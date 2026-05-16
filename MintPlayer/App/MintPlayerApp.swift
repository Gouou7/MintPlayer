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
                .preferredColorScheme(settings.theme == .dark ? .dark : .light)
        }
        .windowStyle(.automatic)
        
        Settings {
            LibrarySettingsView()
                .environmentObject(audioPlayer)
                .environmentObject(musicLibrary)
                .environmentObject(settings)
                .tint(MintTheme.accent)
                .preferredColorScheme(settings.theme == .dark ? .dark : .light)
        }
    }
}
