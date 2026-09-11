import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var settings: SettingsManager
    @Binding var isVisible: Bool
    @State private var selectedSongIDs = Set<Song.ID>()

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
                    List(selection: $selectedSongIDs) {
                        if !historySongs.isEmpty {
                            Section(settings.text(.history)) {
                                ForEach(Array(historySongs.enumerated()), id: \.offset) { index, song in
                                    queueRow(song: song, isCurrent: false) {
                                        audioPlayer.replayHistorySong(song)
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
                                    queueRowContent(song: song, isCurrent: false)
                                        .tag(song.id)
                                        .onTapGesture(count: 2) { audioPlayer.play(song: song) }
                                        .contextMenu {
                                            Button(settings.text(.play)) { audioPlayer.play(song: song) }
                                            Button(role: .destructive) {
                                                audioPlayer.removeUpcomingSongs(withIDs: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id])
                                            } label: {
                                                Text(settings.text(.removeFromQueue))
                                            }
                                        }
                                        .listRowBackground(Color.clear)
                                }
                                .onMove(perform: audioPlayer.moveUpcomingSongs)
                            }
                        }
                    }
                    .onDeleteCommand { audioPlayer.removeUpcomingSongs(withIDs: selectedSongIDs) }
                    .onChange(of: audioPlayer.queue) { _, _ in
                        selectedSongIDs.formIntersection(Set(upNextSongs.map(\.id)))
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        scrollToCurrentSong(with: proxy)
                    }
                    .onChange(of: audioPlayer.currentSong?.id) {
                        selectedSongIDs.formIntersection(Set(upNextSongs.map(\.id)))
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
        audioPlayer.history
    }

    private var upNextSongs: [Song] {
        audioPlayer.upcomingSongs
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

            if !selectedSongIDs.isEmpty {
                Button { audioPlayer.removeUpcomingSongs(withIDs: selectedSongIDs) } label: {
                    Label(settings.text(.removeSelectedQueue), systemImage: "minus.circle")
                }
                .labelStyle(.iconOnly)
                .help(settings.text(.removeSelectedQueue))
            }

            if audioPlayer.canUndoClearQueue {
                Button(action: audioPlayer.undoClearQueue) {
                    Label(settings.text(.undoClearQueue), systemImage: "arrow.uturn.backward")
                }
                .labelStyle(.iconOnly)
                .help(settings.text(.undoClearQueue))
            }

            Button(action: { audioPlayer.clearQueue() }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(upNextSongs.isEmpty)
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
            queueRowContent(song: song, isCurrent: isCurrent)
        }
        .buttonStyle(.plain)
    }

    private func queueRowContent(song: Song, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).lineLimit(1)
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
}
