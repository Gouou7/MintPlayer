import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    let onNavigate: (LibrarySelection) -> Void

    @State private var searchText = ""
    @State private var showsRecentSongs = false
    @State private var recentSearchText = ""
    @State private var recentSongs: [Song] = []
    @State private var recentPlaybackSongs: [Song] = []
    @State private var suggestedSong: Song?
    @State private var displayedSongs: [Song] = []
    @State private var displayedRecentSongs: [Song] = []
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var recentSelectedSongIDs = Set<Song.ID>()
    @State private var sortOrder: [KeyPathComparator<Song>] = []
    @State private var recentSortOrder: [KeyPathComparator<Song>] = []

    private let recentSongLimit = 5
    private let recentSongsDetailLimit = 200

    private var pageSwitchAnimation: Animation {
        .easeInOut(duration: reducesMotion ? 0.16 : 0.26)
    }

    private func pageTransition(offset: CGFloat) -> AnyTransition {
        reducesMotion ? .opacity : .opacity.combined(with: .offset(x: offset))
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: {
                searchText = $0
                rebuildDisplayedSongs()
            }
        )
    }

    private var sortOrderBinding: Binding<[KeyPathComparator<Song>]> {
        Binding(
            get: { sortOrder },
            set: {
                sortOrder = $0
                rebuildDisplayedSongs()
            }
        )
    }

    private var recentSearchTextBinding: Binding<String> {
        Binding(
            get: { recentSearchText },
            set: {
                recentSearchText = $0
                rebuildDisplayedRecentSongs()
            }
        )
    }

    private var recentSortOrderBinding: Binding<[KeyPathComparator<Song>]> {
        Binding(
            get: { recentSortOrder },
            set: {
                recentSortOrder = $0
                rebuildDisplayedRecentSongs()
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsRecentSongs {
                recentSongsDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(pageTransition(offset: 24))
                    .zIndex(1)
            } else {
                Group {
                    if isSearching {
                        searchResults
                    } else {
                        overview
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(pageTransition(offset: -24))
                .zIndex(0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .preference(
            key: LibraryToolbarPreferenceKey.self,
            value: LibraryToolbarConfiguration(
                id: showsRecentSongs ? "home.recentSongs" : "home",
                searchText: showsRecentSongs ? recentSearchTextBinding : searchTextBinding,
                searchPrompt: settings.text(.searchSongs),
                sortOrder: showsRecentSongs ? recentSortOrderBinding : (isSearching ? sortOrderBinding : nil),
                backTitle: showsRecentSongs ? settings.text(.home) : nil,
                onBack: showsRecentSongs ? returnHome : nil
            )
        )
        .onAppear(perform: refreshLibraryContent)
        .onChange(of: musicLibrary.songs) { _, _ in refreshLibraryContent() }
        .background {
            HomePlaybackHistoryObserver { songs in
                recentPlaybackSongs = songs
                refreshLibraryContent()
            }
            .frame(width: 0, height: 0)
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if musicLibrary.songs.isEmpty {
                    EmptyStateView(
                        title: settings.text(.noSongsYet),
                        systemImage: "house.fill",
                        detail: settings.text(.importPrompt),
                        actionTitle: settings.text(.addMusicFolder),
                        action: { MusicFolderImporter.present(for: musicLibrary) }
                    )
                    .frame(minHeight: 360)
                } else {
                    listeningHeader

                    recentlyPlayedSection
                }
            }
            .frame(maxWidth: 1160, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 132)
        }
    }

    private var listeningHeader: some View {
        HomePlaybackHeaderLayout {
            Text(settings.text(.quickPlay))
                .font(.title2.bold())
                .lineLimit(1)
            Text(settings.text(.resumePlayback))
                .font(.title2.bold())
                .lineLimit(1)
            HomeQuickPlay(onNavigate: onNavigate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HomeListeningCard(suggestedSong: suggestedSong)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(settings.text(.recentlyPlayed))
                    .font(.title2.bold())
                Spacer()
                if recentSongs.count > recentSongLimit {
                    Button {
                        recentSearchText = ""
                        rebuildDisplayedRecentSongs()
                        withAnimation(pageSwitchAnimation) {
                            showsRecentSongs = true
                        }
                    } label: {
                        Label(settings.text(.showMore), systemImage: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            if recentSongs.isEmpty {
                EmptyStateView(
                    title: settings.text(.noRecentlyPlayed),
                    systemImage: "clock",
                    detail: settings.text(.recentlyPlayedHint)
                )
                .frame(height: 180)
            } else {
                DetailedSongList(
                    songs: displayedSongs,
                    columnPreferenceScope: .home,
                    selectedSongIDs: $selectedSongIDs,
                    sortOrder: sortOrderBinding
                )
                .frame(height: CGFloat(displayedSongs.count) * 60 + 36)
            }
        }
    }

    private var recentSongsDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(settings.text(.recentlyPlayed))
                .font(.title2.bold())
            HStack(spacing: 16) {
                HomeSearchPlaybackControls(songs: displayedRecentSongs)
                Text("\(displayedRecentSongs.count) \(settings.text(.tracks))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if displayedRecentSongs.isEmpty {
                EmptyStateView(
                    title: settings.text(recentSearchText.isEmpty ? .noRecentlyPlayed : .noMatchingSongs),
                    systemImage: "clock"
                )
            } else {
                DetailedSongList(
                    songs: displayedRecentSongs,
                    columnPreferenceScope: .home,
                    bottomContentInset: 112,
                    selectedSongIDs: $recentSelectedSongIDs,
                    sortOrder: recentSortOrderBinding
                )
            }
        }
        .padding(.leading, 28)
        .padding(.top, 28)
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                HomeSearchPlaybackControls(songs: displayedSongs)
                Text("\(displayedSongs.count) \(settings.text(.tracks))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if displayedSongs.isEmpty {
                EmptyStateView(title: settings.text(.noMatchingSongs), systemImage: "music.note.list")
            } else {
                DetailedSongList(
                    songs: displayedSongs,
                    columnPreferenceScope: .home,
                    bottomContentInset: 112,
                    selectedSongIDs: $selectedSongIDs,
                    sortOrder: sortOrderBinding
                )
            }
        }
        .padding(.leading, 28)
        .padding(.top, 28)
    }

    private func refreshLibraryContent() {
        // Combine session history with saved statistics without changing playback counting.
        let songsByID = Dictionary(uniqueKeysWithValues: musicLibrary.songs.map { ($0.id, $0) })
        let recordedSongs = musicLibrary.songs.filter { $0.lastPlayedAt != nil }.sorted {
            ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast)
        }
        var seenSongs = Set<Song.ID>()
        recentSongs = (recentPlaybackSongs + recordedSongs).compactMap { song in
            guard let currentSong = songsByID[song.id], seenSongs.insert(song.id).inserted else { return nil }
            return currentSong
        }
        suggestedSong = recentSongs.first ?? musicLibrary.songs.first
        rebuildDisplayedSongs()
        rebuildDisplayedRecentSongs()
    }

    private func rebuildDisplayedSongs() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: [Song]
        if query.isEmpty {
            source = Array(recentSongs.prefix(recentSongLimit))
        } else {
            source = musicLibrary.songs.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.artist.localizedCaseInsensitiveContains(query)
                    || $0.album.localizedCaseInsensitiveContains(query)
                    || $0.displayGenre.localizedCaseInsensitiveContains(query)
            }
        }
        displayedSongs = sortOrder.isEmpty ? source : source.sorted(using: sortOrder)
        selectedSongIDs.formIntersection(Set(displayedSongs.map(\.id)))
    }

    private func rebuildDisplayedRecentSongs() {
        let query = recentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let songs = recentSongs.prefix(recentSongsDetailLimit).filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || $0.album.localizedCaseInsensitiveContains(query)
                || $0.displayGenre.localizedCaseInsensitiveContains(query)
        }
        displayedRecentSongs = recentSortOrder.isEmpty ? songs : songs.sorted(using: recentSortOrder)
        recentSelectedSongIDs.formIntersection(Set(displayedRecentSongs.map(\.id)))
    }

    private func returnHome() {
        withAnimation(pageSwitchAnimation) {
            showsRecentSongs = false
        }
    }
}

private struct HomePlaybackHeaderLayout: Layout {
    private let quickPlayWidth: CGFloat = 192
    private let horizontalSpacing: CGFloat = 20
    private let verticalSpacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 4 else { return .zero }
        let width = proposal.width ?? subviews[3].sizeThatFits(.unspecified).width + horizontalSpacing + quickPlayWidth
        let heights = measuredHeights(width: width, subviews: subviews)
        return CGSize(width: width, height: heights.title + verticalSpacing + heights.cards)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let rightWidth = max(bounds.width - horizontalSpacing - quickPlayWidth, 0)
        let rightX = bounds.minX + quickPlayWidth + horizontalSpacing
        let heights = measuredHeights(width: bounds.width, subviews: subviews)
        let cardsY = bounds.minY + heights.title + verticalSpacing
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
            proposal: ProposedViewSize(width: quickPlayWidth, height: heights.title)
        )
        subviews[1].place(
            at: CGPoint(x: rightX, y: bounds.minY), anchor: .topLeading,
            proposal: ProposedViewSize(width: rightWidth, height: heights.title)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX, y: cardsY), anchor: .topLeading,
            proposal: ProposedViewSize(width: quickPlayWidth, height: heights.cards)
        )
        subviews[3].place(
            at: CGPoint(x: rightX, y: cardsY), anchor: .topLeading,
            proposal: ProposedViewSize(width: rightWidth, height: heights.cards)
        )
    }

    private func measuredHeights(width: CGFloat, subviews: Subviews) -> (title: CGFloat, cards: CGFloat) {
        let leftProposal = ProposedViewSize(width: quickPlayWidth, height: nil)
        let rightProposal = ProposedViewSize(width: max(width - horizontalSpacing - quickPlayWidth, 0), height: nil)
        return (
            title: max(subviews[0].sizeThatFits(leftProposal).height, subviews[1].sizeThatFits(rightProposal).height),
            cards: max(subviews[2].sizeThatFits(leftProposal).height, subviews[3].sizeThatFits(rightProposal).height)
        )
    }
}

private struct HomeListeningCard: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    let suggestedSong: Song?

    var body: some View {
        if let song = audioPlayer.currentSong ?? suggestedSong {
            HStack(alignment: .center, spacing: 16) {
                ArtworkImage(path: song.coverPath, cornerRadius: 10, targetSize: CGSize(width: 112, height: 112), crossfadeChanges: true)
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(song.title)
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(2)
                    Text("\(song.artist) - \(song.album)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        Button {
                            if audioPlayer.currentSong != nil {
                                audioPlayer.togglePlayPause()
                            } else {
                                audioPlayer.play(song: song, in: musicLibrary.songs)
                            }
                        } label: {
                            Label(buttonTitle, systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .frame(width: ListPlaybackControls.buttonWidth, height: ListPlaybackControls.buttonHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                        .fixedSize()
                        if audioPlayer.currentSong != nil {
                            Text(playbackCaption)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var buttonTitle: String {
        if audioPlayer.isPlaying { return settings.text(.pause) }
        return settings.text(audioPlayer.currentSong == nil ? .play : .resumePlayback)
    }

    private var playbackCaption: String {
        if audioPlayer.isPlaying { return settings.text(.nowPlaying) }
        if audioPlayer.currentTime >= audioPlayer.duration { return settings.text(.startListening) }
        let seconds = Int(max(audioPlayer.currentTime, 0))
        let time = String(format: "%d:%02d", seconds / 60, seconds % 60)
        return String(format: settings.text(.resumeFromTime), time)
    }
}

private struct HomeQuickPlay: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    let onNavigate: (LibrarySelection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            favoritesOrAlbumsAction
            shuffleAction
        }
    }

    @ViewBuilder
    private var favoritesOrAlbumsAction: some View {
        if !musicLibrary.favoriteSongs.isEmpty {
            quickAction(title: settings.text(.favorites), detail: settings.text(.playFavoriteSongs), systemImage: "heart.fill") {
                audioPlayer.play(songs: musicLibrary.favoriteSongs)
            }
        } else {
            quickAction(title: settings.text(.albums), detail: settings.text(.browseAlbums), systemImage: "square.stack.fill") {
                onNavigate(.albums)
            }
        }
    }

    private var shuffleAction: some View {
        quickAction(title: settings.text(.shuffle), detail: settings.text(.shuffleLibrary), systemImage: "shuffle") {
            audioPlayer.shuffle(songs: musicLibrary.songs)
        }
    }

    private func quickAction(title: String, detail: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(MintContentButtonStyle(cornerRadius: 16, hoverOutset: 0))
        .frame(maxHeight: .infinity)
    }
}

private struct HomePlaybackHistoryObserver: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    let onChange: ([Song]) -> Void

    var body: some View {
        Color.clear
            .onAppear(perform: publishHistory)
            .onChange(of: audioPlayer.currentSong?.id) { _, _ in publishHistory() }
            .onChange(of: audioPlayer.history.map(\.id)) { _, _ in publishHistory() }
    }

    private func publishHistory() {
        onChange((audioPlayer.currentSong.map { [$0] } ?? []) + audioPlayer.history)
    }
}

private struct HomeSearchPlaybackControls: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    let songs: [Song]

    var body: some View {
        ListPlaybackControls(
            songs: songs,
            playAction: { audioPlayer.play(songs: songs) },
            shuffleAction: { audioPlayer.shuffle(songs: songs) }
        )
    }
}
