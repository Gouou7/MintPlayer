import Darwin
import Foundation
import MCP
import NIOCore
import NIOPosix

actor MCPIPCServer {
    private let handle: @Sendable (MCPIPCRequest) async -> CallTool.Result
    private var group: MultiThreadedEventLoopGroup?
    private var listener: Channel?
    private var acceptTask: Task<Void, Never>?
    private var listenerLock: CInt?

    init(handle: @escaping @Sendable (MCPIPCRequest) async -> CallTool.Result) {
        self.handle = handle
    }

    func start() async throws {
        let path = try MCPIPC.socketPath(createDirectory: true)
        listenerLock = try MCPIPC.lockListener(at: path)
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        do {
            let server = try await ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.backlog, value: 16)
                .bind(unixDomainSocketPath: path, cleanupExistingSocketFile: true) { channel in
                    MCPIPC.serverChannel(channel)
                }
            listener = server.channel
            acceptTask = Task { [handle] in
                await Self.accept(server, handle: handle)
            }
        } catch {
            await stop()
            throw error
        }
    }

    func stop() async {
        acceptTask?.cancel()
        try? await listener?.close()
        await acceptTask?.value
        listener = nil
        acceptTask = nil
        try? await group?.shutdownGracefully()
        group = nil
        if let listenerLock {
            close(listenerLock)
            self.listenerLock = nil
        }
    }

    private static func accept(
        _ server: NIOAsyncChannel<NIOAsyncChannel<ByteBuffer, ByteBuffer>, Never>,
        handle: @escaping @Sendable (MCPIPCRequest) async -> CallTool.Result
    ) async {
        try? await server.executeThenClose { inbound, _ in
            try await withThrowingTaskGroup(of: Void.self) { connections in
                var activeCount = 0
                for try await connection in inbound {
                    if activeCount == 16 {
                        _ = try await connections.next()
                        activeCount -= 1
                    }
                    if Task.isCancelled {
                        try? await connection.channel.close()
                        break
                    }
                    connections.addTask { await serve(connection, handle: handle) }
                    activeCount += 1
                }
                connections.cancelAll()
            }
        }
    }

    private static func serve(
        _ connection: NIOAsyncChannel<ByteBuffer, ByteBuffer>,
        handle: @escaping @Sendable (MCPIPCRequest) async -> CallTool.Result
    ) async {
        let channel = connection.channel
        let deadline = channel.eventLoop.scheduleTask(in: .seconds(30)) {
            channel.close(promise: nil)
        }
        defer { deadline.cancel() }
        try? await connection.executeThenClose { inbound, _ in
            for try await message in inbound {
                let request = try JSONDecoder().decode(MCPIPCRequest.self, from: Data(message.readableBytesView))
                guard !Task.isCancelled else { return }
                let response = await handle(request)
                try await channel.writeAndFlush(MCPIPC.frame(response)).get()
                return
            }
        }
    }
}
