import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var songs: [Song]
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        songs: [Song],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case songs
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        songs = try container.decode([Song].self, forKey: .songs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
