import SwiftUI
import AppKit

struct NativeSongTableView: NSViewRepresentable {
    enum ColumnPreferenceScope: String {
        case songs
        case playlist
        case folder
        case none
    }

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
    @EnvironmentObject private var settings: SettingsManager

    let songs: [Song]
    let style: Style
    var columnPreferenceScope: ColumnPreferenceScope = .songs
    var bottomContentInset: CGFloat = 0
    var playlistId: UUID?
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

        let scrollView = InsetSongScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.documentView = tableView
        configureBackground(for: style, tableView: tableView, scrollView: scrollView)
        context.coordinator.configureContentInsets(scrollView)

        context.coordinator.tableView = tableView
        context.coordinator.configureColumns(for: style)
        context.coordinator.configureScrollBehavior(scrollView, for: style)
        context.coordinator.observeClipView(scrollView.contentView)
        context.coordinator.resizeColumnsToFit()
        context.coordinator.lastSongIDs = songs.map(\.id)
        context.coordinator.lastSongs = songs
        context.coordinator.syncSortDescriptorsToTable()
        context.coordinator.syncSelectionToTable()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = scrollView.documentView as? InteractiveSongTableView else { return }

        configureBackground(for: style, tableView: tableView, scrollView: scrollView)
        let styleChanged = context.coordinator.currentStyle != style
        if styleChanged {
            context.coordinator.configureColumns(for: style)
            context.coordinator.configureScrollBehavior(scrollView, for: style)
        }
        context.coordinator.configureContentInsets(scrollView)

        let songIDs = songs.map(\.id)
        if styleChanged || context.coordinator.lastSongIDs != songIDs || context.coordinator.lastSongs != songs {
            context.coordinator.lastSongIDs = songIDs
            context.coordinator.lastSongs = songs
            tableView.reloadData()
        }

        context.coordinator.resizeColumnsToFit()
        context.coordinator.syncSortDescriptorsToTable()
        context.coordinator.syncSelectionToTable()
    }

    private func configureBackground(for style: Style, tableView: NSTableView, scrollView: NSScrollView) {
        switch style {
        case .detailSongs:
            tableView.backgroundColor = .clear
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            scrollView.contentView.drawsBackground = false
            scrollView.contentView.backgroundColor = .clear
        case .detailed, .compactFolder:
            tableView.backgroundColor = NativeSongTableColors.backgroundColor
            scrollView.drawsBackground = true
            scrollView.backgroundColor = NativeSongTableColors.backgroundColor
            scrollView.contentView.drawsBackground = true
            scrollView.contentView.backgroundColor = NativeSongTableColors.backgroundColor
        }
    }
}

private protocol SongTableInteractionDelegate: AnyObject {
    func selectRowForInteraction(_ row: Int)
}

private protocol SongTableHeaderMenuProvider: AnyObject {
    func columnVisibilityMenu() -> NSMenu?
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

private final class InteractiveSongTableHeaderView: NSTableHeaderView {
    weak var menuProvider: SongTableHeaderMenuProvider?

    override var allowsVibrancy: Bool {
        false
    }

    override var isOpaque: Bool {
        true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider?.columnVisibilityMenu()
    }

    override func draw(_ dirtyRect: NSRect) {
        NativeSongTableColors.backgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}

private final class OpaqueSongTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        NativeSongTableColors.backgroundColor.setFill()
        cellFrame.fill()
        drawInterior(withFrame: cellFrame.insetBy(dx: 6, dy: 0), in: controlView)
    }
}

private final class InsetSongScrollView: NSScrollView {
    var desiredBottomContentInset: CGFloat = 0 {
        didSet {
            applyDesiredInsets()
        }
    }

    override func layout() {
        super.layout()
        applyDesiredInsets()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        applyDesiredInsets()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyDesiredInsets()
    }

    private func applyDesiredInsets() {
        automaticallyAdjustsContentInsets = false
        let inset = max(0, desiredBottomContentInset)
        let desiredInsets = NSEdgeInsets(top: 0, left: 0, bottom: inset, right: 0)

        if !contentInsets.isApproximatelyEqual(to: desiredInsets) {
            contentInsets = desiredInsets
        }

        let scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        if !self.scrollerInsets.isApproximatelyEqual(to: scrollerInsets) {
            self.scrollerInsets = scrollerInsets
        }
    }
}

private enum NativeSongTableColors {
    static let backgroundColor = NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
            ? NSColor(calibratedRed: 0.105, green: 0.101, blue: 0.097, alpha: 1)
            : .white
    }
}

private extension NSEdgeInsets {
    func isApproximatelyEqual(to other: NSEdgeInsets) -> Bool {
        abs(top - other.top) < 0.5 &&
            abs(left - other.left) < 0.5 &&
            abs(bottom - other.bottom) < 0.5 &&
            abs(right - other.right) < 0.5
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
    case playCount
    case dateAdded
    case favorite
    case index
}

private enum NativeSongTableMetrics {
    static let rightSafeInset: CGFloat = 56
    static let durationTextWidth: CGFloat = 60
    static let playCountWidth: CGFloat = 76
    static let dateAddedWidth: CGFloat = 150
    static let favoriteWidth: CGFloat = 44
    static let detailedSongMinWidth: CGFloat = 76
    static let detailedArtistMinWidth: CGFloat = 44
    static let detailSongMinWidth: CGFloat = 64
    static let detailIndexWidth: CGFloat = 28
    static let maxHeaderColumnWidthRatio: CGFloat = 0.5
}

extension NativeSongTableView {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, SongTableInteractionDelegate, SongTableHeaderMenuProvider {
        var parent: NativeSongTableView
        fileprivate weak var tableView: InteractiveSongTableView?
        var currentStyle: Style?
        var lastSongIDs: [Song.ID] = []
        var lastSongs: [Song] = []
        private var isSyncingSelection = false
        private var isApplyingColumnWidths = false
        private var isApplyingSortDescriptors = false
        private var menuSongs: [Song] = []
        private var clipViewObservers: [NSObjectProtocol] = []

        init(parent: NativeSongTableView) {
            self.parent = parent
        }

        func configureColumns(for style: Style) {
            guard let tableView else { return }

            tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
            tableView.rowHeight = style.rowHeight

            if style.showsHeader {
                let headerView = InteractiveSongTableHeaderView()
                headerView.menuProvider = self
                tableView.headerView = headerView
            } else {
                tableView.headerView = nil
            }

            switch style {
            case .detailed:
                visibleColumns(for: style).forEach { addVisibleColumn($0, for: style) }
            case .compactFolder:
                visibleColumns(for: style).forEach { addVisibleColumn($0, for: style) }
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
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = shouldResizeColumns
            tableView?.columnAutoresizingStyle = shouldResizeColumns ? .noColumnAutoresizing : .lastColumnOnlyAutoresizingStyle
        }

        func configureContentInsets(_ scrollView: NSScrollView) {
            let inset = max(0, parent.bottomContentInset)
            if let insetScrollView = scrollView as? InsetSongScrollView {
                insetScrollView.desiredBottomContentInset = inset
            } else {
                scrollView.automaticallyAdjustsContentInsets = false
                scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: inset, right: 0)
                scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            }
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
                    if let scrollView = self?.tableView?.enclosingScrollView {
                        self?.configureContentInsets(scrollView)
                    }
                    self?.refreshVisibleRowHover()
                }
                clipViewObservers.append(observer)
            }
        }

        func refreshVisibleRowHover() {
            guard let tableView else { return }
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            guard visibleRows.location != NSNotFound else { return }

            for row in visibleRows.location..<NSMaxRange(visibleRows) {
                tableView.rowView(atRow: row, makeIfNecessary: false)?.needsDisplay = true
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
            updateHeaderColumnMaxWidths()

            if parent.style.showsHeader, hasSavedColumnWidths(for: parent.style) {
                return
            }

            switch parent.style {
            case .detailed:
                applyProgrammaticColumnWidths {
                    setColumnIfPresent(.duration, width: NativeSongTableMetrics.durationTextWidth)
                    setColumnIfPresent(.playCount, width: NativeSongTableMetrics.playCountWidth)
                    setColumnIfPresent(.dateAdded, width: NativeSongTableMetrics.dateAddedWidth)
                    setColumnIfPresent(.favorite, width: NativeSongTableMetrics.favoriteWidth)
                }

                let fixedWidth = columnWidth(.duration) + columnWidth(.playCount) + columnWidth(.dateAdded) + columnWidth(.favorite)
                let remaining = max(0, usableWidth - fixedWidth)
                let hasArtist = column(.artist) != nil

                applyProgrammaticColumnWidths {
                    if hasArtist {
                        var artistWidth = min(max(remaining * 0.3, minWidth(.artist)), 280)
                        if remaining - artistWidth < minWidth(.song) {
                            artistWidth = max(minWidth(.artist), remaining - minWidth(.song))
                        }
                        let songWidth = max(remaining - artistWidth, minWidth(.song))
                        setColumn(.artist, width: artistWidth)
                        setColumn(.song, width: songWidth)
                    } else {
                        setColumn(.song, width: max(remaining, minWidth(.song)))
                    }
                }
            case .detailSongs:
                applyProgrammaticColumnWidths {
                    setColumn(.index, width: NativeSongTableMetrics.detailIndexWidth)
                    setColumn(.duration, width: NativeSongTableMetrics.durationTextWidth)
                }

                let fixedWidth = columnWidth(.index) + columnWidth(.duration)
                applyProgrammaticColumnWidths {
                    setColumn(.song, width: max(usableWidth - fixedWidth, minWidth(.song)))
                }
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
                return hostingView(DetailedNativeSongCell(song: song, unknownAlbum: parent.settings.text(.unknownAlbum)))
            case (.detailed, .artist):
                return hostingView(TextCell(text: song.artist.isEmpty ? parent.settings.text(.unknownArtist) : song.artist, weight: .semibold))
            case (.detailed, .duration):
                return hostingView(DurationCell(text: formatDuration(song.duration)))
            case (.detailed, .playCount):
                return hostingView(TextCell(text: "\(song.playCount)", color: .secondary, alignment: .center, monospaced: true))
            case (.detailed, .dateAdded):
                return hostingView(DurationCell(text: formatDateAdded(song.dateAdded)))
            case (.detailed, .favorite):
                return hostingView(FavoriteCell(isFavorite: song.isFavorite) { [weak self] in
                    self?.parent.musicLibrary.toggleFavorite(for: song.id)
                })
            case (.compactFolder, .title):
                return hostingView(TextCell(text: song.title))
            case (.compactFolder, .artist):
                return hostingView(TextCell(text: song.artist))
            case (.compactFolder, .album):
                return hostingView(TextCell(text: song.album))
            case (.compactFolder, .genre):
                let genre = (song.genre ?? "").isEmpty ? parent.settings.text(.unknownGenre) : song.displayGenre
                return hostingView(TextCell(text: genre, color: .secondary))
            case (.compactFolder, .type):
                return hostingView(TextCell(text: song.fileType, color: .secondary))
            case (.compactFolder, .duration):
                return hostingView(TextCell(text: formatDuration(song.duration, padded: true), color: .secondary, monospaced: true))
            case (.compactFolder, .playCount):
                return hostingView(TextCell(text: "\(song.playCount)", color: .secondary, alignment: .center, monospaced: true))
            case (.compactFolder, .dateAdded):
                return hostingView(DurationCell(text: formatDateAdded(song.dateAdded)))
            case (.compactFolder, .favorite):
                return hostingView(FavoriteCell(isFavorite: song.isFavorite) { [weak self] in
                    self?.parent.musicLibrary.toggleFavorite(for: song.id)
                })
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
            guard !isApplyingSortDescriptors else { return }
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
            case "playCount":
                parent.sortOrder = [KeyPathComparator(\Song.playCount, order: order)]
            case "dateAdded":
                parent.sortOrder = [KeyPathComparator(\Song.dateAdded, order: order)]
            default:
                break
            }
        }

        func syncSortDescriptorsToTable() {
            guard parent.style.showsHeader,
                  let tableView,
                  let descriptor = sortDescriptor(for: parent.sortOrder)
            else { return }

            guard tableView.sortDescriptors.first != descriptor else { return }
            isApplyingSortDescriptors = true
            tableView.sortDescriptors = [descriptor]
            isApplyingSortDescriptors = false
        }

        func tableViewColumnDidResize(_ notification: Notification) {
            guard !isApplyingColumnWidths, parent.style.showsHeader else { return }
            saveColumnWidths(for: parent.style)
        }

        func tableViewColumnDidMove(_ notification: Notification) {
            guard parent.style.showsHeader else { return }
            saveVisibleColumns(visibleColumnsFromTable(), for: parent.style)
            saveColumnWidths(for: parent.style)
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

        func columnVisibilityMenu() -> NSMenu? {
            guard parent.style.showsHeader else { return nil }

            let menu = NSMenu(title: parent.settings.text(.columns))
            for column in configurableColumns(for: parent.style) {
                let item = NSMenuItem(
                    title: title(for: column, style: parent.style),
                    action: #selector(toggleColumnVisibility(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = column.rawValue
                item.state = isColumnVisible(column, for: parent.style) ? .on : .off
                item.isEnabled = column != primaryColumn(for: parent.style)
                menu.addItem(item)
            }
            return menu
        }

        @objc private func toggleColumnVisibility(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let column = NativeSongColumn(rawValue: rawValue),
                  column != primaryColumn(for: parent.style)
            else { return }

            var orderedVisibleColumns = visibleColumnsFromTable()
            if orderedVisibleColumns.isEmpty {
                orderedVisibleColumns = visibleColumns(for: parent.style)
            }

            if orderedVisibleColumns.contains(column) {
                orderedVisibleColumns.removeAll { $0 == column }
            } else {
                orderedVisibleColumns.append(column)
            }

            let primaryColumn = primaryColumn(for: parent.style)
            if !orderedVisibleColumns.contains(primaryColumn) {
                orderedVisibleColumns.insert(primaryColumn, at: 0)
            }

            saveVisibleColumns(orderedVisibleColumns, for: parent.style)
            configureColumns(for: parent.style)
            tableView?.reloadData()
            resizeColumnsToFit()
            syncSelectionToTable()
        }

        private func addVisibleColumn(_ id: NativeSongColumn, for style: Style) {
            guard isColumnVisible(id, for: style) else { return }
            addColumn(
                id,
                title: title(for: id, style: style),
                width: defaultWidth(for: id, style: style),
                minWidth: minWidth(for: id, style: style),
                sortKey: sortKey(for: id)
            )
        }

        private func addColumn(_ id: NativeSongColumn, title: String, width: CGFloat, minWidth: CGFloat, sortKey: String? = nil) {
            guard let tableView else { return }
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id.rawValue))
            column.headerCell = OpaqueSongTableHeaderCell(textCell: title)
            column.minWidth = minWidth
            column.maxWidth = max(minWidth, headerColumnMaxWidth())
            column.width = min(column.maxWidth, max(minWidth, savedColumnWidth(for: id, style: parent.style) ?? width))
            column.resizingMask = .userResizingMask

            if let sortKey {
                let isStringSort = ["title", "artist", "album", "genre", "type"].contains(sortKey)
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

        private func updateHeaderColumnMaxWidths() {
            guard parent.style.showsHeader, let tableView else { return }

            let maxWidth = headerColumnMaxWidth()
            applyProgrammaticColumnWidths {
                for column in tableView.tableColumns {
                    let adjustedMaxWidth = max(column.minWidth, maxWidth)
                    column.maxWidth = adjustedMaxWidth
                    if column.width > adjustedMaxWidth {
                        column.width = adjustedMaxWidth
                    }
                }
            }
        }

        private func headerColumnMaxWidth() -> CGFloat {
            let screenWidth = tableView?.window?.screen?.visibleFrame.width ?? NSScreen.main?.visibleFrame.width ?? 0
            guard screenWidth > 0 else { return CGFloat.greatestFiniteMagnitude }
            return floor(screenWidth * NativeSongTableMetrics.maxHeaderColumnWidthRatio)
        }

        private func setColumn(_ id: NativeSongColumn, width: CGFloat) {
            guard let column = column(id) else { return }
            column.width = min(column.maxWidth, max(column.minWidth, width))
        }

        private func setColumnIfPresent(_ id: NativeSongColumn, width: CGFloat) {
            guard column(id) != nil else { return }
            setColumn(id, width: width)
        }

        private func columnWidth(_ id: NativeSongColumn) -> CGFloat {
            column(id)?.width ?? 0
        }

        private func minWidth(_ id: NativeSongColumn) -> CGFloat {
            column(id)?.minWidth ?? 0
        }

        private func applyProgrammaticColumnWidths(_ operation: () -> Void) {
            isApplyingColumnWidths = true
            operation()
            isApplyingColumnWidths = false
        }

        private func configurableColumns(for style: Style) -> [NativeSongColumn] {
            switch style {
            case .detailed:
                return [.song, .artist, .duration, .playCount, .dateAdded, .favorite]
            case .compactFolder:
                return [.title, .artist, .album, .genre, .type, .duration, .playCount, .dateAdded, .favorite]
            case .detailSongs:
                return [.index, .song, .duration]
            }
        }

        private func defaultVisibleColumns(for style: Style) -> [NativeSongColumn] {
            switch style {
            case .detailed:
                return [.song, .artist, .duration]
            case .compactFolder:
                return [.title, .artist, .album, .genre, .type, .duration]
            case .detailSongs:
                return [.index, .song, .duration]
            }
        }

        private func visibleColumns(for style: Style) -> [NativeSongColumn] {
            guard let key = columnPreferenceKey(for: style),
                  let storedValues = UserDefaults.standard.stringArray(forKey: key)
            else {
                return defaultVisibleColumns(for: style)
            }

            let allColumns = configurableColumns(for: style)
            var seenColumns = Set<NativeSongColumn>()
            var orderedColumns = storedValues.compactMap(NativeSongColumn.init(rawValue:)).filter { column in
                allColumns.contains(column) && seenColumns.insert(column).inserted
            }
            let primaryColumn = primaryColumn(for: style)
            if !orderedColumns.contains(primaryColumn) {
                orderedColumns.insert(primaryColumn, at: 0)
            }

            if orderedColumns.isEmpty {
                return defaultVisibleColumns(for: style)
            }

            return orderedColumns
        }

        private func saveVisibleColumns(_ columns: [NativeSongColumn], for style: Style) {
            guard let key = columnPreferenceKey(for: style) else { return }
            UserDefaults.standard.set(columns.map(\.rawValue), forKey: key)
        }

        private func isColumnVisible(_ column: NativeSongColumn, for style: Style) -> Bool {
            visibleColumns(for: style).contains(column)
        }

        private func primaryColumn(for style: Style) -> NativeSongColumn {
            switch style {
            case .detailed, .detailSongs:
                return .song
            case .compactFolder:
                return .title
            }
        }

        private func columnPreferenceKey(for style: Style) -> String? {
            guard style.showsHeader, parent.columnPreferenceScope != .none else {
                return nil
            }
            return AppConfiguration.userDefaultsKey("songTable.visibleColumns.\(parent.columnPreferenceScope.rawValue)")
        }

        private func columnWidthPreferenceKey(for style: Style) -> String? {
            guard style.showsHeader, parent.columnPreferenceScope != .none else {
                return nil
            }
            return AppConfiguration.userDefaultsKey("songTable.columnWidths.\(parent.columnPreferenceScope.rawValue)")
        }

        private func savedColumnWidths(for style: Style) -> [String: CGFloat] {
            guard let key = columnWidthPreferenceKey(for: style),
                  let storedWidths = UserDefaults.standard.dictionary(forKey: key) as? [String: Double]
            else { return [:] }

            return storedWidths.mapValues { CGFloat($0) }
        }

        private func hasSavedColumnWidths(for style: Style) -> Bool {
            !savedColumnWidths(for: style).isEmpty
        }

        private func savedColumnWidth(for column: NativeSongColumn, style: Style) -> CGFloat? {
            savedColumnWidths(for: style)[column.rawValue]
        }

        private func saveColumnWidths(for style: Style) {
            guard let tableView, let key = columnWidthPreferenceKey(for: style) else { return }

            var widths: [String: Double] = [:]
            for tableColumn in tableView.tableColumns {
                guard let column = NativeSongColumn(rawValue: tableColumn.identifier.rawValue) else { continue }
                widths[column.rawValue] = Double(max(tableColumn.minWidth, tableColumn.width))
            }
            UserDefaults.standard.set(widths, forKey: key)
        }

        private func visibleColumnsFromTable() -> [NativeSongColumn] {
            guard let tableView else { return visibleColumns(for: parent.style) }
            return tableView.tableColumns.compactMap { NativeSongColumn(rawValue: $0.identifier.rawValue) }
        }

        private func title(for column: NativeSongColumn, style: Style) -> String {
            switch (style, column) {
            case (.detailed, .song):
                return parent.settings.text(.columnSong)
            case (.detailed, .artist):
                return parent.settings.text(.columnArtist)
            case (.detailed, .duration):
                return parent.settings.text(.columnDuration)
            case (.detailed, .playCount):
                return parent.settings.text(.columnPlayCount)
            case (.detailed, .dateAdded):
                return parent.settings.text(.columnDateAdded)
            case (.detailed, .favorite):
                return parent.settings.text(.columnFavorite)
            case (.compactFolder, .title):
                return parent.settings.text(.columnTitle)
            case (.compactFolder, .artist):
                return parent.settings.text(.columnArtist)
            case (.compactFolder, .album):
                return parent.settings.text(.columnAlbum)
            case (.compactFolder, .genre):
                return parent.settings.text(.columnGenre)
            case (.compactFolder, .type):
                return parent.settings.text(.columnType)
            case (.compactFolder, .duration):
                return parent.settings.text(.columnDuration)
            case (.compactFolder, .playCount):
                return parent.settings.text(.columnPlayCount)
            case (.compactFolder, .dateAdded):
                return parent.settings.text(.columnDateAdded)
            case (.compactFolder, .favorite):
                return parent.settings.text(.columnFavorite)
            default:
                return ""
            }
        }

        private func defaultWidth(for column: NativeSongColumn, style: Style) -> CGFloat {
            switch (style, column) {
            case (.detailed, .song):
                return 420
            case (.detailed, .artist):
                return 260
            case (_, .duration):
                return style == .compactFolder ? 84 : NativeSongTableMetrics.durationTextWidth
            case (_, .playCount):
                return NativeSongTableMetrics.playCountWidth
            case (_, .dateAdded):
                return NativeSongTableMetrics.dateAddedWidth
            case (_, .favorite):
                return NativeSongTableMetrics.favoriteWidth
            case (.compactFolder, .title):
                return 320
            case (.compactFolder, .artist):
                return 180
            case (.compactFolder, .album):
                return 200
            case (.compactFolder, .genre):
                return 120
            case (.compactFolder, .type):
                return 70
            default:
                return 80
            }
        }

        private func minWidth(for column: NativeSongColumn, style: Style) -> CGFloat {
            switch (style, column) {
            case (.detailed, .song):
                return NativeSongTableMetrics.detailedSongMinWidth
            case (.detailed, .artist):
                return NativeSongTableMetrics.detailedArtistMinWidth
            case (_, .duration):
                return style == .compactFolder ? 72 : NativeSongTableMetrics.durationTextWidth
            case (_, .playCount):
                return 68
            case (_, .dateAdded):
                return 118
            case (_, .favorite):
                return NativeSongTableMetrics.favoriteWidth
            case (.compactFolder, .title):
                return 220
            case (.compactFolder, .artist):
                return 140
            case (.compactFolder, .album):
                return 140
            case (.compactFolder, .genre):
                return 90
            case (.compactFolder, .type):
                return 56
            default:
                return 40
            }
        }

        private func sortKey(for column: NativeSongColumn) -> String? {
            switch column {
            case .song, .title:
                return "title"
            case .artist:
                return "artist"
            case .album:
                return "album"
            case .genre:
                return "genre"
            case .type:
                return "type"
            case .duration:
                return "duration"
            case .playCount:
                return "playCount"
            case .dateAdded:
                return "dateAdded"
            case .favorite:
                return nil
            case .index:
                return nil
            }
        }

        private func sortDescriptor(for sortOrder: [KeyPathComparator<Song>]) -> NSSortDescriptor? {
            guard let comparator = sortOrder.first,
                  let key = sortKey(for: comparator.keyPath)
            else { return nil }

            let isStringSort = ["title", "artist", "album", "genre", "type"].contains(key)
            return NSSortDescriptor(
                key: key,
                ascending: comparator.order == .forward,
                selector: isStringSort ? #selector(NSString.localizedCaseInsensitiveCompare(_:)) : nil
            )
        }

        private func sortKey(for keyPath: PartialKeyPath<Song>) -> String? {
            switch keyPath {
            case \Song.title:
                return "title"
            case \Song.artist:
                return "artist"
            case \Song.album:
                return "album"
            case \Song.displayGenre:
                return "genre"
            case \Song.fileType:
                return "type"
            case \Song.duration:
                return "duration"
            case \Song.playCount:
                return "playCount"
            case \Song.dateAdded:
                return "dateAdded"
            default:
                return nil
            }
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
            menu.addItem(menuItem(parent.settings.text(.play), systemImage: "play.fill", action: #selector(playSongs)))
            menu.addItem(menuItem(parent.settings.text(.playNext), systemImage: "text.line.first.and.arrowtriangle.forward", action: #selector(playNext)))
            menu.addItem(menuItem(parent.settings.text(.addToQueue), systemImage: "text.badge.plus", action: #selector(addToQueue)))

            if !parent.musicLibrary.playlists.isEmpty {
                let playlistTitle = parent.settings.text(.addToPlaylist)
                let playlistItem = NSMenuItem(title: playlistTitle, action: nil, keyEquivalent: "")
                playlistItem.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: playlistTitle)
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
            menu.addItem(menuItem(parent.settings.text(.showInFinder), systemImage: "folder", action: #selector(showInFinder)))

            if parent.playlistId != nil {
                menu.addItem(menuItem(parent.settings.text(.removeFromPlaylist), systemImage: "minus.circle", action: #selector(removeFromPlaylist)))
            }
            menu.addItem(menuItem(parent.settings.text(.blockSong), systemImage: "eye.slash", action: #selector(blockSongs)))
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

        @objc private func blockSongs() {
            let ids = Set(menuSongs.map(\.id))
            parent.musicLibrary.blockSongs(withIds: ids)
            parent.selectedSongIDs.subtract(ids)
        }

        @objc private func removeFromPlaylist() {
            guard let playlistId = parent.playlistId else { return }
            let ids = Set(menuSongs.map(\.id))
            parent.musicLibrary.removeSongsFromPlaylist(songIds: ids, playlistId: playlistId)
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
    let unknownAlbum: String

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(path: song.coverPath, cornerRadius: 7, targetSize: CGSize(width: 46, height: 46))
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.album.isEmpty ? unknownAlbum : song.album)
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

private struct FavoriteCell: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(MintPlainIconButtonStyle(isActive: isFavorite))
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .center)
    }
}

private func formatDuration(_ duration: TimeInterval, padded: Bool = false) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: padded ? "%02d:%02d" : "%d:%02d", minutes, seconds)
}

private func formatDateAdded(_ date: Date) -> String {
    NativeSongDateFormatter.shared.string(from: date)
}

private enum NativeSongDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
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
