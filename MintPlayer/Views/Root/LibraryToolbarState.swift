import SwiftUI

/// Carries page controls across the native hosting boundary to the existing window toolbar.
struct LibraryToolbarConfiguration: Equatable {
    let revision = UUID()
    var id = ""
    var searchText: Binding<String>?
    var searchPrompt: String?
    var sortOrder: Binding<[KeyPathComparator<Song>]>?
    var backTitle: String?
    var onBack: (() -> Void)?

    static let empty = LibraryToolbarConfiguration()

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.revision == rhs.revision
    }

    var appearance: LibraryToolbarState.Appearance {
        .init(
            id: id,
            searchPrompt: searchPrompt,
            searchValue: searchText?.wrappedValue,
            sortValue: sortOrder?.wrappedValue,
            backTitle: backTitle
        )
    }
}

struct LibraryToolbarPreferenceKey: PreferenceKey {
    static let defaultValue = LibraryToolbarConfiguration.empty

    static func reduce(value: inout LibraryToolbarConfiguration, nextValue: () -> LibraryToolbarConfiguration) {
        let next = nextValue()
        if !next.id.isEmpty {
            value = next
        }
    }
}

final class LibraryToolbarState: ObservableObject {
    struct Appearance: Equatable {
        var id = ""
        var searchPrompt: String?
        var searchValue: String?
        var sortValue: [KeyPathComparator<Song>]?
        var backTitle: String?

        var showsSort: Bool { sortValue != nil }
    }

    @Published private(set) var appearance = Appearance()
    private var configuration = LibraryToolbarConfiguration.empty

    func update(_ configuration: LibraryToolbarConfiguration) {
        // Refresh callbacks/bindings even when controls look identical, without a render feedback loop.
        self.configuration = configuration
        if appearance != configuration.appearance {
            appearance = configuration.appearance
        }
    }

    var searchText: Binding<String> {
        // An in-flight IME/debounce edit must retain its original page's binding.
        configuration.searchText ?? .constant("")
    }

    var sortOrder: Binding<[KeyPathComparator<Song>]> {
        Binding(
            get: { self.configuration.sortOrder?.wrappedValue ?? [] },
            set: { self.configuration.sortOrder?.wrappedValue = $0 }
        )
    }

    func goBack() {
        configuration.onBack?()
    }
}
