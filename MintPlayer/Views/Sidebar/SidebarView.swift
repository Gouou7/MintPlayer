import SwiftUI
import AppKit

struct SidebarView: View {
    @Binding var selection: LibrarySelection
    @EnvironmentObject private var musicLibrary: MusicLibrary
    
    @AppStorage("sidebar.library.isExpanded") private var isLibraryExpanded = true
    @AppStorage("sidebar.playlists.isExpanded") private var isPlaylistsExpanded = true
    @AppStorage("sidebar.folders.isExpanded") private var isFoldersExpanded = true
    @AppStorage("sidebar.library.order") private var libraryOrderStorage = LibrarySidebarItem.allCases.map(\.rawValue).joined(separator: ",")
    @State private var playlistEditorDraft: PlaylistEditorDraft?
    @State private var playlistPendingDeletion: Playlist?
    @State private var folderPendingDeletion: MusicLibrarySource?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            List {
                Section {
                    if isLibraryExpanded {
                        ForEach(orderedLibraryItems, id: \.self) { item in
                            Button {
                                selection = item.selection
                            } label: {
                                SidebarRow(
                                    title: item.title,
                                    systemImage: item.systemImage,
                                    isSelected: selection == item.selection
                                )
                            }
                            .buttonStyle(MintRowButtonStyle(isSelected: selection == item.selection))
                        }
                        .onMove(perform: moveLibraryItems)
                    }
                } header: {
                    CollapsibleSidebarHeader(title: "Library", isExpanded: $isLibraryExpanded)
                }
                
                Section {
                    if isPlaylistsExpanded {
                        if musicLibrary.playlists.isEmpty {
                            emptyRow("No playlists")
                        } else {
                            ForEach(musicLibrary.playlists, id: \.id) { playlist in
                                Button {
                                    selection = .playlist(playlist.id)
                                } label: {
                                    SidebarRow(
                                        title: playlist.name,
                                        systemImage: "music.note.list",
                                        isSelected: selection == .playlist(playlist.id)
                                    )
                                }
                                .buttonStyle(MintRowButtonStyle(isSelected: selection == .playlist(playlist.id)))
                                .contextMenu {
                                    Button {
                                        editPlaylist(playlist)
                                    } label: {
                                        Label("Edit Playlist", systemImage: "pencil")
                                    }
                                    
                                    Button {
                                        playlistPendingDeletion = playlist
                                    } label: {
                                        Label("Delete Playlist", systemImage: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .background {
                                    PlaylistDropDestination(
                                        playlistId: playlist.id,
                                        musicLibrary: musicLibrary
                                    )
                                }
                                .onDrop(of: SongDragPayload.acceptedContentTypes, isTargeted: nil) { providers in
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
                        title: "Playlists",
                        isExpanded: $isPlaylistsExpanded,
                        addSystemImage: "plus",
                        addHelp: "New playlist",
                        addAction: createPlaylist
                    )
                }
                
                Section {
                    if isFoldersExpanded {
                        if musicLibrary.librarySources.isEmpty {
                            emptyRow("No folders")
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
                                        Label("Delete Folder", systemImage: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    CollapsibleSidebarHeader(
                        title: "Folders",
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
            "Delete Playlist?",
            isPresented: playlistDeletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: playlistPendingDeletion
        ) { playlist in
            Button("Delete Playlist", role: .destructive) {
                deletePlaylist(playlist)
                playlistPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                playlistPendingDeletion = nil
            }
        } message: { playlist in
            Text("This will remove \"\(playlist.name)\" from Mint Player. Songs will stay in your library.")
        }
        .confirmationDialog(
            "Delete Folder?",
            isPresented: folderDeletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { source in
            Button("Delete Folder", role: .destructive) {
                deleteFolder(source)
                folderPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: { source in
            Text("This will remove \"\(source.name)\" and its songs from Mint Player. Files on disk will not be deleted.")
        }
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(MintTheme.accent)
            Text("Mint Player")
                .font(.headline)
                .bold()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
            Label("Settings", systemImage: "gearshape.fill")
                .labelStyle(.iconOnly)
        }
        .controlSize(.large)
        .foregroundStyle(.secondary)
        .help("Settings")
    }
    
    private var orderedLibraryItems: [LibrarySidebarItem] {
        let storedItems = libraryOrderStorage
            .split(separator: ",")
            .compactMap { LibrarySidebarItem(rawValue: String($0)) }
        let missingItems = LibrarySidebarItem.allCases.filter { !storedItems.contains($0) }
        return storedItems + missingItems
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
        var items = orderedLibraryItems
        items.move(fromOffsets: source, toOffset: destination)
        libraryOrderStorage = items.map(\.rawValue).joined(separator: ",")
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
