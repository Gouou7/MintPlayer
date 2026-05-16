import Foundation

struct Album: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let coverPath: String
    let year: Int
    let songs: [Song]
    
    init(id: UUID = UUID(), title: String, artist: String, coverPath: String, year: Int, songs: [Song]) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverPath = coverPath
        self.year = year
        self.songs = songs
    }
}

struct AlbumSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let coverPath: String
    let year: Int
    let songCount: Int
}
