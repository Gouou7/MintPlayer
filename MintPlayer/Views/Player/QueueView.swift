import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Binding var isVisible: Bool
    
    init(isVisible: Binding<Bool> = .constant(true)) {
        _isVisible = isVisible
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            if audioPlayer.queue.isEmpty && audioPlayer.history.isEmpty {
                EmptyStateView(title: "Queue is empty", systemImage: "list.bullet.rectangle")
            } else {
                List {
                    if !audioPlayer.queue.isEmpty {
                        Section("Up Next") {
                            ForEach(audioPlayer.queue, id: \.id) { song in
                                queueRow(song: song, isCurrent: song.id == audioPlayer.currentSong?.id)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            audioPlayer.removeFromQueue(songId: song.id)
                                        } label: {
                                            Text("Remove from Queue")
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                    
                    if !audioPlayer.history.isEmpty {
                        Section("History") {
                            ForEach(audioPlayer.history, id: \.id) { song in
                                queueRow(song: song, isCurrent: song.id == audioPlayer.currentSong?.id)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Up Next")
                    .font(.headline)
                Text("\(audioPlayer.queue.count) queued")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { audioPlayer.clearQueue() }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(audioPlayer.queue.isEmpty)
            .help("Clear queue")
            
            Button(action: { isVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help("Close Up Next")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func queueRow(song: Song, isCurrent: Bool) -> some View {
        Button {
            audioPlayer.play(song: song, in: audioPlayer.queue)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isCurrent ? MintTheme.accent : .secondary)
                    .frame(width: 26)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MintRowButtonStyle(isSelected: isCurrent))
    }
}
