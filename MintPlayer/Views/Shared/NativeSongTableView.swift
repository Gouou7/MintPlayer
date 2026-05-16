import SwiftUI
import AppKit

struct NativeSongTableView: NSViewRepresentable {
    enum Style: Equatable {
        case detailed
        case compactFolder
        case detailSongs(subtitle: DetailSubtitle)
        
        var rowHeight: CGFloat {
            switch self {
            case .detailed:
                return 64
            case .compactFolder:
                return 28
            case .detailSongs:
                return 58
            }
        }
        
        var showsHeader: Bool {
            switch self {
            case .detailSongs:
                return false
            case .detailed, .compactFolder:
                return true
            }
        }
    }
    
    enum DetailSubtitle: Equatable {
        case none
        case album
        case artist
    }
    
    @EnvironmentObject private var musicLibrary: MusicLibrary
    
    let songs: [Song]
    let style: Style
    @Binding var selectedSongIDs: Set<Song.ID>
    @Binding var sortOrder: [KeyPathComparator<Song>]
    let onPlay: (Song, [Song]) -> Void
    let onPlayNext: (Song) -> Void
    let onAddToQueue: (Song) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let tableView = InteractiveSongTableView()
        tableView.interactionDelegate = context.coordinator
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.doubleClick(_:))
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.usesAlternatingRowBackgroundColors = style == .compactFolder
        tableView.selectionHighlightStyle = .regular
        tableView.setDraggingSourceOperationMask(.copy, forLocal: true)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.documentView = tableView
        
        context.coordinator.tableView = tableView
        context.coordinator.configureColumns(for: style)
        context.coordinator.configureScrollBehavior(scrollView, for: style)
        context.coordinator.observeClipView(scrollView.contentView)
        context.coordinator.resizeColumnsToFit()
        context.coordinator.lastSongIDs = songs.map(\.id)
        context.coordinator.syncSelectionToTable()
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = scrollView.documentView as? InteractiveSongTableView else { return }
        
        let styleChanged = context.coordinator.currentStyle != style
        if styleChanged {
            context.coordinator.configureColumns(for: style)
            context.coordinator.configureScrollBehavior(scrollView, for: style)
        }
        
        let songIDs = songs.map(\.id)
        if styleChanged || context.coordinator.lastSongIDs != songIDs {
            context.coordinator.lastSongIDs = songIDs
            tableView.reloadData()
        }
        
        context.coordinator.resizeColumnsToFit()
        context.coordinator.syncSelectionToTable()
    }
}

private protocol SongTableInteractionDelegate: AnyObject {
    func selectRowForInteraction(_ row: Int)
}

private final class InteractiveSongTableView: NSTableView {
    weak var interactionDelegate: SongTableInteractionDelegate?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0 else { return nil }
        
        interactionDelegate?.selectRowForInteraction(row)
        return (interactionDelegate as? NativeSongTableView.Coordinator)?.menu(forRow: row)
    }
}

private enum NativeSongColumn: String, CaseIterable {
    case song
    case title
    case artist
    case album
    case genre
    case type
    case duration
    case index
}

private enum NativeSongTableMetrics {
    static let rightSafeInset: CGFloat = 56
    static let durationTextWidth: CGFloat = 60
    static let detailedSongMinWidth: CGFloat = 76
    static let detailedArtistMinWidth: CGFloat = 44
    static let detailSongMinWidth: CGFloat = 64
    static let detailIndexWidth: CGFloat = 28
}

extension NativeSongTableView {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, SongTableInteractionDelegate {
        var parent: NativeSongTableView
        fileprivate weak var tableView: InteractiveSongTableView?
        var currentStyle: Style?
        var lastSongIDs: [Song.ID] = []
        private var isSyncingSelection = false
        private var menuSongs: [Song] = []
        private var clipViewObservers: [NSObjectProtocol] = []
        
        init(parent: NativeSongTableView) {
            self.parent = parent
        }
        
        func configureColumns(for style: Style) {
            guard let tableView else { return }
            
            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
            tableView.rowHeight = style.rowHeight
            tableView.headerView = style.showsHeader ? NSTableHeaderView() : nil
            
            switch style {
            case .detailed:
                addColumn(.song, title: "歌曲", width: 420, minWidth: NativeSongTableMetrics.detailedSongMinWidth, sortKey: "title")
                addColumn(.artist, title: "艺人", width: 260, minWidth: NativeSongTableMetrics.detailedArtistMinWidth, sortKey: "artist")
                addColumn(.duration, title: "时长", width: NativeSongTableMetrics.durationTextWidth, minWidth: NativeSongTableMetrics.durationTextWidth, sortKey: "duration")
            case .compactFolder:
                addColumn(.title, title: "Title", width: 320, minWidth: 220, sortKey: "title")
                addColumn(.artist, title: "Artist", width: 180, minWidth: 140, sortKey: "artist")
                addColumn(.album, title: "Album", width: 200, minWidth: 140, sortKey: "album")
                addColumn(.genre, title: "Genre", width: 120, minWidth: 90, sortKey: "genre")
                addColumn(.type, title: "Type", width: 70, minWidth: 56, sortKey: "type")
                addColumn(.duration, title: "Duration", width: 84, minWidth: 72, sortKey: "duration")
            case .detailSongs:
                addColumn(.index, title: "", width: NativeSongTableMetrics.detailIndexWidth, minWidth: 24)
                addColumn(.song, title: "", width: 420, minWidth: NativeSongTableMetrics.detailSongMinWidth, sortKey: "title")
                addColumn(.duration, title: "", width: NativeSongTableMetrics.durationTextWidth, minWidth: NativeSongTableMetrics.durationTextWidth, sortKey: "duration")
            }
            
            currentStyle = style
        }
        
        deinit {
            clipViewObservers.forEach(NotificationCenter.default.removeObserver)
        }
        
        func configureScrollBehavior(_ scrollView: NSScrollView, for style: Style) {
            let shouldResizeColumns = style != .compactFolder
            scrollView.hasHorizontalScroller = !shouldResizeColumns
            scrollView.autohidesScrollers = shouldResizeColumns
            tableView?.columnAutoresizingStyle = shouldResizeColumns ? .noColumnAutoresizing : .lastColumnOnlyAutoresizingStyle
        }
        
        func observeClipView(_ clipView: NSClipView) {
            clipViewObservers.forEach(NotificationCenter.default.removeObserver)
            clipViewObservers.removeAll()
            
            clipView.postsBoundsChangedNotifications = true
            clipView.postsFrameChangedNotifications = true
            
            for notificationName in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
                let observer = NotificationCenter.default.addObserver(
                    forName: notificationName,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    self?.resizeColumnsToFit()
                }
                clipViewObservers.append(observer)
            }
        }
        
        func resizeColumnsToFit() {
            guard parent.style != .compactFolder,
                  let tableView,
                  let scrollView = tableView.enclosingScrollView
            else { return }
            
            let clipWidth = max(0, scrollView.contentView.bounds.width)
            let usableWidth = max(0, clipWidth - NativeSongTableMetrics.rightSafeInset)
            guard usableWidth > 1 else { return }
            tableView.setFrameSize(NSSize(width: usableWidth, height: tableView.frame.height))
            
            switch parent.style {
            case .detailed:
                setColumn(.duration, width: NativeSongTableMetrics.durationTextWidth)
                
                let fixedWidth = columnWidth(.duration)
                let remaining = max(0, usableWidth - fixedWidth)
                var artistWidth = min(max(remaining * 0.3, minWidth(.artist)), 280)
                if remaining - artistWidth < minWidth(.song) {
                    artistWidth = max(minWidth(.artist), remaining - minWidth(.song))
                }
                let songWidth = max(remaining - artistWidth, minWidth(.song))
                setColumn(.artist, width: artistWidth)
                setColumn(.song, width: songWidth)
            case .detailSongs:
                setColumn(.index, width: NativeSongTableMetrics.detailIndexWidth)
                setColumn(.duration, width: NativeSongTableMetrics.durationTextWidth)
                
                let fixedWidth = columnWidth(.index) + columnWidth(.duration)
                setColumn(.song, width: max(usableWidth - fixedWidth, minWidth(.song)))
            case .compactFolder:
                break
            }
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.songs.count
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let verticalInset: CGFloat = parent.style == .compactFolder ? 2 : 3
            return MintTableRowView(verticalInset: verticalInset)
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.songs.indices.contains(row), let column = tableColumn.flatMap({ NativeSongColumn(rawValue: $0.identifier.rawValue) }) else {
                return nil
            }
            
            let song = parent.songs[row]
            switch (parent.style, column) {
            case (.detailed, .song):
                return hostingView(DetailedNativeSongCell(song: song))
            case (.detailed, .artist):
                return hostingView(TextCell(text: song.artist.isEmpty ? "Unknown Artist" : song.artist, weight: .semibold))
            case (.detailed, .duration):
                return hostingView(DurationCell(text: formatDuration(song.duration)))
            case (.compactFolder, .title):
                return hostingView(TextCell(text: song.title))
            case (.compactFolder, .artist):
                return hostingView(TextCell(text: song.artist))
            case (.compactFolder, .album):
                return hostingView(TextCell(text: song.album))
            case (.compactFolder, .genre):
                return hostingView(TextCell(text: song.displayGenre, color: .secondary))
            case (.compactFolder, .type):
                return hostingView(TextCell(text: song.fileType, color: .secondary))
            case (.compactFolder, .duration):
                return hostingView(TextCell(text: formatDuration(song.duration, padded: true), color: .secondary, monospaced: true))
            case (.detailSongs, .index):
                return hostingView(TextCell(text: "\(row + 1)", color: .secondary, alignment: .trailing))
            case (.detailSongs(let subtitle), .song):
                return hostingView(DetailNativeSongCell(song: song, subtitle: detailSubtitle(for: song, mode: subtitle)))
            case (.detailSongs, .duration):
                return hostingView(DurationCell(text: formatDuration(song.duration), color: .secondary))
            default:
                return hostingView(EmptyView())
            }
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection, let tableView else { return }
            parent.selectedSongIDs = Set(tableView.selectedRowIndexes.compactMap { row in
                parent.songs.indices.contains(row) ? parent.songs[row].id : nil
            })
        }
        
        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first else { return }
            let order: SortOrder = descriptor.ascending ? .forward : .reverse
            
            switch descriptor.key {
            case "title":
                parent.sortOrder = [KeyPathComparator(\Song.title, order: order)]
            case "artist":
                parent.sortOrder = [KeyPathComparator(\Song.artist, order: order)]
            case "album":
                parent.sortOrder = [KeyPathComparator(\Song.album, order: order)]
            case "genre":
                parent.sortOrder = [KeyPathComparator(\Song.displayGenre, order: order)]
            case "type":
                parent.sortOrder = [KeyPathComparator(\Song.fileType, order: order)]
            case "duration":
                parent.sortOrder = [KeyPathComparator(\Song.duration, order: order)]
            default:
                break
            }
        }
        
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard parent.songs.indices.contains(row) else { return nil }
            if !tableView.isRowSelected(row) {
                selectRowForInteraction(row)
            }
            return SongDragPayload.pasteboardItem(for: parent.songs[row])
        }
        
        func selectRowForInteraction(_ row: Int) {
            guard let tableView, parent.songs.indices.contains(row) else { return }
            
            if !tableView.isRowSelected(row) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: tableView))
            }
        }
        
        func menu(forRow row: Int) -> NSMenu {
            selectRowForInteraction(row)
            menuSongs = selectedSongs()
            return makeMenu()
        }
        
        @objc func doubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow >= 0 ? sender.clickedRow : sender.selectedRow
            guard row >= 0, parent.songs.indices.contains(row) else { return }
            if !sender.isRowSelected(row) {
                selectRowForInteraction(row)
            }
            
            let songs = selectedSongs()
            guard let firstSong = songs.first ?? (parent.songs.indices.contains(row) ? parent.songs[row] : nil) else { return }
            parent.onPlay(firstSong, parent.songs)
        }
        
        func syncSelectionToTable() {
            guard let tableView else { return }
            let indexes = IndexSet(parent.songs.indices.filter { parent.selectedSongIDs.contains(parent.songs[$0].id) })
            guard indexes != tableView.selectedRowIndexes else { return }
            
            isSyncingSelection = true
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            isSyncingSelection = false
        }
        
        private func addColumn(_ id: NativeSongColumn, title: String, width: CGFloat, minWidth: CGFloat, sortKey: String? = nil) {
            guard let tableView else { return }
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id.rawValue))
            column.title = title
            column.width = width
            column.minWidth = minWidth
            column.resizingMask = .userResizingMask
            
            if let sortKey {
                let isStringSort = sortKey != "duration"
                column.sortDescriptorPrototype = NSSortDescriptor(
                    key: sortKey,
                    ascending: true,
                    selector: isStringSort ? #selector(NSString.localizedCaseInsensitiveCompare(_:)) : nil
                )
            }
            
            tableView.addTableColumn(column)
        }
        
        private func column(_ id: NativeSongColumn) -> NSTableColumn? {
            tableView?.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(id.rawValue))
        }
        
        private func setColumn(_ id: NativeSongColumn, width: CGFloat) {
            guard let column = column(id) else { return }
            column.width = max(column.minWidth, width)
        }
        
        private func columnWidth(_ id: NativeSongColumn) -> CGFloat {
            column(id)?.width ?? 0
        }
        
        private func minWidth(_ id: NativeSongColumn) -> CGFloat {
            column(id)?.minWidth ?? 0
        }
        
        private func selectedSongs() -> [Song] {
            guard let tableView else {
                return parent.songs.filter { parent.selectedSongIDs.contains($0.id) }
            }
            
            let songsFromTableSelection = tableView.selectedRowIndexes.compactMap { row in
                parent.songs.indices.contains(row) ? parent.songs[row] : nil
            }
            
            if !songsFromTableSelection.isEmpty {
                return songsFromTableSelection
            }
            
            let row = tableView.selectedRow
            return parent.songs.indices.contains(row) ? [parent.songs[row]] : []
        }
        
        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            menu.addItem(menuItem("Play", systemImage: "play.fill", action: #selector(playSongs)))
            menu.addItem(menuItem("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward", action: #selector(playNext)))
            menu.addItem(menuItem("Add to Queue", systemImage: "text.badge.plus", action: #selector(addToQueue)))
            
            if !parent.musicLibrary.playlists.isEmpty {
                let playlistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
                playlistItem.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Add to Playlist")
                let submenu = NSMenu()
                for playlist in parent.musicLibrary.playlists {
                    let item = menuItem(playlist.name, systemImage: "plus", action: #selector(addToPlaylist(_:)))
                    item.representedObject = playlist.id.uuidString
                    submenu.addItem(item)
                }
                menu.setSubmenu(submenu, for: playlistItem)
                menu.addItem(playlistItem)
            }
            
            menu.addItem(.separator())
            menu.addItem(menuItem("Show in Finder", systemImage: "folder", action: #selector(showInFinder)))
            menu.addItem(menuItem("Remove from Library", systemImage: "trash", action: #selector(removeFromLibrary)))
            return menu
        }
        
        private func menuItem(_ title: String, systemImage: String, action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = !menuSongs.isEmpty
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
            return item
        }
        
        @objc private func playSongs() {
            guard let firstSong = menuSongs.first else { return }
            parent.onPlay(firstSong, parent.songs)
        }
        
        @objc private func playNext() {
            menuSongs.forEach(parent.onPlayNext)
        }
        
        @objc private func addToQueue() {
            menuSongs.forEach(parent.onAddToQueue)
        }
        
        @objc private func addToPlaylist(_ sender: NSMenuItem) {
            guard let idString = sender.representedObject as? String, let id = UUID(uuidString: idString) else { return }
            parent.musicLibrary.addSongsToPlaylist(menuSongs, playlistId: id)
        }
        
        @objc private func showInFinder() {
            guard let firstSong = menuSongs.first else { return }
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: firstSong.path)])
        }
        
        @objc private func removeFromLibrary() {
            let ids = Set(menuSongs.map(\.id))
            parent.musicLibrary.deleteSongs(withIds: ids)
            parent.selectedSongIDs.subtract(ids)
        }
        
        private func hostingView<V: View>(_ view: V) -> NSView {
            let hostingView = NSHostingView(rootView: view)
            hostingView.sizingOptions = []
            return hostingView
        }
        
        private func detailSubtitle(for song: Song, mode: DetailSubtitle) -> String? {
            switch mode {
            case .none:
                return nil
            case .album:
                return song.album
            case .artist:
                return song.artist
            }
        }
    }
}

private struct DetailedNativeSongCell: View {
    let song: Song
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(path: song.coverPath, cornerRadius: 7, targetSize: CGSize(width: 46, height: 46))
                .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.album.isEmpty ? "Unknown Album" : song.album)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct DetailNativeSongCell: View {
    let song: Song
    let subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title)
                .font(.headline)
                .lineLimit(1)
            
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct TextCell: View {
    let text: String
    var color: HierarchicalShapeStyle = .primary
    var weight: Font.Weight = .regular
    var alignment: Alignment = .leading
    var monospaced = false
    
    var body: some View {
        Text(text)
            .font(.headline.weight(weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .if(monospaced) { $0.monospacedDigit() }
            .frame(maxWidth: .infinity, minHeight: 24, alignment: alignment)
            .padding(.horizontal, 4)
    }
}

private struct DurationCell: View {
    let text: String
    var color: HierarchicalShapeStyle = .primary
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(color)
            .lineLimit(1)
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

private func formatDuration(_ duration: TimeInterval, padded: Bool = false) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: padded ? "%02d:%02d" : "%d:%02d", minutes, seconds)
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
