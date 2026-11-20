import SwiftUI
import AppKit
import Combine

@main
struct MintPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var musicLibrary = MusicLibrary()
    @StateObject private var settings = SettingsManager()
    @State private var isLyricsWindowOpen = false

    var body: some Scene {
        WindowGroup {
            MainView(isLyricsWindowOpen: isLyricsWindowOpen)
                .environmentObject(audioPlayer)
                .environmentObject(musicLibrary)
                .environmentObject(settings)
                .preferredColorScheme(settings.preferredColorScheme)
                .onAppear {
                    appDelegate.configure(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
                }
        }
        .windowStyle(.automatic)
        .commands {
            PlayerCommands(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
        }

        Window(settings.text(.lyrics), id: "lyrics") {
            LyricsWindowView()
                .environmentObject(audioPlayer)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .onAppear {
                    isLyricsWindowOpen = true
                    appDelegate.configure(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
                }
                .onDisappear { isLyricsWindowOpen = false }
        }
        .defaultSize(width: 1180, height: 760)
        .defaultWindowPlacement { _, context in
            let fallbackSize = CGSize(width: 1180, height: 760)
            let displayFrame = context.defaultDisplay.visibleRect

            guard let savedFrame = WindowFramePersistence.savedFrame(for: .lyrics) else {
                return WindowPlacement(size: fallbackSize)
            }

            let frame = WindowFramePersistence.constrainedFrame(
                savedFrame,
                minimumSize: CGSize(width: 980, height: 600),
                displayFrame: displayFrame
            )
            return WindowPlacement(frame.origin, size: frame.size)
        }
        .windowBackgroundDragBehavior(.enabled)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            LibrarySettingsView()
                .environmentObject(audioPlayer)
                .environmentObject(musicLibrary)
                .environmentObject(settings)
                .environmentObject(appDelegate.mcpService)
                .preferredColorScheme(settings.preferredColorScheme)
                .onAppear {
                    appDelegate.configure(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
                }
        }
        .defaultWindowPlacement { _, context in
            let fallbackSize = CGSize(width: 620, height: 640)
            let displayFrame = context.defaultDisplay.visibleRect

            guard let savedFrame = WindowFramePersistence.savedFrame(for: .settings) else {
                return WindowPlacement(size: fallbackSize)
            }

            let frame = WindowFramePersistence.constrainedFrame(
                savedFrame,
                minimumSize: fallbackSize,
                displayFrame: displayFrame
            )
            return WindowPlacement(frame.origin, size: frame.size)
        }
        .windowResizability(.contentMinSize)
    }
}

private struct PlayerCommands: Commands {
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var musicLibrary: MusicLibrary
    @ObservedObject var settings: SettingsManager
    @FocusedValue(\.librarySearchAction) private var searchAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(settings.text(.addMusicFolder), action: { MusicFolderImporter.present(for: musicLibrary) })
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandGroup(after: .textEditing) {
            Button(settings.text(.focusSearch)) { searchAction?() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(searchAction == nil)
        }
        CommandMenu(settings.text(.playbackMenu)) {
            Button(settings.text(.playPause), action: audioPlayer.togglePlayPause)
                .keyboardShortcut("p", modifiers: .command)
                .disabled(audioPlayer.currentSong == nil)
            Button(settings.text(.previous), action: audioPlayer.previous)
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(audioPlayer.queue.isEmpty)
            Button(settings.text(.next), action: audioPlayer.next)
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(audioPlayer.queue.isEmpty)
            Divider()
            Toggle(settings.text(.shuffle), isOn: Binding(
                get: { audioPlayer.isShuffleEnabled }, set: { _ in audioPlayer.toggleShuffle() }
            ))
            Toggle(settings.text(.repeatMode), isOn: Binding(
                get: { audioPlayer.isRepeatEnabled }, set: { _ in audioPlayer.toggleRepeat() }
            ))
            Divider()
            Button(settings.text(.clearQueue), action: audioPlayer.clearQueue)
                .disabled(audioPlayer.upcomingSongs.isEmpty)
            Button(settings.text(.undoClearQueue), action: audioPlayer.undoClearQueue)
                .disabled(!audioPlayer.canUndoClearQueue)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let mcpService = MCPServiceController()
    private weak var audioPlayer: AudioPlayer?
    private weak var musicLibrary: MusicLibrary?
    private var librarySubscription: AnyCancellable?
    private var mcpSettingsSubscription: AnyCancellable?
    private var didRestorePlaybackSession = false

    func configure(audioPlayer: AudioPlayer, musicLibrary: MusicLibrary, settings: SettingsManager) {
        self.audioPlayer = audioPlayer
        self.musicLibrary = musicLibrary
        guard librarySubscription == nil else { return }
        audioPlayer.onPlaybackCounted = { [weak musicLibrary] songID in
            musicLibrary?.recordQualifiedPlayback(for: songID)
        }
        librarySubscription = musicLibrary.$songs
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak audioPlayer] songs in
                guard let self, let audioPlayer else { return }
                audioPlayer.refreshLibrarySongs(songs)
                if !self.didRestorePlaybackSession, !songs.isEmpty {
                    audioPlayer.restoreLastSession(from: songs)
                    self.didRestorePlaybackSession = true
                }
            }
        mcpService.configure(audioPlayer: audioPlayer, musicLibrary: musicLibrary, settings: settings)
        mcpSettingsSubscription = settings.$mcpEnabled.combineLatest(settings.$mcpRequiresToken)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled, requiresToken in
                self?.mcpService.update(enabled: enabled, requiresToken: requiresToken)
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        musicLibrary?.shutdownArtworkMaintenance()
        mcpService.update(enabled: false, requiresToken: true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(menuItem(
            title: L10n.current(.previous),
            symbolName: "backward.fill",
            action: #selector(playPrevious),
            isEnabled: canNavigatePlayback
        ))
        let isPlaying = audioPlayer?.isPlaying == true
        menu.addItem(menuItem(
            title: L10n.current(isPlaying ? .pause : .play),
            symbolName: isPlaying ? "pause.fill" : "play.fill",
            action: #selector(togglePlayback),
            isEnabled: audioPlayer?.currentSong != nil
        ))
        menu.addItem(menuItem(
            title: L10n.current(.next),
            symbolName: "forward.fill",
            action: #selector(playNext),
            isEnabled: canNavigatePlayback
        ))
        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: L10n.current(.shuffle),
            symbolName: "shuffle",
            action: #selector(shuffleSongs),
            isEnabled: musicLibrary?.songs.isEmpty == false
        ))
        return menu
    }

    private var canNavigatePlayback: Bool {
        audioPlayer?.currentSong != nil || audioPlayer?.queue.isEmpty == false
    }

    private func menuItem(
        title: String,
        symbolName: String,
        action: Selector,
        isEnabled: Bool
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = isEnabled
        item.image = symbolImage(named: symbolName, accessibilityDescription: title)
        return item
    }

    private func symbolImage(named symbolName: String, accessibilityDescription: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        return image
    }

    @objc private func playPrevious() {
        audioPlayer?.previous()
    }

    @objc private func togglePlayback() {
        audioPlayer?.togglePlayPause()
    }

    @objc private func playNext() {
        audioPlayer?.next()
    }

    @objc private func shuffleSongs() {
        guard let songs = musicLibrary?.songs, !songs.isEmpty else { return }
        audioPlayer?.shuffle(songs: songs)
    }
}

struct PlaybackSpaceKeyHandler: NSViewRepresentable {
    @EnvironmentObject private var audioPlayer: AudioPlayer

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView()
        context.coordinator.audioPlayer = audioPlayer
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        context.coordinator.audioPlayer = audioPlayer
    }

    static func dismantleNSView(_ nsView: HostView, coordinator: Coordinator) {
        coordinator.detach()
        nsView.coordinator = nil
    }

    final class HostView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    final class Coordinator: NSResponder {
        weak var audioPlayer: AudioPlayer?
        private weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard self.window !== window else { return }
            detach()
            guard let window else { return }

            self.window = window
            // Place playback after the window so focused controls handle their own keys first.
            nextResponder = window.nextResponder
            window.nextResponder = self
        }

        func detach() {
            var responder: NSResponder? = window
            while let current = responder {
                if current.nextResponder === self {
                    current.nextResponder = nextResponder
                    break
                }
                responder = current.nextResponder
            }
            nextResponder = nil
            window = nil
        }

        override func keyDown(with event: NSEvent) {
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting(.capsLock)

            guard event.charactersIgnoringModifiers == " ",
                  modifiers.isEmpty,
                  let window,
                  event.window === window,
                  window.isKeyWindow,
                  let audioPlayer,
                  audioPlayer.currentSong != nil else {
                super.keyDown(with: event)
                return
            }

            if !event.isARepeat {
                audioPlayer.togglePlayPause()
            }
        }
    }
}
