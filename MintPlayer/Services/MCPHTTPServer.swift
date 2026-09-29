import Foundation
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix

actor MCPHTTPServer {
    private let port: Int
    private var token: String?
    private let router: MCPToolRouter
    private var mcpServer: Server?
    private var transport: StatelessHTTPServerTransport?
    private var group: MultiThreadedEventLoopGroup?
    private var listener: Channel?
    private var connections: [ObjectIdentifier: Channel] = [:]
    private var isHandlingRequest = false
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    init(port: Int, token: String?, router: MCPToolRouter) {
        self.port = port
        self.token = token
        self.router = router
    }

    func start() async throws {
        let server = Server(name: "mint-player", version: AppConfiguration.displayVersion,
                            capabilities: .init(tools: .init(listChanged: false)))
        let router = self.router
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: await MCPToolRouter.tools)
        }
        await server.withMethodHandler(CallTool.self) { params in
            await router.call(params)
        }
        let transport = StatelessHTTPServerTransport(validationPipeline: StandardValidationPipeline(validators: [
            OriginValidator.localhost(port: port),
            AcceptHeaderValidator(mode: .jsonOnly),
            ContentTypeValidator(),
            ProtocolVersionValidator()
        ]))
        try await server.start(transport: transport)
        // The SDK's default initialize handler accepts only one initialization per Server.
        // Stateless HTTP clients can initialize independently, so return the same capabilities for each.
        await server.withMethodHandler(Initialize.self) { parameters in
            let version = Version.supported.contains(parameters.protocolVersion)
                ? parameters.protocolVersion : Version.latest
            return .init(protocolVersion: version,
                         capabilities: .init(tools: .init(listChanged: false)),
                         serverInfo: .init(name: "mint-player", version: AppConfiguration.displayVersion))
        }
        self.mcpServer = server
        self.transport = transport

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 64)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                Task { await self.addConnection(channel) }
                channel.closeFuture.whenComplete { _ in
                    Task { await self.removeConnection(channel) }
                }
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(MCPHTTPHandler(server: self))
                }
            }
        do {
            listener = try await bootstrap.bind(host: "127.0.0.1", port: port).get()
        } catch {
            await stop()
            throw error
        }
    }

    func stop() async {
        try? await listener?.close()
        listener = nil
        let openConnections = Array(connections.values)
        connections.removeAll()
        for connection in openConnections { try? await connection.close() }
        await mcpServer?.stop()
        mcpServer = nil
        transport = nil
        if let group {
            await withCheckedContinuation { continuation in
                group.shutdownGracefully { _ in continuation.resume() }
            }
            self.group = nil
        }
    }

    func updateToken(_ token: String?) {
        self.token = token
    }

    private func addConnection(_ channel: Channel) {
        connections[ObjectIdentifier(channel)] = channel
    }

    private func removeConnection(_ channel: Channel) {
        connections[ObjectIdentifier(channel)] = nil
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.path == "/mcp" else {
            return .error(statusCode: 404, .invalidRequest("Not Found"))
        }
        let allowedHosts = ["127.0.0.1:\(port)", "localhost:\(port)"]
        guard let host = request.header("Host"), allowedHosts.contains(host) else {
            return .error(statusCode: 421, .invalidRequest("Host not allowed"))
        }
        if let origin = request.header("Origin"),
           !["http://127.0.0.1:\(port)", "http://localhost:\(port)"].contains(origin) {
            return .error(statusCode: 403, .invalidRequest("Origin not allowed"))
        }
        if let token {
            guard let authorization = request.header("Authorization"),
                  authorization.hasPrefix("Bearer "),
                  constantTimeEqual(String(authorization.dropFirst(7)), token) else {
                return .error(statusCode: 401, .invalidRequest("Invalid bearer token"),
                              extraHeaders: ["WWW-Authenticate": "Bearer"])
            }
        }
        guard let transport else { return .error(statusCode: 503, .internalError("Server unavailable")) }
        // The stateless SDK transport keys in-flight responses by JSON-RPC id, which clients may reuse.
        await acquireRequestSlot()
        defer { releaseRequestSlot() }
        return await transport.handleRequest(request)
    }

    private func acquireRequestSlot() async {
        if isHandlingRequest {
            await withCheckedContinuation { requestWaiters.append($0) }
        } else {
            isHandlingRequest = true
        }
    }

    private func releaseRequestSlot() {
        if requestWaiters.isEmpty {
            isHandlingRequest = false
        } else {
            requestWaiters.removeFirst().resume()
        }
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices { difference |= left[index] ^ right[index] }
        return difference == 0
    }
}

private final class MCPHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private static let maximumBodySize = 1_048_576
    private let server: MCPHTTPServer
    private var head: HTTPRequestHead?
    private var body = Data()
    private var tooLarge = false

    init(server: MCPHTTPServer) { self.server = server }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            body.removeAll(keepingCapacity: true)
            tooLarge = (Int(head.headers.first(name: "Content-Length") ?? "") ?? 0) > Self.maximumBodySize
        case .body(var buffer):
            guard !tooLarge else { return }
            if body.count + buffer.readableBytes > Self.maximumBodySize {
                tooLarge = true
                body.removeAll()
            } else if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                body.append(contentsOf: bytes)
            }
        case .end:
            guard let head else { return }
            self.head = nil
            let version = head.version
            if tooLarge {
                write(.error(statusCode: 413, .invalidRequest("Request body too large")),
                      version: version, context: context)
                return
            }
            var headers: [String: String] = [:]
            for (name, value) in head.headers {
                headers[name] = headers[name].map { "\($0), \(value)" } ?? value
            }
            let path = String(head.uri.split(separator: "?", maxSplits: 1).first ?? "")
            let request = HTTPRequest(method: head.method.rawValue, headers: headers,
                                      body: body.isEmpty ? nil : body, path: path)
            body.removeAll()
            Task {
                let response = await server.handle(request)
                context.eventLoop.execute { self.write(response, version: version, context: context) }
            }
        }
    }

    private func write(_ response: HTTPResponse, version: HTTPVersion, context: ChannelHandlerContext) {
        let body = response.bodyData ?? Data()
        var head = HTTPResponseHead(version: version, status: HTTPResponseStatus(statusCode: response.statusCode))
        for (name, value) in response.headers { head.headers.add(name: name, value: value) }
        head.headers.replaceOrAdd(name: "Content-Length", value: String(body.count))
        head.headers.replaceOrAdd(name: "Connection", value: "close")
        head.headers.replaceOrAdd(name: "Cache-Control", value: "no-store")
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        if !body.isEmpty {
            var buffer = context.channel.allocator.buffer(capacity: body.count)
            buffer.writeBytes(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        let promise = context.eventLoop.makePromise(of: Void.self)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
        promise.futureResult.whenComplete { _ in
            context.close(promise: nil)
        }
    }
}
