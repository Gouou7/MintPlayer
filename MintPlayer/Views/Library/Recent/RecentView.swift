import SwiftUI

struct RecentView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var searchText = ""
    
    private var filteredHistory: [PlayHistory] {
        guard !searchText.isEmpty else {
            return musicLibrary.recentlyPlayed
        }
        
        return musicLibrary.recentlyPlayed.filter { history in
            guard let song = musicLibrary.song(withId: history.songId) else { return false }
            return song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText) ||
                song.album.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 18) {
                List {
                    ForEach(filteredHistory, id: \.id) { history in
                        if let song = musicLibrary.song(withId: history.songId) {
                            HStack(spacing: 12) {
                                Button(action: { audioPlayer.play(song: song, in: filteredSongsForHistory()) }) {
                                    Image(systemName: "play.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(MintTheme.accent)
                                }
                                .buttonStyle(MintPlainIconButtonStyle(isActive: true))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.body)
                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: 200, alignment: .leading)
                                
                                Spacer()
                                
                                Text(formatDate(history.playedAt))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: { /* 显示更多选项 */ }) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(MintPlainIconButtonStyle())
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mintHoverRowStyle(song.id == audioPlayer.currentSong?.id)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .onDelete(perform: deleteHistory)
                }
                .listStyle(.plain)
                .padding(0)
            }
            .padding(.top, 28)
            .padding(.bottom, 132)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LibrarySearchControls(searchText: $searchText, searchPrompt: "Search Recent")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteHistory(at offsets: IndexSet) {
        let historyIds = Set(offsets.compactMap { filteredHistory.indices.contains($0) ? filteredHistory[$0].id : nil })
        let originalOffsets = IndexSet(musicLibrary.recentlyPlayed.indices.filter { historyIds.contains(musicLibrary.recentlyPlayed[$0].id) })
        musicLibrary.deleteRecentHistory(at: originalOffsets)
    }
    
    private func filteredSongsForHistory() -> [Song] {
        filteredHistory.compactMap { musicLibrary.song(withId: $0.songId) }
    }
}
