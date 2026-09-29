import Foundation
import Combine

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
    private var server: MCPHTTPServer?
    private var transition: Task<Void, Never>?
    private var generation = 0
    private var enabled = false
    private var requiresToken = true
    private var port = AppConfiguration.defaultMCPPort

    var endpoint: String { "http://127.0.0.1:\(port)/mcp" }

    private var settings: SettingsManager?

    func configure(audioPlayer: AudioPlayer, musicLibrary: MusicLibrary, settings: SettingsManager) {
        self.audioPlayer = audioPlayer
        self.musicLibrary = musicLibrary
        self.settings = settings
    }

    func update(enabled: Bool, port: Int, requiresToken: Bool) {
        guard self.enabled != enabled || self.port != port || self.requiresToken != requiresToken || status == .off && enabled else { return }
        self.enabled = enabled
        self.port = port
        self.requiresToken = requiresToken
        restart()
    }

    func retry() {
        guard enabled else { return }
        restart()
    }

    func copyToken() throws -> String {
        try MCPTokenStore.loadOrCreate()
    }

    func rotateToken() async {
        do {
            let token = try MCPTokenStore.rotate()
            operationError = nil
            await server?.updateToken(token)
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
            guard let audioPlayer = self.audioPlayer, let musicLibrary = self.musicLibrary, let settings = self.settings else {
                self.status = .failed(L10n.current(.mcpPlayerNotReady))
                return
            }
            do {
                let token: String?
                if self.requiresToken {
                    token = try MCPTokenStore.loadOrCreate()
                } else {
                    token = nil
                }
                let router = MCPToolRouter(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
                let server = MCPHTTPServer(port: self.port, token: token, router: router)
                try await server.start()
                if revision == self.generation {
                    self.server = server
                    self.status = .running
                } else {
                    await server.stop()
                }
            } catch {
                if revision == self.generation { self.status = .failed(error.localizedDescription) }
            }
        }
    }
}
