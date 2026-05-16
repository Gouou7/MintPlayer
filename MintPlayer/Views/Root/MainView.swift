import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    
    @State private var selection: LibrarySelection = .songs
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isLyricsPresented = false
    
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
                    isLyricsPresented = true
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
        .background {
            LyricsOverlayWindowPresenter(
                isPresented: $isLyricsPresented,
                song: audioPlayer.currentSong,
                audioPlayer: audioPlayer,
                preferredColorScheme: settings.theme == .dark ? .dark : .light
            )
            .frame(width: 0, height: 0)
        }
        .onChange(of: audioPlayer.currentSong?.id) { _, songID in
            if songID == nil {
                isLyricsPresented = false
            }
        }
        .onAppear {
            columnVisibility = .all
            audioPlayer.onSongStarted = { song in
                musicLibrary.addToRecentlyPlayed(song: song)
            }
        }
        .onDisappear {
            audioPlayer.onSongStarted = nil
        }
    }
    
    private var currentTitle: String {
        switch selection {
        case .songs:
            return "Songs"
        case .albums:
            return "Albums"
        case .artists:
            return "Artists"
        case .recent:
            return "Recently Played"
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
            SongsView(title: "Songs", subtitle: "\(musicLibrary.songs.count) tracks")
                .dropToImport()
        case .albums:
            AlbumsView()
                .dropToImport()
        case .artists:
            ArtistsView()
                .dropToImport()
        case .recent:
            RecentView()
                .dropToImport()
        case .playlist(let id):
            if let playlist = musicLibrary.playlists.first(where: { $0.id == id }) {
                SongsView(
                    title: playlist.name,
                    subtitle: "\(playlist.songs.count) tracks",
                    description: playlist.description,
                    scopedSongs: playlist.songs
                )
                    .dropToImport()
            } else {
                EmptyStateView(title: "Playlist not found", systemImage: "list.bullet")
            }
        case .folder(let id):
            if let source = musicLibrary.librarySources.first(where: { $0.id == id }) {
                SongsView(
                    title: source.name,
                    subtitle: source.path,
                    scopedSongs: musicLibrary.songs(in: source),
                    presentation: .table
                )
                .dropToImport()
            } else {
                EmptyStateView(title: "Folder not found", systemImage: "folder")
            }
        }
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

private struct LyricsOverlayWindowPresenter: NSViewRepresentable {
    @Binding var isPresented: Bool
    let song: Song?
    let audioPlayer: AudioPlayer
    let preferredColorScheme: ColorScheme?
    
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
        context.coordinator.update(
            from: nsView,
            isPresented: $isPresented,
            song: song,
            audioPlayer: audioPlayer,
            preferredColorScheme: preferredColorScheme
        )
    }
    
    static func dismantleNSView(_ nsView: HostView, coordinator: Coordinator) {
        coordinator.closeOverlay()
    }
    
    final class HostView: NSView {
        weak var coordinator: Coordinator?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.configureSoon(from: self)
        }
    }
    
    final class Coordinator {
        private weak var parentWindow: NSWindow?
        private var mainWindow: LyricsOverlayChildWindow?
        private var chromeWindow: LyricsOverlayChildWindow?
        private var mainHostingController: NSHostingController<AnyView>?
        private var chromeHostingController: NSHostingController<AnyView>?
        private var windowObservers: [NSObjectProtocol] = []
        private var keyEventMonitor: Any?
        private var isPresented: Binding<Bool>?
        private var song: Song?
        private var audioPlayer: AudioPlayer?
        private var preferredColorScheme: ColorScheme?
        
        private var originalTitleVisibility: NSWindow.TitleVisibility?
        private var originalTitlebarAppearsTransparent: Bool?
        private var didAdjustTitlebar = false
        
        private let topChromeHeight: CGFloat = 72
        
        deinit {
            closeOverlay()
        }
        
        func update(
            from view: NSView,
            isPresented: Binding<Bool>,
            song: Song?,
            audioPlayer: AudioPlayer,
            preferredColorScheme: ColorScheme?
        ) {
            self.isPresented = isPresented
            self.song = song
            self.audioPlayer = audioPlayer
            self.preferredColorScheme = preferredColorScheme
            
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.configureOverlay(from: view)
            }
        }
        
        func configureSoon(from view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.configureOverlay(from: view)
            }
        }
        
        func closeOverlay() {
            removeWindowObservers()
            removeKeyEventMonitor()
            restoreTitlebarState()
            
            if let mainWindow {
                parentWindow?.removeChildWindow(mainWindow)
                mainWindow.orderOut(nil)
                mainWindow.close()
            }
            
            if let chromeWindow {
                parentWindow?.removeChildWindow(chromeWindow)
                chromeWindow.orderOut(nil)
                chromeWindow.close()
            }
            
            mainWindow = nil
            chromeWindow = nil
            mainHostingController = nil
            chromeHostingController = nil
        }
        
        private func configureOverlay(from view: NSView) {
            guard let window = view.window else {
                closeOverlay()
                return
            }
            
            if parentWindow !== window {
                closeOverlay()
                parentWindow = window
                installWindowObservers(for: window)
            }
            
            guard isPresented?.wrappedValue == true, let song, let audioPlayer else {
                closeOverlay()
                return
            }
            
            applyTitlebarState(to: window)
            ensureOverlayWindows(for: window)
            updateOverlayRoots(song: song, audioPlayer: audioPlayer)
            updateOverlayFrames(for: window)
        }
        
        private func ensureOverlayWindows(for window: NSWindow) {
            if mainWindow == nil {
                let overlayWindow = LyricsOverlayChildWindow()
                configureWindow(overlayWindow)
                mainWindow = overlayWindow
                window.addChildWindow(overlayWindow, ordered: .above)
            }
            
            if chromeWindow == nil {
                let overlayWindow = LyricsOverlayChildWindow()
                configureWindow(overlayWindow)
                chromeWindow = overlayWindow
                window.addChildWindow(overlayWindow, ordered: .above)
            }
            
            ensureKeyEventMonitor()
        }
        
        private func configureWindow(_ window: LyricsOverlayChildWindow) {
            window.styleMask = [.borderless]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            window.acceptsMouseMovedEvents = true
            window.level = .floating
        }
        
        private func updateOverlayRoots(song: Song, audioPlayer: AudioPlayer) {
            guard let isPresented else { return }
            
            let mainRootView = AnyView(
                LyricsOverlayView(song: song, isPresented: isPresented)
                    .environmentObject(audioPlayer)
                    .preferredColorScheme(preferredColorScheme)
            )
            
            if let mainHostingController {
                mainHostingController.rootView = mainRootView
            } else {
                let hostingController = NSHostingController(rootView: mainRootView)
                hostingController.view.wantsLayer = true
                hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
                mainHostingController = hostingController
                mainWindow?.contentViewController = hostingController
            }
            
            let chromeRootView = AnyView(
                LyricsOverlayChromeCoverView(song: song)
                    .preferredColorScheme(preferredColorScheme)
            )
            
            if let chromeHostingController {
                chromeHostingController.rootView = chromeRootView
            } else {
                let hostingController = NSHostingController(rootView: chromeRootView)
                hostingController.view.wantsLayer = true
                hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
                chromeHostingController = hostingController
                chromeWindow?.contentViewController = hostingController
            }
        }
        
        private func updateOverlayFrames(for window: NSWindow) {
            let parentFrame = window.frame
            let trafficSafeWidth = trafficLightSafeWidth(for: window)
            let chromeHeight = min(topChromeHeight, max(1, parentFrame.height))
            let mainHeight = max(1, parentFrame.height - chromeHeight)
            let chromeWidth = max(1, parentFrame.width - trafficSafeWidth)
            
            mainWindow?.setFrame(
                NSRect(
                    x: parentFrame.minX,
                    y: parentFrame.minY,
                    width: parentFrame.width,
                    height: mainHeight
                ),
                display: true
            )
            
            chromeWindow?.setFrame(
                NSRect(
                    x: parentFrame.minX + trafficSafeWidth,
                    y: parentFrame.maxY - chromeHeight,
                    width: chromeWidth,
                    height: chromeHeight
                ),
                display: true
            )
        }
        
        private func trafficLightSafeWidth(for window: NSWindow) -> CGFloat {
            guard
                let zoomButton = window.standardWindowButton(.zoomButton),
                let buttonSuperview = zoomButton.superview
            else {
                return 136
            }
            
            let buttonFrame = buttonSuperview.convert(zoomButton.frame, to: nil)
            return max(136, buttonFrame.maxX + 42)
        }
        
        private func applyTitlebarState(to window: NSWindow) {
            guard !didAdjustTitlebar else { return }
            
            originalTitleVisibility = window.titleVisibility
            originalTitlebarAppearsTransparent = window.titlebarAppearsTransparent
            didAdjustTitlebar = true
            
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
        
        private func restoreTitlebarState() {
            guard let window = parentWindow, didAdjustTitlebar else { return }
            
            if let originalTitleVisibility {
                window.titleVisibility = originalTitleVisibility
            }
            
            if let originalTitlebarAppearsTransparent {
                window.titlebarAppearsTransparent = originalTitlebarAppearsTransparent
            }
            
            didAdjustTitlebar = false
            originalTitleVisibility = nil
            originalTitlebarAppearsTransparent = nil
        }
        
        private func installWindowObservers(for window: NSWindow) {
            removeWindowObservers()
            
            let notifications: [NSNotification.Name] = [
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
                NSWindow.didBecomeKeyNotification,
                NSWindow.didChangeScreenNotification
            ]
            
            windowObservers = notifications.map { notificationName in
                NotificationCenter.default.addObserver(
                    forName: notificationName,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    guard let self, let window else { return }
                    self.updateOverlayFrames(for: window)
                }
            }
            
            let closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.closeOverlay()
            }
            
            windowObservers.append(closeObserver)
        }
        
        private func removeWindowObservers() {
            for observer in windowObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            windowObservers.removeAll()
        }
        
        private func ensureKeyEventMonitor() {
            guard keyEventMonitor == nil else { return }
            
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.mainWindow != nil else { return event }
                
                if event.keyCode == 53 {
                    self.isPresented?.wrappedValue = false
                    self.closeOverlay()
                    return nil
                }
                
                return event
            }
        }
        
        private func removeKeyEventMonitor() {
            if let keyEventMonitor {
                NSEvent.removeMonitor(keyEventMonitor)
                self.keyEventMonitor = nil
            }
        }
    }
}

private final class LyricsOverlayChildWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        false
    }
}
