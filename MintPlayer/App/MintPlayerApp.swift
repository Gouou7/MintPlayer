import SwiftUI
import AppKit

@main
struct MintPlayerApp: App {
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
