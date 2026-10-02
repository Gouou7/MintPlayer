import Foundation

enum LibrarySidebarItem: String, CaseIterable, Hashable {
    case home
    case songs
    case albums
    case artists

    var selection: LibrarySelection {
        switch self {
        case .home:
            return .home
        case .songs:
            return .songs
        case .albums:
            return .albums
        case .artists:
            return .artists
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .home:
            return L10n.text(.home, language: language)
        case .songs:
            return L10n.text(.songs, language: language)
        case .albums:
            return L10n.text(.albums, language: language)
        case .artists:
            return L10n.text(.artists, language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .songs:
            return "music.note"
        case .albums:
            return "rectangle.stack.fill"
        case .artists:
            return "music.microphone"
        }
    }
}
