import Foundation
import Combine
import MCP

enum MCPServiceStatus: Equatable {
    case off
    case starting
    case running
    case failed(String)
}

@MainActor
final class MCPServiceController: ObservableObject {
    @Published private(set) var status: MCPServiceStatus = .off
    @Published private(set) var operationError: String?
    private var audioPlayer: AudioPlayer?
    private var musicLibrary: MusicLibrary?
    private var server: MCPIPCServer?
    private var transition: Task<Void, Never>?
    private var generation = 0
    private var enabled = false
    private var requiresToken = true

    var command: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(AppConfiguration.mcpHelperName).path
    }

    private var settings: SettingsManager?

    func configure(audioPlayer: AudioPlayer, musicLibrary: MusicLibrary, settings: SettingsManager) {
        self.audioPlayer = audioPlayer
        self.musicLibrary = musicLibrary
        self.settings = settings
    }

    func update(enabled: Bool, requiresToken: Bool) {
        guard self.enabled != enabled || self.requiresToken != requiresToken else { return }
        self.enabled = enabled
        self.requiresToken = requiresToken
        restart()
    }

    func retry() {
        guard enabled else { return }
        restart()
    }

    func copyToken() throws -> String {
        guard musicLibrary?.isLibraryReady == true else { throw LibraryPersistenceStore.StoreError.missingDatabase }
        return try MCPTokenStore.loadOrCreate()
    }

    func rotateToken() {
        do {
            guard musicLibrary?.isLibraryReady == true else { throw LibraryPersistenceStore.StoreError.missingDatabase }
            _ = try MCPTokenStore.rotate()
            operationError = nil
            if enabled { restart() }
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func restart() {
        generation += 1
        let revision = generation
        let previous = transition
        status = enabled ? .starting : .off
        transition = Task { [weak self] in
            await previous?.value
            guard let self, revision == self.generation else { return }
            if let server = self.server {
                self.server = nil
                await server.stop()
            }
            guard revision == self.generation, self.enabled else { return }
            guard let audioPlayer = self.audioPlayer, let musicLibrary = self.musicLibrary,
                  let settings = self.settings else {
                self.status = .failed(L10n.current(.mcpPlayerNotReady))
                return
            }
            let token: String?
            do {
                token = self.requiresToken ? try self.copyToken() : nil
            } catch {
                self.status = .failed(error.localizedDescription)
                return
            }
            do {
                let router = MCPToolRouter(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
                let server = MCPIPCServer { [weak self] request in
                    guard let self else {
                        return MCPIPC.error("mcp_unavailable", L10n.current(.mcpPlayerNotReady))
                    }
                    return await self.call(request, router: router, token: token, revision: revision)
                }
                try await server.start()
                if revision == self.generation {
                    self.server = server
                    self.status = .running
                } else {
                    await server.stop()
                }
            } catch {
                if revision == self.generation {
                    self.status = .failed(settings.text(.mcpLocalConnectionFailed))
                }
            }
        }
    }

    private func call(
        _ request: MCPIPCRequest, router: MCPToolRouter, token: String?, revision: Int
    ) async -> CallTool.Result {
        guard enabled, settings?.mcpEnabled == true else {
            return MCPIPC.error("mcp_disabled", L10n.current(.mcpDisabled))
        }
        guard revision == generation, requiresToken == settings?.mcpRequiresToken else {
            return MCPIPC.error("mcp_unavailable", L10n.current(.mcpPlayerNotReady))
        }
        if let token, !Self.tokensMatch(token, request.token ?? "") {
            return MCPIPC.error("mcp_unauthorized", L10n.current(.mcpUnauthorized))
        }
        guard musicLibrary?.isLibraryReady == true else {
            return MCPIPC.error("library_unavailable", L10n.current(.databaseUnavailable))
        }
        return await router.call(request.parameters)
    }

    private static func tokensMatch(_ expected: String, _ supplied: String) -> Bool {
        let left = Array(expected.utf8)
        let right = Array(supplied.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices { difference |= left[index] ^ right[index] }
        return difference == 0
    }
}
