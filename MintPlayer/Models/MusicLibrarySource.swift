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
