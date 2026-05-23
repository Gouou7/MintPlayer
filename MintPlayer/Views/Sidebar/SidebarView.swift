import SwiftUI
import AppKit

struct SidebarView: View {
    @Binding var selection: LibrarySelection
    @EnvironmentObject private var musicLibrary: MusicLibrary
    @EnvironmentObject private var settings: SettingsManager

    @AppStorage(AppConfiguration.userDefaultsKey("sidebar.playlists.isExpanded")) private var isPlaylistsExpanded = true
    @AppStorage(AppConfiguration.userDefaultsKey("sidebar.folders.isExpanded")) private var isFoldersExpanded = true
    @AppStorage(AppConfiguration.userDefaultsKey("sidebar.library.order")) private var libraryOrderStorage = LibrarySidebarItem.allCases.map(\.rawValue).joined(separator: ",")
    @State private var playlistEditorDraft: PlaylistEditorDraft?
    @State private var playlistPendingDeletion: Playlist?
    @State private var folderPendingDeletion: MusicLibrarySource?
    @State private var dropTargetedPlaylistID: Playlist.ID?

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(orderedLibraryItems, id: \.self) { item in
                        Button {
                            selection = item.selection
                        } label: {
                            SidebarRow(
                                title: item.title(language: settings.effectiveLanguage),
                                systemImage: item.systemImage,
                                isSelected: selection == item.selection
                            )
                        }
                        .buttonStyle(MintRowButtonStyle(isSelected: selection == item.selection))
                    }
                    .onMove(perform: moveLibraryItems)
                }

                Section {
                    if isPlaylistsExpanded {
                        if musicLibrary.playlists.isEmpty {
                            emptyRow(settings.text(.noPlaylists))
                        } else {
                            ForEach(musicLibrary.playlists, id: \.id) { playlist in
                                let isDropTargeted = dropTargetedPlaylistID == playlist.id

                                Button {
                                    selection = .playlist(playlist.id)
                                } label: {
                                    SidebarRow(
                                        title: playlist.name,
                                        systemImage: "music.note.list",
                                        isSelected: selection == .playlist(playlist.id)
                                    )
                                }
                                .buttonStyle(MintRowButtonStyle(isSelected: selection == .playlist(playlist.id), isHighlighted: isDropTargeted))
                                .contextMenu {
                                    Button {
                                        editPlaylist(playlist)
                                    } label: {
                                        Label(settings.text(.editPlaylistAction), systemImage: "pencil")
                                    }

                                    Button {
                                        playlistPendingDeletion = playlist
                                    } label: {
                                        Label(settings.text(.deletePlaylist), systemImage: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .background {
                                    PlaylistDropDestination(
                                        playlistId: playlist.id,
                                        musicLibrary: musicLibrary
                                    )
                                }
                                .onDrop(of: SongDragPayload.acceptedContentTypes, isTargeted: dropTargetBinding(for: playlist.id)) { providers in
                                    SongDragPayload.loadSongs(from: providers, musicLibrary: musicLibrary) { songs in
                                        musicLibrary.addSongsToPlaylist(songs, playlistId: playlist.id)
                                    }
                                }
                            }
                            .onMove { source, destination in
                                musicLibrary.movePlaylists(from: source, to: destination)
                            }
                        }
                    }
                } header: {
                    CollapsibleSidebarHeader(
                        title: settings.text(.playlists),
                        isExpanded: $isPlaylistsExpanded,
                        addSystemImage: "plus",
                        addHelp: "New playlist",
                        addAction: createPlaylist
                    )
                }

                Section {
                    if isFoldersExpanded {
                        if musicLibrary.librarySources.isEmpty {
                            emptyRow(settings.text(.noFolders))
                        } else {
                            ForEach(musicLibrary.librarySources, id: \.id) { source in
                                Button {
                                    selection = .folder(source.id)
                                } label: {
                                    SidebarRow(
                                        title: source.name,
                                        systemImage: "folder.fill",
                                        isSelected: selection == .folder(source.id)
                                    )
                                }
                                .buttonStyle(MintRowButtonStyle(isSelected: selection == .folder(source.id)))
                                .contextMenu {
                                    Button {
                                        folderPendingDeletion = source
                                    } label: {
                                        Label(settings.text(.deleteFolder), systemImage: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    CollapsibleSidebarHeader(
                        title: settings.text(.foldersSection),
                        isExpanded: $isFoldersExpanded,
                        addSystemImage: "plus",
                        addHelp: "Add folder",
                        addAction: importFolder
                    )
                }
            }
            .listStyle(.sidebar)
            .tint(MintTheme.accent)
            .accentColor(MintTheme.accent)

            footer
        }
        .frame(minWidth: 204)
        .sheet(item: $playlistEditorDraft) { draft in
            PlaylistEditorSheet(
                draft: draft,
                onCancel: { playlistEditorDraft = nil },
                onSave: { name, description in
                    savePlaylist(draft: draft, name: name, description: description)
                }
            )
        }
        .confirmationDialog(
            settings.text(.deletePlaylistQuestion),
            isPresented: playlistDeletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: playlistPendingDeletion
        ) { playlist in
            Button(settings.text(.deletePlaylist), role: .destructive) {
                deletePlaylist(playlist)
                playlistPendingDeletion = nil
            }
            Button(settings.text(.cancel), role: .cancel) {
                playlistPendingDeletion = nil
            }
        } message: { playlist in
            Text(String(format: settings.text(.deletePlaylistMessage), playlist.name))
        }
        .confirmationDialog(
            settings.text(.deleteFolderQuestion),
            isPresented: folderDeletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { source in
            Button(settings.text(.deleteFolder), role: .destructive) {
                deleteFolder(source)
                folderPendingDeletion = nil
            }
            Button(settings.text(.cancel), role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: { source in
            Text(String(format: settings.text(.deleteFolderMessage), source.name))
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                settingsButton

                Spacer()
            }
            .font(.system(size: 18, weight: .semibold))
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var settingsButton: some View {
        SettingsLink {
            Label(settings.text(.settings), systemImage: "gearshape.fill")
                .labelStyle(.iconOnly)
        }
        .controlSize(.large)
        .foregroundStyle(.secondary)
        .help(settings.text(.settings))
    }

    private var orderedLibraryItems: [LibrarySidebarItem] {
        let storedItems = libraryOrderStorage
            .split(separator: ",")
            .compactMap { LibrarySidebarItem(rawValue: String($0)) }
        let missingItems = LibrarySidebarItem.allCases.filter { !storedItems.contains($0) }
        let movableItems = (storedItems + missingItems).filter { $0 != .favorites }
        return [.favorites] + movableItems
    }

    private var playlistDeletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { playlistPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    playlistPendingDeletion = nil
                }
            }
        )
    }

    private var folderDeletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { folderPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    folderPendingDeletion = nil
                }
            }
        )
    }

    private func emptyRow(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 36)
            .padding(.vertical, 7)
    }

    private func dropTargetBinding(for playlistId: Playlist.ID) -> Binding<Bool> {
        Binding(
            get: { dropTargetedPlaylistID == playlistId },
            set: { isTargeted in
                if isTargeted {
                    dropTargetedPlaylistID = playlistId
                } else if dropTargetedPlaylistID == playlistId {
                    dropTargetedPlaylistID = nil
                }
            }
        )
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        musicLibrary.addLibrarySource(name: url.lastPathComponent, path: url.path)
        selection = .folder(musicLibrary.librarySources.last?.id ?? UUID())
    }

    private func createPlaylist() {
        playlistEditorDraft = .create()
    }

    private func moveLibraryItems(from source: IndexSet, to destination: Int) {
        let favoritesIndex = 0
        let filteredSource = IndexSet(source.filter { $0 != favoritesIndex })
        guard !filteredSource.isEmpty else { return }

        var items = orderedLibraryItems
        items.move(fromOffsets: filteredSource, toOffset: max(destination, 1))
        items.removeAll { $0 == .favorites }
        libraryOrderStorage = ([.favorites] + items).map(\.rawValue).joined(separator: ",")
    }

    private func deletePlaylist(_ playlist: Playlist) {
        musicLibrary.deletePlaylist(id: playlist.id)
        if selection == .playlist(playlist.id) {
            selection = .songs
        }
    }

    private func editPlaylist(_ playlist: Playlist) {
        playlistEditorDraft = .edit(playlist)
    }

    private func savePlaylist(draft: PlaylistEditorDraft, name: String, description: String) {
        guard !name.isEmpty else { return }

        if let playlistId = draft.playlistId {
            musicLibrary.updatePlaylist(
                id: playlistId,
                name: name,
                description: description
            )
        } else {
            musicLibrary.createPlaylist(name: name, description: description)
            if let playlist = musicLibrary.playlists.last {
                selection = .playlist(playlist.id)
            }
        }

        playlistEditorDraft = nil
    }

    private func deleteFolder(_ source: MusicLibrarySource) {
        musicLibrary.removeLibrarySource(id: source.id)
        if selection == .folder(source.id) {
            selection = .songs
        }
    }
}
