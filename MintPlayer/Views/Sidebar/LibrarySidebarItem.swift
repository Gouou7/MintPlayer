import Foundation

enum LibrarySidebarItem: String, CaseIterable, Hashable {
    case recent
    case songs
    case albums
    case artists
    
    var selection: LibrarySelection {
        switch self {
        case .recent:
            return .recent
        case .songs:
            return .songs
        case .albums:
            return .albums
        case .artists:
            return .artists
        }
    }
    
    var title: String {
        switch self {
        case .recent:
            return "Recently Played"
        case .songs:
            return "Songs"
        case .albums:
            return "Albums"
        case .artists:
            return "Artists"
        }
    }
    
    var systemImage: String {
        switch self {
        case .recent:
            return "clock.fill"
        case .songs:
            return "music.note"
        case .albums:
            return "rectangle.stack.fill"
        case .artists:
            return "music.microphone"
        }
    }
}
