import SwiftUI
import AppKit

struct MainView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    @State private var selection: LibrarySelection = .songs
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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
        .frame(minWidth: 980, minHeight: 600)
        .background {
            NoncollapsibleSidebarView()
                .frame(width: 0, height: 0)
        }
        .onAppear {
            columnVisibility = .all
            restorePlaybackSessionIfNeeded()
            audioPlayer.onSongStarted = { song in
                musicLibrary.recordSongPlayback(song)
            }
        }
        .onChange(of: musicLibrary.songs) { _, _ in
            restorePlaybackSessionIfNeeded()
        }
        .onDisappear {
            audioPlayer.onSongStarted = nil
        }
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

private struct NoncollapsibleSidebarView: NSViewRepresentable {
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
        context.coordinator.configureSoon(from: nsView)
    }

    final class HostView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.configureSoon(from: self)
        }
    }

    final class Coordinator {
        func configureSoon(from view: NSView) {
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                self.configure(from: view)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
                guard let view else { return }
                self.configure(from: view)
            }
        }

        private func configure(from view: NSView) {
            guard let window = view.window else { return }
            configureSplitViewControllers(in: window.contentViewController)
            removeSidebarToggle(from: window.toolbar)
        }

        private func configureSplitViewControllers(in viewController: NSViewController?) {
            guard let viewController else { return }

            if let splitViewController = viewController as? NSSplitViewController,
               let sidebarItem = splitViewController.splitViewItems.first {
                sidebarItem.canCollapse = false
                sidebarItem.minimumThickness = 200
                sidebarItem.maximumThickness = 300
                sidebarItem.preferredThicknessFraction = 0
            }

            viewController.children.forEach(configureSplitViewControllers)
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
