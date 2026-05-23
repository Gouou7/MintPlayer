import Foundation

struct PlaylistSong: Codable, Hashable {
    let songId: UUID
    let addedAt: Date
    var sortOrder: Int

    init(songId: UUID, addedAt: Date = Date(), sortOrder: Int) {
        self.songId = songId
        self.addedAt = addedAt
        self.sortOrder = sortOrder
    }
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var songs: [Song]
    var songEntries: [PlaylistSong]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        songs: [Song],
        songEntries: [PlaylistSong]? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.songs = songs
        self.songEntries = songEntries ?? songs.enumerated().map { index, song in
            PlaylistSong(songId: song.id, addedAt: createdAt, sortOrder: index)
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case songs
        case songEntries
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        songs = try container.decode([Song].self, forKey: .songs)
        songEntries = try container.decodeIfPresent([PlaylistSong].self, forKey: .songEntries) ?? songs.enumerated().map { index, song in
            PlaylistSong(songId: song.id, addedAt: Date(), sortOrder: index)
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
