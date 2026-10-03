import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    let onNavigate: (LibrarySelection) -> Void
    let onShowLyrics: () -> Void

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
                HomeWidgetArea(suggestedSong: suggestedSong, onShowLyrics: onShowLyrics)

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

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.text(.recentlyPlayed))
                .font(.title2.bold())
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
