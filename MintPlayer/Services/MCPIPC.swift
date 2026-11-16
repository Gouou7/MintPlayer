import Darwin
import Foundation
import MCP
import NIOCore

struct MCPIPCRequest: Codable, Sendable {
    let parameters: CallTool.Parameters
    let token: String?
}

enum MCPIPC {
    private static let maximumRequestSize = 1_048_576
    private static let maximumResponseSize = 16_777_216

    static func socketPath(createDirectory: Bool = false) throws -> String {
        var temporaryPath = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = confstr(_CS_DARWIN_USER_TEMP_DIR, &temporaryPath, temporaryPath.count)
        guard length > 0, length <= temporaryPath.count else { throw Failure.unavailable }
        let directory = URL(fileURLWithPath: String(cString: temporaryPath))
            .appendingPathComponent(AppConfiguration.mcpDirectoryName, isDirectory: true).path
        if createDirectory, mkdir(directory, 0o700) != 0, errno != EEXIST {
            throw Failure.unavailable
        }

        var metadata = stat()
        if lstat(directory, &metadata) != 0 {
            if errno == ENOENT, !createDirectory { throw Failure.notListening }
            throw Failure.unavailable
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR), metadata.st_uid == geteuid(),
              metadata.st_mode & 0o077 == 0 else { throw Failure.unavailable }

        let socket = directory + "/player.sock"
        if !createDirectory {
            if lstat(socket, &metadata) != 0 {
                if errno == ENOENT { throw Failure.notListening }
                throw Failure.unavailable
            }
            guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFSOCK), metadata.st_uid == geteuid() else {
                throw Failure.unavailable
            }
        }
        return socket
    }

    static func lockListener(at socket: String) throws -> CInt {
        let descriptor = open(socket + ".lock", O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw Failure.unavailable }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), metadata.st_uid == geteuid(),
              metadata.st_mode & 0o077 == 0,
              flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw Failure.unavailable
        }
        return descriptor
    }

    static func serverChannel(_ channel: Channel) -> EventLoopFuture<NIOAsyncChannel<ByteBuffer, ByteBuffer>> {
        framedChannel(channel, maximumSize: maximumRequestSize)
    }

    static func clientChannel(_ channel: Channel) -> EventLoopFuture<NIOAsyncChannel<ByteBuffer, ByteBuffer>> {
        framedChannel(channel, maximumSize: maximumResponseSize)
    }

    private static func framedChannel(
        _ channel: Channel, maximumSize: Int
    ) -> EventLoopFuture<NIOAsyncChannel<ByteBuffer, ByteBuffer>> {
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(
                ByteToMessageHandler(FrameDecoder(maximumSize: maximumSize))
            )
            return try NIOAsyncChannel(wrappingChannelSynchronously: channel)
        }
    }

    static func frame(_ value: MCPIPCRequest) throws -> ByteBuffer {
        try frame(value, maximumSize: maximumRequestSize)
    }

    static func frame(_ value: CallTool.Result) throws -> ByteBuffer {
        try frame(value, maximumSize: maximumResponseSize)
    }

    private static func frame(_ value: some Encodable, maximumSize: Int) throws -> ByteBuffer {
        let data = try JSONEncoder().encode(value)
        guard data.count <= maximumSize else { throw Failure.invalidMessage }
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt32(data.count))
        buffer.writeBytes(data)
        return buffer
    }

    static func error(_ code: String, _ message: String) -> CallTool.Result {
        .init(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            structuredContent: Optional.some(.object(["code": .string(code), "message": .string(message)])),
            isError: true
        )
    }

    enum Failure: Swift.Error {
        case notListening
        case unavailable
        case invalidMessage
        case connectionClosed
    }

    private struct FrameDecoder: ByteToMessageDecoder {
        typealias InboundOut = ByteBuffer
        let maximumSize: Int

        mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
            guard let length = buffer.getInteger(at: buffer.readerIndex, as: UInt32.self) else {
                return .needMoreData
            }
            guard length > 0, Int(length) <= maximumSize else { throw Failure.invalidMessage }
            let headerSize = MemoryLayout<UInt32>.size
            guard let message = buffer.getSlice(at: buffer.readerIndex + headerSize, length: Int(length)) else {
                return .needMoreData
            }
            buffer.moveReaderIndex(forwardBy: headerSize + Int(length))
            context.fireChannelRead(wrapInboundOut(message))
            return .continue
        }
    }
}
