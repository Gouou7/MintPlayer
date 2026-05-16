import Foundation

struct PlayHistory: Identifiable, Codable, Hashable {
    let id: UUID
    let songId: UUID
    let playedAt: Date
    
    init(id: UUID = UUID(), songId: UUID, playedAt: Date) {
        self.id = id
        self.songId = songId
        self.playedAt = playedAt
    }
}
