import Foundation

struct MusicLibrarySource: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var isScanning: Bool = false
    var lastScanned: Date?

    init(id: UUID = UUID(), name: String, path: String, isScanning: Bool = false, lastScanned: Date? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.isScanning = isScanning
        self.lastScanned = lastScanned
    }
}

struct BlockedSong: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceId: UUID
    let path: String
    let title: String
    let artist: String
    let album: String
    let blockedAt: Date

    init(
        id: UUID = UUID(),
        sourceId: UUID,
        path: String,
        title: String,
        artist: String,
        album: String,
        blockedAt: Date = Date()
    ) {
        self.id = id
        self.sourceId = sourceId
        self.path = path
        self.title = title
        self.artist = artist
        self.album = album
        self.blockedAt = blockedAt
    }
}
