import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @State private var searchText = ""
    @State private var artistSearchText = ""
    @State private var albumSearchText = ""
    @State private var selectedArtist: ArtistSummary?
    @State private var selectedAlbum: AlbumSummary?
    @Namespace private var artistArtworkTransitionNamespace
    @Namespace private var artistAlbumArtworkTransitionNamespace

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
            if selectedArtist == nil && selectedAlbum == nil {
                ToolbarItem(placement: .primaryAction) {
                    NativeToolbarSearchField(text: activeSearchText, prompt: searchPrompt)
                }
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
            AlbumDetailView(
                album: selectedAlbum,
                searchText: $albumSearchText,
                artworkTransitionNamespace: artistAlbumArtworkTransitionNamespace,
                artworkTransitionID: selectedAlbum.id
            ) {
                withAnimation(.smooth(duration: 0.32)) {
                    albumSearchText = ""
                    self.selectedAlbum = nil
                }
            }
            .zIndex(2)
        } else if let selectedArtist {
            ArtistDetailView(
                artist: selectedArtist,
                searchText: $artistSearchText,
                artistArtworkTransitionNamespace: artistArtworkTransitionNamespace,
                artistArtworkTransitionID: selectedArtist.id,
                albumArtworkTransitionNamespace: artistAlbumArtworkTransitionNamespace,
                onBack: {
                    withAnimation(.smooth(duration: 0.32)) {
                        artistSearchText = ""
                        albumSearchText = ""
                        self.selectedArtist = nil
                    }
                },
                onAlbumSelect: { album in
                    withAnimation(.smooth(duration: 0.32)) {
                        albumSearchText = ""
                        selectedAlbum = album
                    }
                }
            )
            .zIndex(1)
        } else {
            artistGrid
                .zIndex(0)
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
                                withAnimation(.smooth(duration: 0.32)) {
                                    selectedArtist = artist
                                    artistSearchText = ""
                                    albumSearchText = ""
                                }
                            } label: {
                                ArtistTile(
                                    artist: artist,
                                    artworkTransitionNamespace: artistArtworkTransitionNamespace,
                                    artworkTransitionID: artist.id
                                )
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
    let artworkTransitionNamespace: Namespace.ID
    let artworkTransitionID: String

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ArtworkImage(path: artist.coverPath, cornerRadius: 66, targetSize: CGSize(width: 132, height: 132))
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .matchedGeometryEffect(id: artworkTransitionID, in: artworkTransitionNamespace, properties: .frame)
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
    let artistArtworkTransitionNamespace: Namespace.ID?
    let artistArtworkTransitionID: String?
    let albumArtworkTransitionNamespace: Namespace.ID?
    let onBack: () -> Void
    let onAlbumSelect: (AlbumSummary) -> Void

    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var songSortOrder = [KeyPathComparator(\Song.album), KeyPathComparator(\Song.title)]

    private var artistAlbums: [AlbumSummary] {
        musicLibrary.albums(forArtist: artist)
    }

    private var artistSongs: [Song] {
        musicLibrary.songs(forArtist: artist).sorted {
            if $0.album == $1.album {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending
        }
    }

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
        .onChange(of: searchText) {
            pruneSongSelection()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label(backButtonTitle, systemImage: "chevron.left")
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private var backButtonTitle: String {
        settings.effectiveLanguage == .chinese ? "返回" : "Back"
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
                            ArtistAlbumTile(
                                album: album,
                                artworkTransitionNamespace: albumArtworkTransitionNamespace,
                                artworkTransitionID: album.id
                            )
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
        ArtworkHeaderLayout(spacing: 28, minimumHorizontalInfoWidth: 300) {
            artistArtwork
            artistHeaderInfo
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var artistArtwork: some View {
        ArtworkImage(path: artist.coverPath, cornerRadius: 82, targetSize: CGSize(width: 164, height: 164))
            .frame(width: 164, height: 164)
            .clipShape(Circle())
            .matchedGeometryEffectIfPresent(id: artistArtworkTransitionID, in: artistArtworkTransitionNamespace, properties: .frame)
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
    let artworkTransitionNamespace: Namespace.ID?
    let artworkTransitionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkImage(path: album.coverPath, cornerRadius: 10)
                .matchedGeometryEffectIfPresent(id: artworkTransitionID, in: artworkTransitionNamespace, properties: .frame)
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

private extension View {
    @ViewBuilder
    func matchedGeometryEffectIfPresent(
        id: String?,
        in namespace: Namespace.ID?,
        properties: MatchedGeometryProperties = .frame
    ) -> some View {
        if let id, let namespace {
            matchedGeometryEffect(id: id, in: namespace, properties: properties)
        } else {
            self
        }
    }
}
