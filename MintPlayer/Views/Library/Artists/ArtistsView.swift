import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.isPlayerOverlayPresented) private var isPlayerOverlayPresented
    @State private var searchText = ""
    @State private var artistSearchText = ""
    @State private var albumSearchText = ""
    @State private var selectedArtist: ArtistSummary?
    @State private var selectedAlbum: AlbumSummary?

    private var filteredArtists: [ArtistSummary] {
        guard !searchText.isEmpty else {
            return musicLibrary.artistSummaries
        }

        return musicLibrary.artistSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var activeSearchText: Binding<String> {
        Binding(
            get: {
                if selectedAlbum != nil {
                    return albumSearchText
                }
                if selectedArtist != nil {
                    return artistSearchText
                }
                return searchText
            },
            set: { value in
                if selectedAlbum != nil {
                    albumSearchText = value
                } else if selectedArtist != nil {
                    artistSearchText = value
                } else {
                    searchText = value
                }
            }
        )
    }

    private var searchPrompt: String {
        if selectedAlbum != nil {
            return settings.text(.searchInAlbum)
        }
        if selectedArtist != nil {
            return settings.text(.searchInArtist)
        }
        return settings.text(.searchArtists)
    }

    var body: some View {
        ZStack(alignment: .top) {
            content
        }
        .toolbar {
            if !isPlayerOverlayPresented {
                ToolbarItem(placement: .primaryAction) {
                    LibrarySearchControls(
                        searchText: activeSearchText,
                        searchPrompt: searchPrompt
                    )
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: musicLibrary.artistSummaries) { _, artists in
            guard let selectedArtist else { return }
            if !artists.contains(where: { $0.id == selectedArtist.id }) {
                self.selectedArtist = nil
                selectedAlbum = nil
                artistSearchText = ""
                albumSearchText = ""
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let selectedAlbum {
            AlbumDetailView(album: selectedAlbum, searchText: $albumSearchText) {
                albumSearchText = ""
                self.selectedAlbum = nil
            }
        } else if let selectedArtist {
            ArtistDetailView(
                artist: selectedArtist,
                searchText: $artistSearchText,
                onBack: {
                    artistSearchText = ""
                    albumSearchText = ""
                    self.selectedArtist = nil
                },
                onAlbumSelect: { album in
                    albumSearchText = ""
                    selectedAlbum = album
                }
            )
        } else {
            artistGrid
        }
    }

    private var artistGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if filteredArtists.isEmpty {
                    EmptyStateView(
                        title: searchText.isEmpty ? settings.text(.noArtistsYet) : settings.text(.noMatchingArtists),
                        systemImage: "music.mic",
                        detail: searchText.isEmpty ? settings.text(.importPrompt) : nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 22)], spacing: 28) {
                        ForEach(filteredArtists, id: \.id) { artist in
                            Button {
                                selectedArtist = artist
                                artistSearchText = ""
                                albumSearchText = ""
                            } label: {
                                ArtistTile(artist: artist)
                            }
                            .buttonStyle(MintContentButtonStyle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 132)
        }
    }
}

private struct ArtistTile: View {
    @EnvironmentObject private var settings: SettingsManager
    let artist: ArtistSummary

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ArtworkImage(path: artist.coverPath, cornerRadius: 66, targetSize: CGSize(width: 132, height: 132))
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 7)

            VStack(alignment: .center, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(countSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
    }

    private var countSummary: String {
        "\(artist.albumCount) \(settings.text(.albums).lowercased()) · \(artist.songCount) \(settings.text(.songs).lowercased())"
    }
}

private struct ArtistDetailView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    let artist: ArtistSummary
    @Binding var searchText: String
    let onBack: () -> Void
    let onAlbumSelect: (AlbumSummary) -> Void

    @State private var artistSongs: [Song] = []
    @State private var artistAlbums: [AlbumSummary] = []
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var songSortOrder = [KeyPathComparator(\Song.album), KeyPathComparator(\Song.title)]

    private var visibleArtistAlbums: [AlbumSummary] {
        guard !searchText.isEmpty else {
            return artistAlbums
        }

        return artistAlbums.filter { album in
            album.title.localizedCaseInsensitiveContains(searchText) ||
                (album.year > 0 && "\(album.year)".contains(searchText))
        }
    }

    private var visibleArtistSongs: [Song] {
        guard !searchText.isEmpty else {
            return artistSongs
        }

        return artistSongs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
                song.album.localizedCaseInsensitiveContains(searchText) ||
                song.displayGenre.localizedCaseInsensitiveContains(searchText)
        }
    }

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

                artistHeader

                if visibleArtistAlbums.isEmpty && visibleArtistSongs.isEmpty {
                    EmptyStateView(
                        title: settings.text(.noMatchingMusic),
                        systemImage: "magnifyingglass",
                        detail: settings.text(.artistSearchHint)
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    artistAlbumsSection
                    artistSongsSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 32)
            .padding(.bottom, 150)
        }
        .task(id: artist.id) {
            refreshArtistData()
        }
        .onChange(of: searchText) {
            pruneSongSelection()
        }
    }

    @ViewBuilder
    private var artistAlbumsSection: some View {
        if !visibleArtistAlbums.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(settings.text(.albums))
                    .font(.title.bold())

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 24) {
                    ForEach(visibleArtistAlbums, id: \.id) { album in
                        Button {
                            onAlbumSelect(album)
                        } label: {
                            ArtistAlbumTile(album: album)
                        }
                        .buttonStyle(MintContentButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var artistSongsSection: some View {
        if !visibleArtistSongs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(settings.text(.songs))
                    .font(.title.bold())
                    .padding(.bottom, 4)

                NativeSongTableView(
                    songs: visibleArtistSongs,
                    style: .detailSongs(subtitle: .album),
                    selectedSongIDs: $selectedSongIDs,
                    sortOrder: $songSortOrder,
                    onPlay: { song, queue in audioPlayer.play(song: song, in: queue) },
                    onPlayNext: audioPlayer.playNext,
                    onAddToQueue: audioPlayer.addToQueue
                )
                .frame(height: songTableHeight(for: visibleArtistSongs.count))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var artistHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 28) {
                artistArtwork
                artistHeaderInfo
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 16) {
                artistArtwork
                artistHeaderInfo
            }
        }
    }

    private var artistArtwork: some View {
        ArtworkImage(path: artist.coverPath, cornerRadius: 82, targetSize: CGSize(width: 164, height: 164))
            .frame(width: 164, height: 164)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.22), radius: 13, x: 0, y: 7)
    }

    private var artistHeaderInfo: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(artist.name)
                .font(.system(size: 31, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(artist.albumCount) \(settings.text(.albums).lowercased()) · \(artist.songCount) \(settings.text(.songs).lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ListPlaybackControls(
                songs: artistSongs,
                playAction: playArtist,
                shuffleAction: shuffleArtist
            )
            .padding(.top, 14)
        }
    }

    private func playArtist() {
        audioPlayer.play(songs: artistSongs)
    }

    private func shuffleArtist() {
        audioPlayer.shuffle(songs: artistSongs)
    }

    private func refreshArtistData() {
        artistAlbums = musicLibrary.albums(forArtist: artist)
        artistSongs = musicLibrary.songs(forArtist: artist).sorted {
            if $0.album == $1.album {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending
        }
        pruneSongSelection()
    }

    private func pruneSongSelection() {
        let visibleIDs = Set(visibleArtistSongs.map(\.id))
        selectedSongIDs = selectedSongIDs.filter { visibleIDs.contains($0) }
    }

    private func songTableHeight(for count: Int) -> CGFloat {
        min(max(CGFloat(max(count, 1)) * 58 + 10, 180), 620)
    }
}

private struct ArtistAlbumTile: View {
    @EnvironmentObject private var settings: SettingsManager
    let album: AlbumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkImage(path: album.coverPath, cornerRadius: 10)
                .frame(width: 140, height: 140)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            Text(album.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(album.year > 0 ? "\(album.year)" : "\(album.songCount) \(settings.text(.songs).lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
        .contentShape(Rectangle())
    }
}
