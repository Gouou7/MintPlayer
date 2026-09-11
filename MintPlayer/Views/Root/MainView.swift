import SwiftUI
import AppKit

struct MainView: View {
    private static let sidebarCollapsedDefaultsKey = AppConfiguration.userDefaultsKey("sidebar.isCollapsed")

    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    @AppStorage(Self.sidebarCollapsedDefaultsKey) private var isSidebarCollapsedStored = false
    @State private var selection: LibrarySelection = .songs
    @State private var columnVisibility: NavigationSplitViewVisibility = UserDefaults.standard.bool(forKey: Self.sidebarCollapsedDefaultsKey) ? .detailOnly : .all
    @State private var didRestorePlaybackSession = false
    @State private var isLyricsMounted = false
    @State private var isLyricsVisible = false
    @State private var isLyricsImmersiveFullScreen = false
    @State private var lyricsPresentationGeneration = 0

    private let playerBarWidth: CGFloat = 648

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(
                        min: SidebarWidth.minimum,
                        ideal: SidebarWidth.ideal,
                        max: SidebarWidth.maximum
                    )
                    .toolbar(removing: isLyricsMounted ? .sidebarToggle : nil)
            } detail: {
                ZStack(alignment: .bottom) {
                    contentView
                        .safeAreaInset(edge: .top, spacing: 0) { LibraryActivityView() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    PlayerBarView {
                        showLyrics()
                    }
                    .frame(width: playerBarWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)
                }
                .background(MintTheme.contentBackground)
            }
            .navigationTitle(isLyricsMounted ? "" : currentTitle)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .disabled(isLyricsMounted)
            .accessibilityHidden(isLyricsMounted)

            if isLyricsMounted, let currentSong = audioPlayer.currentSong {
                EmbeddedLyricsPresentationLayer(
                    song: currentSong,
                    isVisible: isLyricsVisible,
                    reducesMotion: accessibilityReduceMotion,
                    showsImmersiveControls: isLyricsImmersiveFullScreen
                ) {
                    dismissEmbeddedLyrics()
                }
                .zIndex(1)
            }
        }
        .environment(\.isPlayerOverlayPresented, isLyricsMounted)
        .toolbarBackgroundVisibility(isLyricsMounted ? .hidden : .automatic, for: .windowToolbar)
        .toolbar {
            if isLyricsMounted {
                if !isLyricsImmersiveFullScreen {
                    ToolbarSpacer(.flexible)

                    ToolbarItem(id: "embeddedLyrics.close", placement: .automatic) {
                        Button(action: dismissEmbeddedLyrics) {
                            Label(settings.text(.close), systemImage: "chevron.down")
                        }
                        .labelStyle(.iconOnly)
                        .environment(\.colorScheme, .dark)
                        .help(settings.text(.close))
                        .accessibilityLabel(settings.text(.close))
                    }
                }
            } else if isSidebarCollapsed {
                ToolbarItem(placement: .principal) {
                    CollapsedSidebarNavigationPicker(selection: $selection)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 600)
        .background {
            MainWindowLyricsChromeConfigurator(
                isPresented: isLyricsMounted,
                isImmersiveFullScreen: $isLyricsImmersiveFullScreen
            )
                .frame(width: 0, height: 0)
            PlaybackSpaceKeyHandler()
                .frame(width: 0, height: 0)
        }
        .onAppear {
            columnVisibility = preferredColumnVisibility
            restorePlaybackSessionIfNeeded()
            audioPlayer.onPlaybackCounted = { songId in
                musicLibrary.recordQualifiedPlayback(for: songId)
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
        .onChange(of: musicLibrary.songs) { _, songs in
            audioPlayer.refreshLibrarySongs(songs)
            restorePlaybackSessionIfNeeded()
        }
        .onChange(of: audioPlayer.currentSong?.id) { _, songID in
            if songID == nil, isLyricsMounted {
                dismissEmbeddedLyrics()
            }
        }
        .onDisappear {
            audioPlayer.onPlaybackCounted = nil
        }
    }

    private var isSidebarCollapsed: Bool {
        columnVisibility == .detailOnly
    }

    private var preferredColumnVisibility: NavigationSplitViewVisibility {
        isSidebarCollapsedStored ? .detailOnly : .all
    }

    private var lyricsPresentationAnimation: Animation {
        .easeInOut(duration: accessibilityReduceMotion ? 0.16 : 0.38)
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
            return musicLibrary.playlists.first(where: { $0.id == id })?.name ?? settings.text(.playlists)
        case .folder(let id):
            return musicLibrary.librarySources.first(where: { $0.id == id })?.name ?? settings.text(.folders)
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

    private func showLyrics() {
        guard audioPlayer.currentSong != nil else { return }

        if let lyricsWindow = NSApp.windows.first(where: { window in
            window.identifier?.rawValue == "mintPlayer.lyricsWindow" || window.title == "Lyrics"
        }) {
            NSApp.activate()
            lyricsWindow.makeKeyAndOrderFront(nil)
            return
        }

        switch settings.lyricsPresentationMode {
        case .embedded:
            presentEmbeddedLyrics()
        case .separateWindow:
            openWindow(id: "lyrics")
        }
    }

    private func presentEmbeddedLyrics() {
        guard !isLyricsMounted else { return }

        lyricsPresentationGeneration += 1
        let generation = lyricsPresentationGeneration

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isLyricsVisible = false
            isLyricsMounted = true
        }

        DispatchQueue.main.async {
            DispatchQueue.main.async {
                guard isLyricsMounted, lyricsPresentationGeneration == generation else { return }
                withAnimation(lyricsPresentationAnimation) {
                    isLyricsVisible = true
                }
            }
        }
    }

    private func dismissEmbeddedLyrics() {
        guard isLyricsMounted else { return }

        lyricsPresentationGeneration += 1
        let generation = lyricsPresentationGeneration
        guard isLyricsVisible else {
            isLyricsMounted = false
            return
        }

        withAnimation(lyricsPresentationAnimation, completionCriteria: .logicallyComplete) {
            isLyricsVisible = false
        } completion: {
            guard lyricsPresentationGeneration == generation, !isLyricsVisible else { return }
            isLyricsMounted = false
        }
    }
}

private struct MainWindowLyricsChromeConfigurator: NSViewRepresentable {
    let isPresented: Bool
    @Binding var isImmersiveFullScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isImmersiveFullScreen: $isImmersiveFullScreen)
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.updateImmersiveBinding($isImmersiveFullScreen)
        context.coordinator.configureSoon(from: nsView, isPresented: isPresented)
    }

    static func dismantleNSView(_ nsView: HostView, coordinator: Coordinator) {
        coordinator.restoreWindow()
    }

    final class HostView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.configureSoon(from: self)
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                coordinator?.restoreWindow()
            }
            super.viewWillMove(toWindow: newWindow)
        }
    }

    final class Coordinator {
        private weak var configuredWindow: NSWindow?
        private var requestedPresentation = false
        private var isWindowFullScreen = false
        private var originalWindowState: WindowState?
        private var fullScreenObservers: [NSObjectProtocol] = []
        private var immersiveBinding: Binding<Bool>
        private var lastPublishedImmersiveState = false

        init(isImmersiveFullScreen: Binding<Bool>) {
            immersiveBinding = isImmersiveFullScreen
        }

        deinit {
            removeFullScreenObservers()
        }

        func updateImmersiveBinding(_ binding: Binding<Bool>) {
            immersiveBinding = binding
        }

        func configureSoon(from view: NSView, isPresented: Bool? = nil) {
            if let isPresented {
                requestedPresentation = isPresented
            }

            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.configureWindow(from: view)
            }
        }

        func restoreWindow() {
            if let window = configuredWindow {
                restorePresentationState(on: window)
            }
            originalWindowState = nil
            removeFullScreenObservers()
            configuredWindow = nil
            publishImmersiveState(false)
        }

        private func configureWindow(from view: NSView) {
            guard let window = view.window else {
                restoreWindow()
                return
            }

            if configuredWindow !== window {
                restoreWindow()
                configuredWindow = window
                isWindowFullScreen = window.styleMask.contains(.fullScreen)
                observeFullScreenChanges(for: window)
            }

            if requestedPresentation {
                if originalWindowState == nil {
                    originalWindowState = WindowState(window: window)
                }
                applyLyricsPresentation(to: window)
            } else {
                restorePresentationState(on: window)
                originalWindowState = nil
            }

            publishImmersiveState(requestedPresentation && isWindowFullScreen)
        }

        private func applyLyricsPresentation(to window: NSWindow) {
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none

            if isWindowFullScreen {
                window.toolbar?.isVisible = false
            } else if let toolbarIsVisible = originalWindowState?.toolbarIsVisible {
                window.toolbar?.isVisible = toolbarIsVisible
            }
        }

        private func restorePresentationState(on window: NSWindow) {
            guard let originalWindowState else { return }

            if originalWindowState.usesFullSizeContentView {
                window.styleMask.insert(.fullSizeContentView)
            } else {
                window.styleMask.remove(.fullSizeContentView)
            }
            window.titlebarAppearsTransparent = originalWindowState.titlebarAppearsTransparent
            window.titleVisibility = originalWindowState.titleVisibility
            window.titlebarSeparatorStyle = originalWindowState.titlebarSeparatorStyle
            if let toolbarIsVisible = originalWindowState.toolbarIsVisible {
                window.toolbar?.isVisible = toolbarIsVisible
            }
        }

        private func observeFullScreenChanges(for window: NSWindow) {
            removeFullScreenObservers()

            let center = NotificationCenter.default
            let notifications: [(NSNotification.Name, Bool)] = [
                (NSWindow.willEnterFullScreenNotification, true),
                (NSWindow.didEnterFullScreenNotification, true),
                (NSWindow.willExitFullScreenNotification, false),
                (NSWindow.didExitFullScreenNotification, false)
            ]

            fullScreenObservers = notifications.map { name, isFullScreen in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    guard let self, let window, self.configuredWindow === window else { return }
                    self.handleFullScreenChange(isFullScreen, for: window)
                }
            }
        }

        private func handleFullScreenChange(_ isFullScreen: Bool, for window: NSWindow) {
            isWindowFullScreen = isFullScreen

            if requestedPresentation {
                applyLyricsPresentation(to: window)
            }
            publishImmersiveState(requestedPresentation && isFullScreen)

            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.configuredWindow === window else { return }
                if self.requestedPresentation {
                    self.applyLyricsPresentation(to: window)
                }
            }
        }

        private func publishImmersiveState(_ isImmersive: Bool) {
            guard lastPublishedImmersiveState != isImmersive else { return }
            lastPublishedImmersiveState = isImmersive

            DispatchQueue.main.async { [weak self] in
                guard let self, self.immersiveBinding.wrappedValue != isImmersive else { return }
                self.immersiveBinding.wrappedValue = isImmersive
            }
        }

        private func removeFullScreenObservers() {
            fullScreenObservers.forEach(NotificationCenter.default.removeObserver)
            fullScreenObservers = []
        }

        private struct WindowState {
            let usesFullSizeContentView: Bool
            let titlebarAppearsTransparent: Bool
            let titleVisibility: NSWindow.TitleVisibility
            let titlebarSeparatorStyle: NSTitlebarSeparatorStyle
            let toolbarIsVisible: Bool?

            init(window: NSWindow) {
                usesFullSizeContentView = window.styleMask.contains(.fullSizeContentView)
                titlebarAppearsTransparent = window.titlebarAppearsTransparent
                titleVisibility = window.titleVisibility
                titlebarSeparatorStyle = window.titlebarSeparatorStyle
                toolbarIsVisible = window.toolbar?.isVisible
            }
        }
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
