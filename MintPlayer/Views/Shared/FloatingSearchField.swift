import SwiftUI
import AppKit

private struct PlayerOverlayPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPlayerOverlayPresented: Bool {
        get { self[PlayerOverlayPresentationKey.self] }
        set { self[PlayerOverlayPresentationKey.self] = newValue }
    }
}

struct NativeToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = prompt
        searchField.stringValue = text
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchFieldDidChange(_:))
        searchField.delegate = context.coordinator
        searchField.sendsSearchStringImmediately = true
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: 245).isActive = true
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.text = $text
        nsView.placeholderString = prompt
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func searchFieldDidChange(_ sender: NSSearchField) {
            text.wrappedValue = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text.wrappedValue = searchField.stringValue
        }
    }
}

struct SongSortButton: View {
    @EnvironmentObject private var settings: SettingsManager
    @Binding var sortOrder: [KeyPathComparator<Song>]

    var body: some View {
        Menu {
            sortOptions
        } label: {
            Label(settings.text(.sortSongs), systemImage: "line.3.horizontal.decrease")
        }
        .labelStyle(.iconOnly)
        .tint(Color.primary)
        .foregroundStyle(.primary)
        .help(settings.text(.sortSongs))
    }

    private var sortOptions: some View {
        Group {
            sortFieldButton(settings.text(.title), field: .title)
            sortFieldButton(settings.text(.artist), field: .artist)
            sortFieldButton(settings.text(.album), field: .album)
            sortFieldButton(settings.text(.duration), field: .duration)
            sortFieldButton(settings.text(.playCount), field: .playCount)
            sortFieldButton(settings.text(.dateAdded), field: .dateAdded)
            Divider()
            sortOrderButton(settings.text(.ascending), order: .forward)
            sortOrderButton(settings.text(.descending), order: .reverse)
        }
    }

    private func sortFieldButton(_ title: String, field: SongSortField) -> some View {
        Button {
            setSort(field, order: activeSortOrder)
        } label: {
            if activeSortField == field {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func sortOrderButton(_ title: String, order: Foundation.SortOrder) -> some View {
        Button {
            setSort(activeSortField, order: order)
        } label: {
            if activeSortOrder == order {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var activeSortField: SongSortField {
        guard let keyPath = sortOrder.first?.keyPath else { return .title }

        switch keyPath {
        case \Song.title:
            return .title
        case \Song.artist:
            return .artist
        case \Song.album:
            return .album
        case \Song.displayGenre:
            return .genre
        case \Song.fileType:
            return .type
        case \Song.duration:
            return .duration
        case \Song.playCount:
            return .playCount
        case \Song.dateAdded:
            return .dateAdded
        default:
            return .title
        }
    }

    private var activeSortOrder: Foundation.SortOrder {
        sortOrder.first?.order ?? .forward
    }

    private func setSort(_ field: SongSortField, order: Foundation.SortOrder) {
        switch field {
        case .title:
            sortOrder = [KeyPathComparator(\Song.title, order: order)]
        case .artist:
            sortOrder = [KeyPathComparator(\Song.artist, order: order)]
        case .album:
            sortOrder = [KeyPathComparator(\Song.album, order: order)]
        case .genre:
            sortOrder = [KeyPathComparator(\Song.displayGenre, order: order)]
        case .type:
            sortOrder = [KeyPathComparator(\Song.fileType, order: order)]
        case .duration:
            sortOrder = [KeyPathComparator(\Song.duration, order: order)]
        case .playCount:
            sortOrder = [KeyPathComparator(\Song.playCount, order: order)]
        case .dateAdded:
            sortOrder = [KeyPathComparator(\Song.dateAdded, order: order)]
        }
    }
}
