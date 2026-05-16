import SwiftUI

struct SongsView: View {
    enum Presentation {
        case detailedList
        case table
    }
    
    @EnvironmentObject private var musicLibrary: MusicLibrary
    
    let title: String
    let subtitle: String?
    let description: String?
    let scopedSongs: [Song]?
    let presentation: Presentation
    
    @State private var searchText = ""
    @State private var selectedSongIDs = Set<Song.ID>()
    @State private var sortOrder = [KeyPathComparator(\Song.title)]
    @State private var displayedSongs: [Song] = []
    
    init(
        title: String = "Songs",
        subtitle: String? = nil,
        description: String? = nil,
        scopedSongs: [Song]? = nil,
        presentation: Presentation = .detailedList
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.scopedSongs = scopedSongs
        self.presentation = presentation
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
                metadataHeader
                
                if displayedSongs.isEmpty {
                    EmptyStateView(
                        title: searchText.isEmpty ? "No songs yet" : "No matching songs",
                        systemImage: "music.note.list",
                        detail: searchText.isEmpty ? "Import a folder or drag audio files into this window." : nil
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LibrarySearchControls(searchText: searchTextBinding, searchPrompt: "Search Songs") {
                    SongSortButton(sortOrder: sortOrderBinding)
                }
            }
            .sharedBackgroundVisibility(.hidden)
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
    private var songContent: some View {
        switch presentation {
        case .detailedList:
            DetailedSongList(
                songs: displayedSongs,
                selectedSongIDs: $selectedSongIDs,
                sortOrder: sortOrderBinding
            )
        case .table:
            CustomizableSongsTable(
                songs: displayedSongs,
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
}
