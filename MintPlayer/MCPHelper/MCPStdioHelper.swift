import AppKit
import CoreFoundation
import Darwin
import Foundation
import MCP
import NIOCore
import NIOPosix

@main
struct MCPStdioHelper {
    @MainActor
    static func main() async {
        signal(SIGPIPE, SIG_IGN)

        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let appURL = executable.resolvingSymlinksInPath().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard appURL.pathExtension == "app", let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            FileHandle.standardError.write(Data((L10n.current(.mcpHelperNotInstalled) + "\n").utf8))
            exit(EXIT_FAILURE)
        }

        let bridge = MCPStdioBridge(appURL: appURL, bundleIdentifier: bundleIdentifier)
        let server = Server(
            name: "mint-player", version: AppConfiguration.displayVersion(in: bundle),
            capabilities: .init(tools: .init(listChanged: false))
        )
        await server.withMethodHandler(ListTools.self) { _ in .init(tools: MCPToolCatalog.tools) }
        await server.withMethodHandler(CallTool.self) { parameters in await bridge.call(parameters) }

        do {
            try await server.start(transport: StdioTransport())
            await server.waitUntilCompleted()
            await server.stop()
            await bridge.stop()
        } catch {
            FileHandle.standardError.write(Data((L10n.current(.mcpStdioStartError) + "\n").utf8))
            await bridge.stop()
            exit(EXIT_FAILURE)
        }
    }
}

@MainActor
private final class MCPStdioBridge {
    private typealias Connection = NIOAsyncChannel<ByteBuffer, ByteBuffer>

    private let appURL: URL
    private let bundleIdentifier: String
    private let token = ProcessInfo.processInfo.environment["MINTPLAYER_MCP_TOKEN"]
    private var group: MultiThreadedEventLoopGroup?
    private var launchTask: Task<Void, Error>?
    private var isStopping = false

    init(appURL: URL, bundleIdentifier: String) {
        self.appURL = appURL
        self.bundleIdentifier = bundleIdentifier
    }

    func call(_ parameters: CallTool.Parameters) async -> CallTool.Result {
        do {
            let message = try MCPIPC.frame(MCPIPCRequest(parameters: parameters, token: token))
            let connection = try await connectOrLaunch()
            let channel = connection.channel
            let deadline = channel.eventLoop.scheduleTask(in: .seconds(20)) {
                channel.close(promise: nil)
            }
            defer { deadline.cancel() }

            // Once a command is sent, retrying could apply it more than once.
            return try await connection.executeThenClose { inbound, _ in
                try await channel.writeAndFlush(message).get()
                for try await response in inbound {
                    return try JSONDecoder().decode(CallTool.Result.self, from: Data(response.readableBytesView))
                }
                throw MCPIPC.Failure.connectionClosed
            }
        } catch Failure.disabled {
            return MCPIPC.error("mcp_disabled", text(.mcpDisabled))
        } catch Failure.launchFailed {
            return MCPIPC.error("launch_failed", text(.mcpAppLaunchError))
        } catch MCPIPC.Failure.notListening {
            return MCPIPC.error("mcp_unavailable", text(.mcpPlayerNotReady))
        } catch MCPIPC.Failure.invalidMessage {
            return MCPIPC.error("invalid_request", text(.mcpRequestTooLarge))
        } catch {
            return MCPIPC.error("mcp_unavailable", text(.mcpLocalConnectionFailed))
        }
    }

    func stop() async {
        isStopping = true
        launchTask?.cancel()
        try? await group?.shutdownGracefully()
        group = nil
    }

    private func connectOrLaunch() async throws -> Connection {
        do {
            return try await connect()
        } catch MCPIPC.Failure.notListening {
            guard isEnabled else { throw Failure.disabled }
            try await launchIfNeeded()
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        repeat {
            do {
                return try await connect()
            } catch MCPIPC.Failure.notListening {
                try await Task.sleep(for: .milliseconds(100))
            }
        } while clock.now < deadline
        throw MCPIPC.Failure.notListening
    }

    private func connect() async throws -> Connection {
        guard !isStopping else { throw CancellationError() }
        let path = try MCPIPC.socketPath()
        if group == nil { group = MultiThreadedEventLoopGroup(numberOfThreads: 1) }
        guard let group else { throw MCPIPC.Failure.unavailable }
        do {
            return try await ClientBootstrap(group: group).connectTimeout(.seconds(1))
                .connect(unixDomainSocketPath: path) { channel in MCPIPC.clientChannel(channel) }
        } catch let error as IOError where error.errnoCode == ENOENT || error.errnoCode == ECONNREFUSED {
            throw MCPIPC.Failure.notListening
        }
    }

    private var isEnabled: Bool {
        let domain = bundleIdentifier as CFString
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(AppConfiguration.mcpEnabledKey as CFString, domain) as? Bool == true
    }

    private func launchIfNeeded() async throws {
        guard !isStopping else { throw CancellationError() }
        if let launchTask { return try await launchTask.value }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty else { return }

        let task = Task {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            do {
                _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            } catch {
                throw Failure.launchFailed
            }
        }
        launchTask = task
        defer { launchTask = nil }
        try await task.value
    }

    private func text(_ key: L10n.Key) -> String {
        let saved = CFPreferencesCopyAppValue(
            AppConfiguration.userDefaultsKey("settings.language") as CFString, bundleIdentifier as CFString
        ) as? String
        let language = (saved.flatMap(AppLanguage.init(rawValue:)) ?? .system).resolved
        return L10n.text(key, language: language)
    }

    private enum Failure: Error {
        case disabled
        case launchFailed
    }
}
