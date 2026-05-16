import SwiftUI

struct DetailedSongList: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    
    let songs: [Song]
    @Binding var selectedSongIDs: Set<Song.ID>
    @Binding var sortOrder: [KeyPathComparator<Song>]
    
    var body: some View {
        NativeSongTableView(
            songs: songs,
            style: .detailed,
            selectedSongIDs: $selectedSongIDs,
            sortOrder: $sortOrder,
            onPlay: { song, queue in audioPlayer.play(song: song, in: queue) },
            onPlayNext: audioPlayer.playNext,
            onAddToQueue: audioPlayer.addToQueue
        )
    }
}
