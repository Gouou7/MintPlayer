import SwiftUI
import AppKit

struct PlaylistDropDestination: NSViewRepresentable {
    let playlistId: UUID
    let musicLibrary: MusicLibrary
    
    func makeNSView(context: Context) -> DropView {
        let view = DropView()
        view.playlistId = playlistId
        view.musicLibrary = musicLibrary
        view.registerForDraggedTypes(SongDragPayload.acceptedPasteboardTypes)
        return view
    }
    
    func updateNSView(_ nsView: DropView, context: Context) {
        nsView.playlistId = playlistId
        nsView.musicLibrary = musicLibrary
    }
    
    final class DropView: NSView {
        var playlistId: UUID?
        weak var musicLibrary: MusicLibrary?
        
        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            canAccept(sender) ? .copy : []
        }
        
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            canAccept(sender) ? .copy : []
        }
        
        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard let playlistId, let musicLibrary else { return false }
            let songs = SongDragPayload.songs(from: sender.draggingPasteboard, musicLibrary: musicLibrary)
            guard !songs.isEmpty else { return false }
            musicLibrary.addSongsToPlaylist(songs, playlistId: playlistId)
            return true
        }
        
        private func canAccept(_ sender: NSDraggingInfo) -> Bool {
            sender.draggingPasteboard.canReadItem(withDataConformingToTypes: SongDragPayload.acceptedPasteboardTypeIdentifiers)
        }
    }
}
