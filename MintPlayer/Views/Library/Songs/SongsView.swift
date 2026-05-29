import SwiftUI

struct SongsView: View {
    enum Presentation: Equatable {
        case detailedList
        case table
    }

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.isPlayerOverlayPresented) private var isPlayerOverlayPresented

    let title: String
    let subtitle: String?
    let description: String?
    let scopedSongs: [Song]?
    let presentation: Presentation
    let playlistId: UUID?
    let columnPreferenceScope: NativeSongTableView.ColumnPreferenceScope

    @State private var searchText = ""
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var sortOrder = [KeyPathComparator(\Song.title)]
    @State private var displayedSongs: [Song] = []

    init(
        title: String = "Songs",
        subtitle: String? = nil,
        description: String? = nil,
        scopedSongs: [Song]? = nil,
        presentation: Presentation = .detailedList,
        playlistId: UUID? = nil,
        columnPreferenceScope: NativeSongTableView.ColumnPreferenceScope = .songs
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.scopedSongs = scopedSongs
        self.presentation = presentation
        self.playlistId = playlistId
        self.columnPreferenceScope = columnPreferenceScope
    }

    private var sourceSongs: [Song] {
        scopedSongs ?? musicLibrary.songs
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: { newValue in
                searchText = newValue
                rebuildDisplayedSongs(searchText: newValue)
            }
        )
    }

    private var sortOrderBinding: Binding<[KeyPathComparator<Song>]> {
        Binding(
            get: { sortOrder },
            set: { newValue in
                sortOrder = newValue
                rebuildDisplayedSongs(sortOrder: newValue)
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 18) {
                topControls

                if displayedSongs.isEmpty {
                    EmptyStateView(
                        title: searchText.isEmpty ? settings.text(.noSongsYet) : settings.text(.noMatchingSongs),
                        systemImage: "music.note.list",
                        detail: searchText.isEmpty ? settings.text(.importPrompt) : nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    songContent
                }
            }
            .padding(.leading, 28)
            .padding(.trailing, 0)
            .padding(.top, 28)
            .padding(.bottom, 0)
        }
        .background(Color(nsColor: NativeSongBackgroundColor.value))
        .toolbar {
            if !isPlayerOverlayPresented {
                ToolbarItem(placement: .primaryAction) {
                    SongSortButton(sortOrder: sortOrderBinding)
                }

                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItem(placement: .primaryAction) {
                    NativeToolbarSearchField(
                        text: searchTextBinding,
                        prompt: settings.text(.searchSongs)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            rebuildDisplayedSongs()
        }
        .onChange(of: sourceSongs) { _, _ in
            rebuildDisplayedSongs()
        }
    }

    @ViewBuilder
    private var topControls: some View {
        if presentation == .detailedList, !displayedSongs.isEmpty {
            HStack(alignment: .center, spacing: 16) {
                playbackControls
                metadataHeader
            }
        } else {
            metadataHeader
        }
    }

    @ViewBuilder
    private var metadataHeader: some View {
        if subtitle != nil || (description?.isEmpty == false) {
            VStack(alignment: .leading, spacing: 4) {
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        if presentation == .detailedList {
            ListPlaybackControls(
                songs: displayedSongs,
                playAction: playDisplayedSongs,
                shuffleAction: shuffleDisplayedSongs
            )
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private var songContent: some View {
        switch presentation {
        case .detailedList:
            DetailedSongList(
                songs: displayedSongs,
                columnPreferenceScope: columnPreferenceScope,
                bottomContentInset: 112,
                playlistId: playlistId,
                selectedSongIDs: $selectedSongIDs,
                sortOrder: sortOrderBinding
            )
        case .table:
            CustomizableSongsTable(
                songs: displayedSongs,
                columnPreferenceScope: columnPreferenceScope,
                bottomContentInset: 112,
                playlistId: playlistId,
                selectedSongIDs: $selectedSongIDs,
                sortOrder: sortOrderBinding
            )
        }
    }

    private func rebuildDisplayedSongs(
        searchText requestedSearchText: String? = nil,
        sortOrder requestedSortOrder: [KeyPathComparator<Song>]? = nil
    ) {
        let activeSearchText = requestedSearchText ?? searchText
        let activeSortOrder = requestedSortOrder ?? sortOrder
        let filteredSongs: [Song]

        if activeSearchText.isEmpty {
            filteredSongs = sourceSongs
        } else {
            filteredSongs = sourceSongs.filter { song in
                song.title.localizedCaseInsensitiveContains(activeSearchText) ||
                    song.artist.localizedCaseInsensitiveContains(activeSearchText) ||
                    song.album.localizedCaseInsensitiveContains(activeSearchText) ||
                    song.displayGenre.localizedCaseInsensitiveContains(activeSearchText)
            }
        }

        let nextDisplayedSongs = filteredSongs.sorted(using: activeSortOrder)
        displayedSongs = nextDisplayedSongs

        let visibleIDs = Set(nextDisplayedSongs.map(\.id))
        selectedSongIDs = selectedSongIDs.filter { visibleIDs.contains($0) }
    }

    private func playDisplayedSongs() {
        audioPlayer.play(songs: displayedSongs)
    }

    private func shuffleDisplayedSongs() {
        audioPlayer.shuffle(songs: displayedSongs)
    }
}

private enum NativeSongBackgroundColor {
    static let value = NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
            ? NSColor(calibratedRed: 0.105, green: 0.101, blue: 0.097, alpha: 1)
            : .white
    }
}
