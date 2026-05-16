import SwiftUI
import AppKit

struct NativeArtistTableView: NSViewRepresentable {
    let artists: [ArtistSummary]
    @Binding var selectedArtist: ArtistSummary?
    let onSelect: (ArtistSummary) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.allowsMultipleSelection = false
        tableView.allowsColumnResizing = true
        tableView.selectionHighlightStyle = .regular
        tableView.headerView = nil
        tableView.rowHeight = 70
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView?.drawsBackground = false
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("artist"))
        column.width = 360
        column.minWidth = 112
        column.resizingMask = .userResizingMask
        tableView.addTableColumn(column)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        
        context.coordinator.tableView = tableView
        context.coordinator.observeClipView(scrollView.contentView)
        context.coordinator.resizeColumnToFit()
        context.coordinator.lastArtistIDs = artists.map(\.id)
        context.coordinator.syncSelectionToTable()
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        
        let artistIDs = artists.map(\.id)
        if context.coordinator.lastArtistIDs != artistIDs {
            context.coordinator.lastArtistIDs = artistIDs
            tableView.reloadData()
        }
        
        context.coordinator.resizeColumnToFit()
        context.coordinator.syncSelectionToTable()
    }
}

extension NativeArtistTableView {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeArtistTableView
        weak var tableView: NSTableView?
        var lastArtistIDs: [ArtistSummary.ID] = []
        private var isSyncingSelection = false
        private var clipViewObservers: [NSObjectProtocol] = []
        
        init(parent: NativeArtistTableView) {
            self.parent = parent
        }
        
        deinit {
            clipViewObservers.forEach(NotificationCenter.default.removeObserver)
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
                    self?.resizeColumnToFit()
                }
                clipViewObservers.append(observer)
            }
        }
        
        func resizeColumnToFit() {
            guard let tableView,
                  let scrollView = tableView.enclosingScrollView,
                  let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("artist"))
            else { return }
            
            let width = max(column.minWidth, scrollView.contentView.bounds.width)
            tableView.setFrameSize(NSSize(width: width, height: tableView.frame.height))
            column.width = width
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.artists.count
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            MintTableRowView(verticalInset: 4)
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.artists.indices.contains(row) else { return nil }
            let artist = parent.artists[row]
            let view = NSHostingView(rootView: NativeArtistCell(artist: artist))
            view.sizingOptions = []
            return view
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection, let tableView else { return }
            let row = tableView.selectedRow
            guard parent.artists.indices.contains(row) else { return }
            let artist = parent.artists[row]
            parent.selectedArtist = artist
            parent.onSelect(artist)
        }
        
        func syncSelectionToTable() {
            guard let tableView else { return }
            let selectedIndex = parent.selectedArtist.flatMap { selected in
                parent.artists.firstIndex { $0.id == selected.id }
            }
            
            let indexes = selectedIndex.map { IndexSet(integer: $0) } ?? IndexSet()
            guard indexes != tableView.selectedRowIndexes else { return }
            
            isSyncingSelection = true
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            isSyncingSelection = false
        }
    }
}

private struct NativeArtistCell: View {
    let artist: ArtistSummary
    
    var body: some View {
        HStack(spacing: 13) {
            ArtworkImage(
                path: artist.coverPath,
                cornerRadius: 21,
                targetSize: CGSize(width: 41, height: 41)
            )
            .frame(width: 41, height: 41)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 5) {
                Text(artist.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(artist.albumCount) albums · \(artist.songCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
    }
}
