import SwiftUI
import AppKit

struct MainView: View {
    private static let sidebarCollapsedDefaultsKey = AppConfiguration.userDefaultsKey("sidebar.isCollapsed")

    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    @AppStorage(Self.sidebarCollapsedDefaultsKey) private var isSidebarCollapsedStored = false
    @State private var selection: LibrarySelection = .songs
    @State private var columnVisibility: NavigationSplitViewVisibility = UserDefaults.standard.bool(forKey: Self.sidebarCollapsedDefaultsKey) ? .detailOnly : .all
    @State private var didRestorePlaybackSession = false

    private let playerBarWidth: CGFloat = 648

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 204, ideal: 260, max: 300)
        } detail: {
            ZStack(alignment: .bottom) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PlayerBarView {
                    if audioPlayer.currentSong != nil {
                        openLyricsWindow()
                    }
                }
                .frame(width: playerBarWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(currentTitle)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            if isSidebarCollapsed {
                ToolbarItem(placement: .principal) {
                    CollapsedSidebarNavigationPicker(selection: $selection)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 600)
        .background {
            SidebarToolbarToggleRemover()
                .frame(width: 0, height: 0)
            PlaybackSpaceKeyHandler()
                .frame(width: 0, height: 0)
        }
        .onAppear {
            columnVisibility = preferredColumnVisibility
            restorePlaybackSessionIfNeeded()
            audioPlayer.onSongStarted = { song in
                musicLibrary.recordSongPlayback(song)
            }
        }
        .onChange(of: columnVisibility) { _, newVisibility in
            switch newVisibility {
            case .detailOnly:
                isSidebarCollapsedStored = true
            case .all, .doubleColumn:
                isSidebarCollapsedStored = false
            case .automatic:
                break
            default:
                break
            }
        }
        .onChange(of: musicLibrary.songs) { _, _ in
            restorePlaybackSessionIfNeeded()
        }
        .onDisappear {
            audioPlayer.onSongStarted = nil
        }
    }

    private var isSidebarCollapsed: Bool {
        columnVisibility == .detailOnly
    }

    private var preferredColumnVisibility: NavigationSplitViewVisibility {
        isSidebarCollapsedStored ? .detailOnly : .all
    }

    private var currentTitle: String {
        switch selection {
        case .songs:
            return settings.text(.songs)
        case .albums:
            return settings.text(.albums)
        case .artists:
            return settings.text(.artists)
        case .favorites:
            return settings.text(.favorites)
        case .playlist(let id):
            return musicLibrary.playlists.first(where: { $0.id == id })?.name ?? "Playlist"
        case .folder(let id):
            return musicLibrary.librarySources.first(where: { $0.id == id })?.name ?? "Folder"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .songs:
            SongsView(title: settings.text(.songs), subtitle: "\(musicLibrary.songs.count) \(settings.text(.tracks))")
                .dropToImport()
        case .albums:
            AlbumsView()
                .dropToImport()
        case .artists:
            ArtistsView()
                .dropToImport()
        case .favorites:
            SongsView(
                title: settings.text(.favorites),
                subtitle: "\(musicLibrary.favoriteSongs.count) \(settings.text(.tracks))",
                scopedSongs: musicLibrary.favoriteSongs
            )
                .dropToImport()
        case .playlist(let id):
            if let playlist = musicLibrary.playlists.first(where: { $0.id == id }) {
                SongsView(
                    title: playlist.name,
                    subtitle: "\(playlist.songs.count) \(settings.text(.tracks))",
                    description: playlist.description,
                    scopedSongs: playlist.songs,
                    playlistId: id,
                    columnPreferenceScope: .playlist
                )
                    .dropToImport()
            } else {
                EmptyStateView(title: settings.text(.playlistNotFound), systemImage: "list.bullet")
            }
        case .folder(let id):
            if let source = musicLibrary.librarySources.first(where: { $0.id == id }) {
                SongsView(
                    title: source.name,
                    subtitle: source.path,
                    scopedSongs: musicLibrary.songs(in: source),
                    presentation: .table,
                    columnPreferenceScope: .folder
                )
                .dropToImport()
            } else {
                EmptyStateView(title: settings.text(.folderNotFound), systemImage: "folder")
            }
        }
    }

    private func restorePlaybackSessionIfNeeded() {
        guard !didRestorePlaybackSession, !musicLibrary.songs.isEmpty else { return }
        audioPlayer.restoreLastSession(from: musicLibrary.songs)
        didRestorePlaybackSession = true
    }

    private func openLyricsWindow() {
        if let lyricsWindow = NSApp.windows.first(where: { window in
            window.identifier?.rawValue == "mintPlayer.lyricsWindow" || window.title == "Lyrics"
        }) {
            NSApp.activate()
            lyricsWindow.makeKeyAndOrderFront(nil)
            return
        }

        openWindow(id: "lyrics")
    }
}

private struct CollapsedSidebarNavigationPicker: View {
    @Binding var selection: LibrarySelection
    @EnvironmentObject private var settings: SettingsManager

    private let items: [LibrarySidebarItem] = [.favorites, .songs, .albums, .artists]

    var body: some View {
        NativeCollapsedSidebarTabBar(
            items: items,
            selectedItem: selectedItem,
            titleProvider: tabTitle(for:)
        )
        .fixedSize()
    }

    private var selectedItem: Binding<LibrarySidebarItem?> {
        Binding(
            get: {
                LibrarySidebarItem(selection: selection)
            },
            set: { item in
                guard let item else { return }
                selection = item.selection
            }
        )
    }

    private func tabTitle(for item: LibrarySidebarItem) -> String {
        switch item {
        case .favorites:
            return settings.effectiveLanguage == .chinese ? "喜欢" : "Favorites"
        case .songs, .albums, .artists:
            return item.title(language: settings.effectiveLanguage)
        }
    }
}

private struct NativeCollapsedSidebarTabBar: NSViewRepresentable {
    let items: [LibrarySidebarItem]
    @Binding var selectedItem: LibrarySidebarItem?
    let titleProvider: (LibrarySidebarItem) -> String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedItem: $selectedItem, items: items)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentStyle = .automatic
        control.borderShape = .capsule
        control.trackingMode = .selectOne
        control.segmentDistribution = .fillEqually
        control.controlSize = .regular
        control.target = context.coordinator
        control.action = #selector(Coordinator.selectionChanged(_:))
        configure(control, context: context)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        context.coordinator.selectedItem = $selectedItem
        context.coordinator.items = items
        configure(nsView, context: context)
    }

    private func configure(_ control: NSSegmentedControl, context: Context) {
        control.segmentCount = items.count

        for (index, item) in items.enumerated() {
            let title = titleProvider(item)
            control.setLabel(title, forSegment: index)
            control.setTag(index, forSegment: index)
            control.setAlignment(.center, forSegment: index)
            control.setWidth(segmentWidth(for: title, control: control), forSegment: index)
        }

        if let selectedItem, let selectedIndex = items.firstIndex(of: selectedItem) {
            control.selectedSegment = selectedIndex
        } else {
            control.selectedSegment = -1
        }
    }

    private func segmentWidth(for title: String, control: NSSegmentedControl) -> CGFloat {
        let font = control.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize(for: control.controlSize))
        let measuredWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(measuredWidth + 38)
    }

    final class Coordinator: NSObject {
        var selectedItem: Binding<LibrarySidebarItem?>
        var items: [LibrarySidebarItem]

        init(selectedItem: Binding<LibrarySidebarItem?>, items: [LibrarySidebarItem]) {
            self.selectedItem = selectedItem
            self.items = items
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard items.indices.contains(index) else { return }
            selectedItem.wrappedValue = items[index]
        }
    }
}

private extension LibrarySidebarItem {
    init?(selection: LibrarySelection) {
        switch selection {
        case .favorites:
            self = .favorites
        case .songs:
            self = .songs
        case .albums:
            self = .albums
        case .artists:
            self = .artists
        case .playlist, .folder:
            return nil
        }
    }
}

private struct SidebarToolbarToggleRemover: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.removeSoon(from: nsView)
    }

    final class HostView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.removeSoon(from: self)
        }
    }

    final class Coordinator {
        func removeSoon(from view: NSView) {
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                self.removeSidebarToggle(from: view.window?.toolbar)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
                guard let view else { return }
                self.removeSidebarToggle(from: view.window?.toolbar)
            }
        }

        private func removeSidebarToggle(from toolbar: NSToolbar?) {
            guard let toolbar else { return }
            let toggleIdentifier = NSToolbarItem.Identifier.toggleSidebar

            while let index = toolbar.items.firstIndex(where: { $0.itemIdentifier == toggleIdentifier }) {
                toolbar.removeItem(at: index)
            }
        }
    }
}
