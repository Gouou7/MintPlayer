import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SongDragPayload {
    static let songIDsTypeIdentifier = "dev.govo.mintplayer.song-ids"
    static let songIDsContentType = UTType(exportedAs: songIDsTypeIdentifier)
    static let filenamesTypeIdentifier = "NSFilenamesPboardType"
    
    static var acceptedContentTypes: [UTType] {
        [
            songIDsContentType,
            .fileURL,
            UTType(filenamesTypeIdentifier) ?? .data
        ]
    }
    
    static var acceptedPasteboardTypes: [NSPasteboard.PasteboardType] {
        acceptedPasteboardTypeIdentifiers.map { NSPasteboard.PasteboardType($0) }
    }
    
    static var acceptedPasteboardTypeIdentifiers: [String] {
        [
            songIDsTypeIdentifier,
            NSPasteboard.PasteboardType.fileURL.rawValue,
            filenamesTypeIdentifier
        ]
    }
    
    static func itemProvider(for songs: [Song]) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = songs.count == 1 ? songs[0].title : "\(songs.count) Songs"
        
        if let idsData = songIDsData(for: songs) {
            provider.registerDataRepresentation(forTypeIdentifier: songIDsTypeIdentifier, visibility: .all) { completion in
                completion(idsData, nil)
                return nil
            }
        }
        
        if let filenamesData = filenamesData(for: songs) {
            provider.registerDataRepresentation(forTypeIdentifier: filenamesTypeIdentifier, visibility: .all) { completion in
                completion(filenamesData, nil)
                return nil
            }
        }
        
        if let firstSong = songs.first {
            let urlData = URL(fileURLWithPath: firstSong.path).absoluteString.data(using: .utf8)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
                completion(urlData, nil)
                return nil
            }
        }
        
        return provider
    }
    
    static func pasteboardItem(for song: Song) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(song.id.uuidString, forType: NSPasteboard.PasteboardType(songIDsTypeIdentifier))
        item.setString(URL(fileURLWithPath: song.path).absoluteString, forType: .fileURL)
        
        if let filenamesData = filenamesData(for: [song]) {
            item.setData(filenamesData, forType: NSPasteboard.PasteboardType(filenamesTypeIdentifier))
        }
        
        return item
    }
    
    static func loadSongs(
        from providers: [NSItemProvider],
        musicLibrary: MusicLibrary,
        completion: @escaping ([Song]) -> Void
    ) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var loadedIDs: [Song.ID] = []
        var loadedPaths: [String] = []
        var acceptedProvider = false
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(songIDsTypeIdentifier) {
                acceptedProvider = true
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: songIDsTypeIdentifier) { data, _ in
                    if let data {
                        lock.withLock {
                            loadedIDs.append(contentsOf: songIDs(from: data))
                        }
                    }
                    group.leave()
                }
            }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                acceptedProvider = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let path = filePath(from: item) {
                        lock.withLock {
                            loadedPaths.append(path)
                        }
                    }
                    group.leave()
                }
            }
            
            if provider.hasItemConformingToTypeIdentifier(filenamesTypeIdentifier) {
                acceptedProvider = true
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: filenamesTypeIdentifier) { data, _ in
                    if let data {
                        lock.withLock {
                            loadedPaths.append(contentsOf: filePaths(fromFilenamesData: data))
                        }
                    }
                    group.leave()
                }
            }
        }
        
        guard acceptedProvider else { return false }
        
        group.notify(queue: .main) {
            completion(musicLibrary.songs(matchingIDs: loadedIDs, paths: loadedPaths))
        }
        return true
    }
    
    static func songs(from pasteboard: NSPasteboard, musicLibrary: MusicLibrary) -> [Song] {
        var loadedIDs: [Song.ID] = []
        var loadedPaths: [String] = []
        
        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let idString = item.string(forType: NSPasteboard.PasteboardType(songIDsTypeIdentifier)),
                   let songID = UUID(uuidString: idString) {
                    loadedIDs.append(songID)
                }
                
                if let fileURLString = item.string(forType: .fileURL),
                   let path = URL(string: fileURLString)?.path {
                    loadedPaths.append(path)
                }
                
                if let filenamesData = item.data(forType: NSPasteboard.PasteboardType(filenamesTypeIdentifier)) {
                    loadedPaths.append(contentsOf: filePaths(fromFilenamesData: filenamesData))
                }
            }
        }
        
        if let idsData = pasteboard.data(forType: NSPasteboard.PasteboardType(songIDsTypeIdentifier)) {
            loadedIDs.append(contentsOf: songIDs(from: idsData))
        }
        
        if let filenamesData = pasteboard.data(forType: NSPasteboard.PasteboardType(filenamesTypeIdentifier)) {
            loadedPaths.append(contentsOf: filePaths(fromFilenamesData: filenamesData))
        }
        
        if let fileURLString = pasteboard.string(forType: .fileURL),
           let path = URL(string: fileURLString)?.path {
            loadedPaths.append(path)
        }
        
        return musicLibrary.songs(matchingIDs: loadedIDs, paths: loadedPaths)
    }
    
    private static func songIDsData(for songs: [Song]) -> Data? {
        songs.map { $0.id.uuidString }.joined(separator: "\n").data(using: .utf8)
    }
    
    private static func songIDs(from data: Data) -> [Song.ID] {
        guard let string = String(data: data, encoding: .utf8) else { return [] }
        return string
            .split(whereSeparator: \.isNewline)
            .compactMap { UUID(uuidString: String($0)) }
    }
    
    private static func filenamesData(for songs: [Song]) -> Data? {
        let paths = songs.map(\.path)
        return try? PropertyListSerialization.data(fromPropertyList: paths, format: .binary, options: 0)
    }
    
    private static func filePaths(fromFilenamesData data: Data) -> [String] {
        guard let paths = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
            return []
        }
        return paths
    }
    
    private static func filePath(from item: NSSecureCoding?) -> String? {
        switch item {
        case let url as URL:
            return url.path
        case let data as Data:
            guard let string = String(data: data, encoding: .utf8) else { return nil }
            return URL(string: string)?.path ?? string
        case let string as String:
            return URL(string: string)?.path ?? string
        default:
            return nil
        }
    }
}

private extension NSLock {
    func withLock(_ body: () -> Void) {
        lock()
        defer { unlock() }
        body()
    }
}
