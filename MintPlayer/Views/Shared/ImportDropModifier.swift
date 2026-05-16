import SwiftUI

extension View {
    func dropToImport() -> some View {
        modifier(ImportDropModifier())
    }
}

private struct ImportDropModifier: ViewModifier {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    
    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: nil) { providers -> Bool in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async {
                            musicLibrary.importMusic(from: [url])
                        }
                    }
                }
                
                return true
            }
    }
}
