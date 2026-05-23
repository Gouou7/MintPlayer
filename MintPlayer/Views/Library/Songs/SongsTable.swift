import SwiftUI

struct CustomizableSongsTable: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer

    let songs: [Song]
    var columnPreferenceScope: NativeSongTableView.ColumnPreferenceScope = .folder
    var bottomContentInset: CGFloat = 0
    var playlistId: UUID?
    @Binding var selectedSongIDs: Set<Song.ID>
    @Binding var sortOrder: [KeyPathComparator<Song>]

    var body: some View {
        NativeSongTableView(
            songs: songs,
            style: .compactFolder,
            columnPreferenceScope: columnPreferenceScope,
            bottomContentInset: bottomContentInset,
            playlistId: playlistId,
            selectedSongIDs: $selectedSongIDs,
            sortOrder: $sortOrder,
            onPlay: { song, queue in audioPlayer.play(song: song, in: queue) },
            onPlayNext: audioPlayer.playNext,
            onAddToQueue: audioPlayer.addToQueue
        )
    }
}
