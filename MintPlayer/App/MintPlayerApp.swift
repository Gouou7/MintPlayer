import SwiftUI

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
