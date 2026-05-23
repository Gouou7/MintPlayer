import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @Binding var isVisible: Bool

    init(isVisible: Binding<Bool> = .constant(true)) {
        _isVisible = isVisible
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isQueueTimelineEmpty {
                EmptyStateView(title: settings.text(.queueEmpty), systemImage: "list.bullet.rectangle")
            } else {
                ScrollViewReader { proxy in
                    List {
                        if !historySongs.isEmpty {
                            Section(settings.text(.history)) {
                                ForEach(Array(historySongs.enumerated()), id: \.offset) { index, song in
                                    queueRow(song: song, isCurrent: false) {
                                        audioPlayer.play(song: song)
                                    }
                                    .id("history-\(index)-\(song.id)")
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }

                        if let currentSong = audioPlayer.currentSong {
                            Section(settings.text(.nowPlaying)) {
                                queueRow(song: currentSong, isCurrent: true) {}
                                    .id(currentSongScrollID)
                                    .listRowBackground(Color.clear)
                            }
                        }

                        if !upNextSongs.isEmpty {
                            Section(settings.text(.upNext)) {
                                ForEach(upNextSongs, id: \.id) { song in
                                    queueRow(song: song, isCurrent: false) {
                                        audioPlayer.play(song: song, in: audioPlayer.queue)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            audioPlayer.removeFromQueue(songId: song.id)
                                        } label: {
                                            Text(settings.text(.removeFromQueue))
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        scrollToCurrentSong(with: proxy)
                    }
                    .onChange(of: audioPlayer.currentSong?.id) {
                        scrollToCurrentSong(with: proxy)
                    }
                }
            }
        }
    }

    private var isQueueTimelineEmpty: Bool {
        audioPlayer.currentSong == nil && audioPlayer.queue.isEmpty && audioPlayer.history.isEmpty
    }

    private var historySongs: [Song] {
        Array(audioPlayer.history.reversed())
    }

    private var upNextSongs: [Song] {
        guard let currentSong = audioPlayer.currentSong,
              let currentIndex = audioPlayer.queue.firstIndex(where: { $0.id == currentSong.id }) else {
            return audioPlayer.queue
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < audioPlayer.queue.endIndex else {
            return []
        }

        return Array(audioPlayer.queue[nextIndex...])
    }

    private var currentSongScrollID: String {
        "current-song"
    }

    private func scrollToCurrentSong(with proxy: ScrollViewProxy) {
        guard audioPlayer.currentSong != nil else { return }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(currentSongScrollID, anchor: UnitPoint(x: 0.5, y: 0.34))
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.text(.upNext))
                    .font(.headline)
                Text("\(audioPlayer.history.count) \(settings.text(.history)) · \(upNextSongs.count) \(settings.text(.upNextLower))")
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
            .help(settings.text(.clearQueue))

            Button(action: { isVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help(settings.text(.closeUpNext))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func queueRow(song: Song, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
