import Foundation

struct Artist: Identifiable, Hashable {
    let id: UUID
    let name: String
    let albums: [Album]
    let songs: [Song]
    
    init(id: UUID = UUID(), name: String, albums: [Album], songs: [Song]) {
        self.id = id
        self.name = name
        self.albums = albums
        self.songs = songs
    }
}

struct ArtistSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let coverPath: String?
    let albumCount: Int
    let songCount: Int
}
