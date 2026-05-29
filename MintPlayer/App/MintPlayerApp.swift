import SwiftUI
import AppKit

@main
struct MintPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var musicLibrary = MusicLibrary()
    @StateObject private var settings = SettingsManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(audioPlayer)
                .environmentObject(musicLibrary)
                .environmentObject(settings)
                .tint(MintTheme.accent)
                .preferredColorScheme(settings.preferredColorScheme)
                .onAppear {
                    appDelegate.configure(audioPlayer: audioPlayer, musicLibrary: musicLibrary)
                }
        }
        .windowStyle(.automatic)

        WindowGroup("Lyrics", id: "lyrics") {
            LyricsWindowView()
                .environmentObject(audioPlayer)
                .environmentObject(settings)
                .tint(MintTheme.accent)
                .preferredColorScheme(settings.preferredColorScheme)
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultSize(width: 1180, height: 760)
        .windowBackgroundDragBehavior(.enabled)
        .restorationBehavior(.disabled)

        Settings {
            LibrarySettingsView()
                .environmentObject(audioPlayer)
                .environmentObject(musicLibrary)
                .environmentObject(settings)
                .tint(MintTheme.accent)
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var audioPlayer: AudioPlayer?
    private weak var musicLibrary: MusicLibrary?

    func configure(audioPlayer: AudioPlayer, musicLibrary: MusicLibrary) {
        self.audioPlayer = audioPlayer
        self.musicLibrary = musicLibrary
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(menuItem(
            title: "⏪️ 上一曲",
            symbolName: "backward.fill",
            action: #selector(playPrevious),
            isEnabled: canNavigatePlayback
        ))
        let isPlaying = audioPlayer?.isPlaying == true
        menu.addItem(menuItem(
            title: isPlaying ? "⏸ 暂停" : "▶️ 播放",
            symbolName: isPlaying ? "pause.fill" : "play.fill",
            action: #selector(togglePlayback),
            isEnabled: audioPlayer?.currentSong != nil
        ))
        menu.addItem(menuItem(
            title: "⏩️ 下一曲",
            symbolName: "forward.fill",
            action: #selector(playNext),
            isEnabled: canNavigatePlayback
        ))
        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: "🔀 随机播放",
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
        view.coordinator = context.coordinator
        context.coordinator.audioPlayer = audioPlayer
        context.coordinator.hostView = view
        context.coordinator.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.audioPlayer = audioPlayer
        context.coordinator.hostView = nsView
        context.coordinator.installMonitorIfNeeded()
    }

    final class HostView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.hostView = self
        }
    }

    final class Coordinator {
        weak var audioPlayer: AudioPlayer?
        weak var hostView: HostView?
        private var eventMonitor: Any?

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        func installMonitorIfNeeded() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting(.capsLock)

            guard event.keyCode == 49,
                  modifiers.isEmpty,
                  NSApp.isActive,
                  let window = hostView?.window,
                  event.window === window,
                  window.isKeyWindow,
                  !isTextInputFocused(in: window)
            else { return event }

            audioPlayer?.togglePlayPause()
            return nil
        }

        private func isTextInputFocused(in window: NSWindow) -> Bool {
            if window.firstResponder is NSTextView {
                return true
            }

            var view = window.firstResponder as? NSView
            while let currentView = view {
                if currentView is NSTextField {
                    return true
                }
                view = currentView.superview
            }

            return false
        }
    }
}
