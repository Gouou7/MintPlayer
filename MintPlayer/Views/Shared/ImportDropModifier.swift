import SwiftUI
import AppKit

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
                let group = DispatchGroup()
                var urls: [URL] = []
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        DispatchQueue.main.async {
                            if let url { urls.append(url) }
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    musicLibrary.importMusic(from: urls)
                }

                return true
            }
    }
}

enum MusicFolderImporter {
    static func present(for musicLibrary: MusicLibrary) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.current(.add)
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                musicLibrary.addLibrarySource(name: url.lastPathComponent, path: url.path)
            }
        }
    }
}
