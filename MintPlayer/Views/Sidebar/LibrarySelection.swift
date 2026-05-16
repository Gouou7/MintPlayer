import Foundation

enum LibrarySelection: Hashable {
    case songs
    case albums
    case artists
    case recent
    case playlist(UUID)
    case folder(UUID)
}
