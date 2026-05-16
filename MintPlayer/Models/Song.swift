import Foundation

struct Song: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let path: String
    let coverPath: String?
    let genre: String?
    let year: Int?
    
    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        path: String,
        coverPath: String? = nil,
        genre: String? = nil,
        year: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.path = path
        self.coverPath = coverPath
        self.genre = genre
        self.year = year
    }
}
