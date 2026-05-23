import Foundation

enum LibrarySelection: Hashable {
    case songs
    case albums
    case artists
    case favorites
    case playlist(UUID)
    case folder(UUID)
}
