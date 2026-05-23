import SwiftUI

private struct PlayerOverlayPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPlayerOverlayPresented: Bool {
        get { self[PlayerOverlayPresentationKey.self] }
        set { self[PlayerOverlayPresentationKey.self] = newValue }
    }
}

private enum FloatingSearchMetrics {
    static let height: CGFloat = 34
    static let searchWidth: CGFloat = 245
    static let spacing: CGFloat = 9
}

struct LibrarySearchControls<LeadingControls: View>: View {
    @Binding var searchText: String
    let searchPrompt: String
    private let leadingControls: LeadingControls

    init(
        searchText: Binding<String>,
        searchPrompt: String,
        @ViewBuilder leadingControls: () -> LeadingControls
    ) {
        self._searchText = searchText
        self.searchPrompt = searchPrompt
        self.leadingControls = leadingControls()
    }

    var body: some View {
        HStack(spacing: FloatingSearchMetrics.spacing) {
            leadingControls
            FloatingSearchField(text: $searchText, prompt: searchPrompt)
        }
        .fixedSize()
    }
}

extension LibrarySearchControls where LeadingControls == EmptyView {
    init(searchText: Binding<String>, searchPrompt: String) {
        self.init(searchText: searchText, searchPrompt: searchPrompt) {
            EmptyView()
        }
    }
}

struct FloatingSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 13)
        .frame(width: FloatingSearchMetrics.searchWidth, height: FloatingSearchMetrics.height)
        .modifier(CapsuleGlassControlSurface(height: FloatingSearchMetrics.height))
    }
}

struct SongSortButton: View {
    @EnvironmentObject private var settings: SettingsManager
    @Binding var sortOrder: [KeyPathComparator<Song>]
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 15, weight: .medium))
                .frame(width: FloatingSearchMetrics.height, height: FloatingSearchMetrics.height)
                .contentShape(Circle())
        }
        .buttonStyle(MintPlainIconButtonStyle())
        .modifier(CircleGlassButtonSurface())
        .labelStyle(.iconOnly)
        .fixedSize()
        .help(settings.text(.sortSongs))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            sortOptions
                .frame(width: 220)
                .padding(10)
        }
    }

    private var sortOptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            sortOptionButton(settings.text(.title), field: .title, order: .forward)
            sortOptionButton(settings.text(.titleDescending), field: .title, order: .reverse)
            Divider()
            sortOptionButton(settings.text(.artist), field: .artist, order: .forward)
            sortOptionButton(settings.text(.artistDescending), field: .artist, order: .reverse)
            Divider()
            sortOptionButton(settings.text(.album), field: .album, order: .forward)
            sortOptionButton(settings.text(.albumDescending), field: .album, order: .reverse)
            Divider()
            sortOptionButton(settings.text(.duration), field: .duration, order: .forward)
            sortOptionButton(settings.text(.durationDescending), field: .duration, order: .reverse)
            Divider()
            sortOptionButton(settings.text(.playCount), field: .playCount, order: .reverse)
            sortOptionButton(settings.text(.playCountAscending), field: .playCount, order: .forward)
            Divider()
            sortOptionButton(settings.text(.dateAdded), field: .dateAdded, order: .reverse)
            sortOptionButton(settings.text(.dateAddedAscending), field: .dateAdded, order: .forward)
        }
    }

    private func sortOptionButton(_ title: String, field: SongSortField, order: Foundation.SortOrder) -> some View {
        Button {
            setSort(field, order: order)
            isPopoverPresented = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(activeSortField == field && activeSortOrder == order ? 1 : 0)
                    .frame(width: 16)

                Text(title)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(MintRowButtonStyle())
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

struct CapsuleGlassControlSurface: ViewModifier {
    let height: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: shape)
    }
}
