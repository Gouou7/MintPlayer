import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @State private var searchText = ""
    @State private var selectedAlbum: AlbumSummary?
    @Namespace private var albumArtworkTransitionNamespace

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
                AlbumDetailView(
                    album: selectedAlbum,
                    searchText: $searchText,
                    artworkTransitionNamespace: albumArtworkTransitionNamespace,
                    artworkTransitionID: selectedAlbum.id
                ) {
                    withAnimation(.smooth(duration: 0.32)) {
                        self.selectedAlbum = nil
                    }
                }
                .zIndex(1)
            } else {
                albumGrid
                    .zIndex(0)
            }

        }
        .toolbar {
            if selectedAlbum == nil {
                ToolbarItem(placement: .primaryAction) {
                    NativeToolbarSearchField(
                        text: $searchText,
                        prompt: settings.text(.searchAlbums)
                    )
                }
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
                            withAnimation(.smooth(duration: 0.32)) {
                                selectedAlbum = album
                            }
                        } label: {
                            AlbumTile(
                                album: album,
                                artworkTransitionNamespace: albumArtworkTransitionNamespace,
                                artworkTransitionID: album.id
                            )
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
    let artworkTransitionNamespace: Namespace.ID
    let artworkTransitionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArtworkImage(path: album.coverPath, cornerRadius: 10)
                .matchedGeometryEffect(id: artworkTransitionID, in: artworkTransitionNamespace, properties: .frame)
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
    var artworkTransitionNamespace: Namespace.ID?
    var artworkTransitionID: String?
    let onBack: () -> Void

    @State private var albumSongs: [Song] = []
    @State private var visibleSongs: [Song] = []
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var songSortOrder = [KeyPathComparator(\Song.title)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
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

    private var albumHeader: some View {
        ArtworkHeaderLayout(spacing: 29, minimumHorizontalInfoWidth: 320) {
            albumArtwork
            albumHeaderInfo
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var albumArtwork: some View {
        ArtworkImage(path: album.coverPath, cornerRadius: 16)
            .matchedGeometryEffectIfPresent(id: artworkTransitionID, in: artworkTransitionNamespace, properties: .frame)
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

struct ArtworkHeaderLayout: Layout {
    let spacing: CGFloat
    let minimumHorizontalInfoWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let artworkSize = subviews[0].sizeThatFits(.unspecified)
        let proposalWidth = proposal.width

        if usesHorizontalLayout(width: proposalWidth, artworkWidth: artworkSize.width) {
            let availableInfoWidth = max((proposalWidth ?? 0) - artworkSize.width - spacing, 0)
            let infoSize = subviews[1].sizeThatFits(ProposedViewSize(width: availableInfoWidth, height: nil))
            return CGSize(
                width: proposalWidth ?? artworkSize.width + spacing + infoSize.width,
                height: max(artworkSize.height, infoSize.height)
            )
        }

        let infoSize = subviews[1].sizeThatFits(ProposedViewSize(width: proposalWidth, height: nil))
        return CGSize(
            width: proposalWidth ?? max(artworkSize.width, infoSize.width),
            height: artworkSize.height + spacing + infoSize.height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }

        let artworkSize = subviews[0].sizeThatFits(.unspecified)

        if usesHorizontalLayout(width: bounds.width, artworkWidth: artworkSize.width) {
            let infoWidth = max(bounds.width - artworkSize.width - spacing, 0)
            let infoSize = subviews[1].sizeThatFits(ProposedViewSize(width: infoWidth, height: nil))
            let artworkY = bounds.minY + (bounds.height - artworkSize.height) / 2
            let infoY = bounds.minY + (bounds.height - infoSize.height) / 2

            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: artworkY),
                proposal: ProposedViewSize(artworkSize)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + artworkSize.width + spacing, y: infoY),
                proposal: ProposedViewSize(width: infoWidth, height: infoSize.height)
            )
        } else {
            let infoSize = subviews[1].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                proposal: ProposedViewSize(artworkSize)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + artworkSize.height + spacing),
                proposal: ProposedViewSize(width: bounds.width, height: infoSize.height)
            )
        }
    }

    private func usesHorizontalLayout(width: CGFloat?, artworkWidth: CGFloat) -> Bool {
        guard let width else { return true }
        return width >= artworkWidth + spacing + minimumHorizontalInfoWidth
    }
}
