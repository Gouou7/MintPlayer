import Foundation

enum LibrarySidebarItem: String, CaseIterable, Hashable {
    case favorites
    case songs
    case albums
    case artists

    var selection: LibrarySelection {
        switch self {
        case .favorites:
            return .favorites
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
        case .favorites:
            return L10n.text(.favorites, language: language)
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
        case .favorites:
            return "heart.fill"
        case .songs:
            return "music.note"
        case .albums:
            return "rectangle.stack.fill"
        case .artists:
            return "music.microphone"
        }
    }
}
