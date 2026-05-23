import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.isPlayerOverlayPresented) private var isPlayerOverlayPresented
    @State private var searchText = ""
    @State private var selectedAlbum: AlbumSummary?

    private var filteredAlbums: [AlbumSummary] {
        guard !searchText.isEmpty else {
            return musicLibrary.albumSummaries
        }

        return musicLibrary.albumSummaries
            .filter { album in
                album.title.localizedCaseInsensitiveContains(searchText) ||
                    album.artist.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let selectedAlbum {
                AlbumDetailView(album: selectedAlbum, searchText: $searchText) {
                    self.selectedAlbum = nil
                }
            } else {
                albumGrid
            }

        }
        .toolbar {
            if !isPlayerOverlayPresented {
                ToolbarItem(placement: .primaryAction) {
                    LibrarySearchControls(
                        searchText: $searchText,
                        searchPrompt: selectedAlbum == nil ? settings.text(.searchAlbums) : settings.text(.searchInAlbum)
                    )
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var albumGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 22)], spacing: 28) {
                    ForEach(filteredAlbums, id: \.id) { album in
                        Button {
                            selectedAlbum = album
                        } label: {
                            AlbumTile(album: album)
                        }
                        .buttonStyle(MintContentButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 132)
        }
    }
}

private struct AlbumTile: View {
    @EnvironmentObject private var settings: SettingsManager
    let album: AlbumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArtworkImage(path: album.coverPath, cornerRadius: 10)
                .frame(width: 150, height: 150)
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(album.year > 0 ? "\(album.year) · \(songCountText(album.songCount))" : songCountText(album.songCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .leading)
        }
    }

    private func songCountText(_ count: Int) -> String {
        "\(count) \(settings.text(.songs).lowercased())"
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    let album: AlbumSummary
    @Binding var searchText: String
    let onBack: () -> Void

    @State private var albumSongs: [Song] = []
    @State private var visibleSongs: [Song] = []
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var songSortOrder = [KeyPathComparator(\Song.title)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                }
                .buttonStyle(MintPlainIconButtonStyle())
                .modifier(CircleGlassButtonSurface())

                albumHeader

                NativeSongTableView(
                    songs: visibleSongs,
                    style: .detailSongs(subtitle: .none),
                    selectedSongIDs: $selectedSongIDs,
                    sortOrder: $songSortOrder,
                    onPlay: { song, queue in audioPlayer.play(song: song, in: queue) },
                    onPlayNext: audioPlayer.playNext,
                    onAddToQueue: audioPlayer.addToQueue
                )
                .frame(height: songTableHeight(for: visibleSongs.count))
                .frame(maxWidth: .infinity)

                Text(footerText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 32)
            .padding(.bottom, 150)
        }
        .task(id: album.id) {
            refreshSongs()
        }
        .onChange(of: searchText) {
            refreshVisibleSongs()
        }
    }

    private var albumHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 29) {
                albumArtwork
                albumHeaderInfo
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 16) {
                albumArtwork
                albumHeaderInfo
            }
        }
    }

    private var albumArtwork: some View {
        ArtworkImage(path: album.coverPath, cornerRadius: 16)
            .frame(width: 238, height: 238)
            .shadow(color: .black.opacity(0.28), radius: 17, x: 0, y: 11)
    }

    private var albumHeaderInfo: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(album.title)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(album.artist)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MintTheme.accent)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(albumDetailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ListPlaybackControls(
                songs: albumSongs,
                playAction: playAlbum,
                shuffleAction: shuffleAlbum
            )
            .padding(.top, 44)
        }
    }

    private var albumDetailText: String {
        var values: [String] = []
        if let genre = albumSongs.first?.genre, !genre.isEmpty {
            values.append(genre)
        }
        if album.year > 0 {
            values.append("\(album.year)")
        }
        values.append("\(album.songCount) \(settings.text(.songs).lowercased())")
        return values.joined(separator: " · ")
    }

    private var footerText: String {
        "\(albumSongs.count) \(settings.text(.items)), \(formatDuration(albumSongs.reduce(0) { $0 + $1.duration }))"
    }

    private func playAlbum() {
        audioPlayer.play(songs: albumSongs)
    }

    private func shuffleAlbum() {
        audioPlayer.shuffle(songs: albumSongs)
    }

    private func refreshSongs() {
        albumSongs = musicLibrary.songs(forAlbum: album).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        selectedSongIDs = []
        refreshVisibleSongs()
    }

    private func refreshVisibleSongs() {
        guard !searchText.isEmpty else {
            visibleSongs = albumSongs
            return
        }

        visibleSongs = albumSongs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
        }
        selectedSongIDs = selectedSongIDs.filter { id in
            visibleSongs.contains { $0.id == id }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) \(settings.text(.minutesShort))"
    }

    private func songTableHeight(for count: Int) -> CGFloat {
        min(max(CGFloat(max(count, 1)) * 58 + 10, 180), 620)
    }
}
