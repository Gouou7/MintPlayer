import Foundation
import AVFoundation

class MusicLibrary: ObservableObject {
    @Published var songs: [Song] = []
    @Published private(set) var albumSummaries: [AlbumSummary] = []
    @Published private(set) var artistSummaries: [ArtistSummary] = []
    @Published var playlists: [Playlist] = []
    @Published var librarySources: [MusicLibrarySource] = []
    @Published var blockedSongs: [BlockedSong] = []
    @Published var lastScanError: String?

    private let persistenceStore: LibraryPersistenceStore?
    private let supportedAudioFileExtensions = Set(["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "aif"])
    private let artworkFolderName = "Artwork"
    private var albumSongIDs: [AlbumSummary.ID: [Song.ID]] = [:]
    private var artistSongIDs: [ArtistSummary.ID: [Song.ID]] = [:]
    private var artistAlbumIDs: [ArtistSummary.ID: [AlbumSummary.ID]] = [:]
    private var songsByID: [Song.ID: Song] = [:]
    private var albumSummariesByID: [AlbumSummary.ID: AlbumSummary] = [:]
    private var indexBuildGeneration = 0

    init() {
        do {
            persistenceStore = try LibraryPersistenceStore()
        } catch {
            persistenceStore = nil
            lastScanError = error.localizedDescription
        }

        loadLibraryState()
        rebuildAlbumsAndArtists()
    }

    // 导入音乐文件
    func importMusic(from urls: [URL]) {
        var importedSongs: [Song] = []

        for url in urls {
            if isDirectory(url) {
                importedSongs.append(contentsOf: scanDirectoryForMusic(at: url, sourceId: nil))
            } else if isSupportedMusicFile(url), let song = createSong(from: url) {
                importedSongs.append(song)
            }
        }

        mergeSongs(importedSongs)
    }

    // 添加资料库
    func addLibrarySource(name: String, path: String) {
        guard !librarySources.contains(where: { standardizedPath($0.path) == standardizedPath(path) }) else {
            return
        }

        let source = MusicLibrarySource(name: name, path: path)
        librarySources.append(source)
        saveLibraryState()

        // 自动扫描新添加的资料库
        scanLibrarySource(source)
    }

    // 删除资料库
    func removeLibrarySource(id: UUID) {
        if let index = librarySources.firstIndex(where: { $0.id == id }) {
            let source = librarySources[index]
            librarySources.remove(at: index)
            songs.removeAll { isPath($0.path, inside: source.path) }
            blockedSongs.removeAll { $0.sourceId == source.id }
            playlists = playlists.map { playlist in
                var updatedPlaylist = playlist
                updatedPlaylist.songs.removeAll { isPath($0.path, inside: source.path) }
                let remainingIDs = Set(updatedPlaylist.songs.map(\.id))
                updatedPlaylist.songEntries.removeAll { !remainingIDs.contains($0.songId) }
                updatedPlaylist.songEntries = normalizedPlaylistEntries(updatedPlaylist.songEntries)
                updatedPlaylist.updatedAt = Date()
                return updatedPlaylist
            }
            rebuildAlbumsAndArtists()
            saveLibraryState()
        }
    }

    // 重新扫描所有资料库
    func rescanAllLibraries() {
        songs.removeAll()
        rebuildAlbumsAndArtists()
        saveLibraryState()

        for source in librarySources {
            scanLibrarySource(source)
        }
    }

    // 扫描单个资料库
    func scanLibrarySource(_ source: MusicLibrarySource) {
        // 更新扫描状态
        if let index = librarySources.firstIndex(where: { $0.id == source.id }) {
            var updatedSource = source
            updatedSource.isScanning = true
            librarySources[index] = updatedSource
        }

        DispatchQueue.global(qos: .background).async {
            let scannedSongs = self.scanDirectoryForMusic(at: URL(fileURLWithPath: source.path), sourceId: source.id)

            DispatchQueue.main.async {
                let existingSourceSongs = self.songs.filter { self.isSong($0, from: source) }
                self.songs.removeAll { self.isPath($0.path, inside: source.path) }
                self.mergeSongs(scannedSongs, existingSongs: existingSourceSongs, shouldSave: false)

                // 更新扫描状态
                if let index = self.librarySources.firstIndex(where: { $0.id == source.id }) {
                    var updatedSource = source
                    updatedSource.isScanning = false
                    updatedSource.lastScanned = Date()
                    self.librarySources[index] = updatedSource
                }

                self.saveLibraryState()
            }
        }
    }

    // 扫描目录中的音乐文件
    private func scanDirectoryForMusic(at directory: URL, sourceId: UUID?) -> [Song] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var scannedSongs: [Song] = []
        for case let fileURL as URL in enumerator {
            guard isSupportedMusicFile(fileURL), let song = createSong(from: fileURL, librarySourceId: sourceId) else {
                continue
            }

            if !isBlocked(path: song.path, sourceId: sourceId) {
                scannedSongs.append(song)
            }
        }
        return scannedSongs
    }

    // 从URL创建歌曲对象
    private func createSong(from url: URL, librarySourceId: UUID? = nil) -> Song? {
        guard isSupportedMusicFile(url) else { return nil }

        let fileName = url.lastPathComponent
        var title = fileName.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var duration: TimeInterval = 0
        var coverPath: String?
        var genre: String?
        var year: Int?

        // 使用AVAudioFile获取时长
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = audioFile.length
            duration = Double(frameCount) / sampleRate
        } catch {
            print("Error getting audio duration: \(error)")
        }

        let metadata = metadataItems(for: AVURLAsset(url: url))
        title = stringMetadata(for: [.commonIdentifierTitle], in: metadata) ?? title
        artist = stringMetadata(for: [.commonIdentifierArtist, .iTunesMetadataArtist, .id3MetadataLeadPerformer], in: metadata) ?? artist
        album = stringMetadata(for: [.commonIdentifierAlbumName, .iTunesMetadataAlbum, .id3MetadataAlbumTitle], in: metadata) ?? album
        genre = stringMetadata(for: [.quickTimeMetadataGenre, .iTunesMetadataUserGenre, .id3MetadataContentType], in: metadata)
        year = yearMetadata(in: metadata)
        coverPath = artworkPath(for: url, metadata: metadata)

        // 没有元数据时，使用常见的 Artist/Album/Track 文件夹结构来兜底。
        let albumFolder = url.deletingLastPathComponent()
        let artistFolder = albumFolder.deletingLastPathComponent()
        if album == "Unknown Album", !albumFolder.lastPathComponent.isEmpty {
            album = albumFolder.lastPathComponent
        }
        if artist == "Unknown Artist", artistFolder.path != albumFolder.path, !artistFolder.lastPathComponent.isEmpty {
            artist = artistFolder.lastPathComponent
        }

        return Song(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            path: url.path,
            coverPath: coverPath,
            genre: genre,
            year: year,
            librarySourceId: librarySourceId
        )
    }

    private func mergeSongs(_ newSongs: [Song], existingSongs: [Song]? = nil, shouldSave: Bool = true) {
        guard !newSongs.isEmpty else { return }

        let songsForMerge = existingSongs ?? songs
        var existingSongsByPath = Dictionary(uniqueKeysWithValues: songsForMerge.map { (standardizedPath($0.path), $0) })
        var songsByPath = Dictionary(uniqueKeysWithValues: songs.map { (standardizedPath($0.path), $0) })
        for song in newSongs {
            let pathKey = standardizedPath(song.path)
            if let existingSong = existingSongsByPath[pathKey] ?? songsByPath[pathKey] {
                songsByPath[pathKey] = song.mergingPersistentFields(from: existingSong)
            } else {
                songsByPath[pathKey] = song
            }
            existingSongsByPath.removeValue(forKey: pathKey)
        }

        songs = Array(songsByPath.values).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        rebuildAlbumsAndArtists()

        if shouldSave {
            saveLibraryState()
        }
    }

    // 重建专辑和艺术家索引
    private func rebuildAlbumsAndArtists() {
        let songsSnapshot = songs
        indexBuildGeneration += 1
        let generation = indexBuildGeneration

        DispatchQueue.global(qos: .userInitiated).async {
            let indexes = Self.buildLibraryIndexes(from: songsSnapshot)

            DispatchQueue.main.async {
                guard generation == self.indexBuildGeneration else { return }
                self.albumSummaries = indexes.albumSummaries
                self.artistSummaries = indexes.artistSummaries
                self.albumSongIDs = indexes.albumSongIDs
                self.artistSongIDs = indexes.artistSongIDs
                self.artistAlbumIDs = indexes.artistAlbumIDs
                self.songsByID = Dictionary(uniqueKeysWithValues: songsSnapshot.map { ($0.id, $0) })
                self.albumSummariesByID = Dictionary(uniqueKeysWithValues: indexes.albumSummaries.map { ($0.id, $0) })
            }
        }
    }

    // 根据ID查找歌曲
    func song(withId id: UUID) -> Song? {
        songsByID[id] ?? songs.first { $0.id == id }
    }

    func songs(matchingIDs ids: [Song.ID], paths: [String]) -> [Song] {
        var result: [Song] = []
        var addedIDs = Set<Song.ID>()

        for id in ids {
            guard let song = song(withId: id), addedIDs.insert(song.id).inserted else {
                continue
            }
            result.append(song)
        }

        guard !paths.isEmpty else { return result }

        let normalizedPaths = Set(paths.map(standardizedPath))
        for song in songs where normalizedPaths.contains(standardizedPath(song.path)) && addedIDs.insert(song.id).inserted {
            result.append(song)
        }

        return result
    }

    func songs(forAlbum album: AlbumSummary) -> [Song] {
        songs(from: albumSongIDs[album.id] ?? [])
    }

    func songs(forArtist artist: ArtistSummary) -> [Song] {
        songs(from: artistSongIDs[artist.id] ?? [])
    }

    func albums(forArtist artist: ArtistSummary) -> [AlbumSummary] {
        (artistAlbumIDs[artist.id] ?? [])
            .compactMap { albumSummariesByID[$0] }
            .sorted(by: albumSummarySort)
    }

    // 指定资料库中的歌曲
    func songs(in source: MusicLibrarySource) -> [Song] {
        songs.filter { isSong($0, from: source) }
    }

    func blockedSongs(in source: MusicLibrarySource) -> [BlockedSong] {
        blockedSongs
            .filter { $0.sourceId == source.id }
            .sorted { $0.blockedAt > $1.blockedAt }
    }

    var favoriteSongs: [Song] {
        songs.filter(\.isFavorite)
    }

    private func songs(from ids: [Song.ID]) -> [Song] {
        ids.compactMap { songsByID[$0] ?? song(withId: $0) }
    }

    // 记录一次达到有效播放阈值的播放统计。
    func recordQualifiedPlayback(for songId: Song.ID) {
        incrementPlaybackStats(for: songId)
    }

    // 删除歌曲
    func deleteSongs(withIds ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        removeSongsFromVisibleLibrary(withIds: ids)
    }

    private func removeSongsFromVisibleLibrary(withIds ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        songs.removeAll { ids.contains($0.id) }
        playlists = playlists.map { playlist in
            var updatedPlaylist = playlist
            updatedPlaylist.songs.removeAll { ids.contains($0.id) }
            updatedPlaylist.songEntries.removeAll { ids.contains($0.songId) }
            updatedPlaylist.songEntries = normalizedPlaylistEntries(updatedPlaylist.songEntries)
            updatedPlaylist.updatedAt = Date()
            return updatedPlaylist
        }
        rebuildAlbumsAndArtists()
        saveLibraryState()
    }

    func toggleFavorite(for songId: Song.ID) {
        guard let song = song(withId: songId) else { return }
        setFavorite(!song.isFavorite, for: songId)
    }

    func setFavorite(_ isFavorite: Bool, for songId: Song.ID) {
        guard let index = songs.firstIndex(where: { $0.id == songId }) else { return }
        let updatedSong = songs[index].settingFavorite(isFavorite)
        songs[index] = updatedSong
        syncSongCopies(updatedSong)
        rebuildAlbumsAndArtists()
        saveLibraryState()
    }

    // 屏蔽歌曲：只从 Mint Player 资料库隐藏，不删除本地文件。
    func blockSongs(withIds ids: Set<UUID>) {
        let songsToBlock = songs.filter { ids.contains($0.id) }
        guard !songsToBlock.isEmpty else { return }

        var existingKeys = Set(blockedSongs.map { blockedKey(path: $0.path, sourceId: $0.sourceId) })
        for song in songsToBlock {
            guard let sourceId = song.librarySourceId ?? source(containing: song.path)?.id else { continue }
            let key = blockedKey(path: song.path, sourceId: sourceId)
            guard existingKeys.insert(key).inserted else { continue }
            blockedSongs.append(
                BlockedSong(
                    sourceId: sourceId,
                    path: song.path,
                    title: song.title,
                    artist: song.artist,
                    album: song.album
                )
            )
        }

        removeSongsFromVisibleLibrary(withIds: ids)
    }

    func unblockSong(_ blockedSong: BlockedSong) {
        blockedSongs.removeAll { $0.id == blockedSong.id }
        saveLibraryState()

        if let source = librarySources.first(where: { $0.id == blockedSong.sourceId }) {
            scanLibrarySource(source)
        }
    }

    // 创建新播放列表
    func createPlaylist(name: String, description: String = "") {
        let playlist = Playlist(
            name: name,
            description: description,
            songs: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        playlists.append(playlist)
        saveLibraryState()
    }

    // 更新播放列表信息
    func updatePlaylist(id: UUID, name: String, description: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = name
        playlists[index].description = description
        playlists[index].updatedAt = Date()
        saveLibraryState()
    }

    // 删除播放列表
    func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        saveLibraryState()
    }

    // 调整播放列表顺序
    func movePlaylists(from source: IndexSet, to destination: Int) {
        reorder(&playlists, from: source, to: destination)
        saveLibraryState()
    }

    // 添加歌曲到播放列表
    func addSongToPlaylist(song: Song, playlistId: UUID) {
        addSongsToPlaylist([song], playlistId: playlistId)
    }

    // 批量添加歌曲到播放列表
    func addSongsToPlaylist(_ songsToAdd: [Song], playlistId: UUID) {
        guard !songsToAdd.isEmpty, let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            return
        }

        var playlist = playlists[index]
        var existingIDs = Set(playlist.songs.map(\.id))
        var didAddSongs = false

        for song in songsToAdd where existingIDs.insert(song.id).inserted {
            playlist.songs.append(song)
            playlist.songEntries.append(
                PlaylistSong(
                    songId: song.id,
                    addedAt: Date(),
                    sortOrder: playlist.songEntries.count
                )
            )
            didAddSongs = true
        }

        guard didAddSongs else { return }

        playlist.updatedAt = Date()
        playlists[index] = playlist
        saveLibraryState()
    }

    // 从播放列表移除歌曲
    func removeSongFromPlaylist(songId: UUID, playlistId: UUID) {
        removeSongsFromPlaylist(songIds: [songId], playlistId: playlistId)
    }

    // 从播放列表批量移除歌曲
    func removeSongsFromPlaylist(songIds ids: Set<UUID>, playlistId: UUID) {
        guard !ids.isEmpty, let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            return
        }

        var playlist = playlists[index]
        let originalCount = playlist.songs.count
        playlist.songs.removeAll { ids.contains($0.id) }
        playlist.songEntries.removeAll { ids.contains($0.songId) }
        playlist.songEntries = normalizedPlaylistEntries(playlist.songEntries)

        guard playlist.songs.count != originalCount else { return }

        playlist.updatedAt = Date()
        playlists[index] = playlist
        saveLibraryState()
    }

    private func incrementPlaybackStats(for songId: Song.ID) {
        guard let index = songs.firstIndex(where: { $0.id == songId }) else { return }
        let playedAt = Date()
        let updatedSong = songs[index].recordingPlayback(at: playedAt)
        songs[index] = updatedSong
        syncSongCopies(updatedSong)
        rebuildAlbumsAndArtists()

        do {
            try persistenceStore?.updatePlaybackStats(for: updatedSong)
        } catch {
            lastScanError = "无法保存播放统计：\(error.localizedDescription)"
        }
    }

    private func syncSongCopies(_ updatedSong: Song) {
        songsByID[updatedSong.id] = updatedSong

        for playlistIndex in playlists.indices {
            if let songIndex = playlists[playlistIndex].songs.firstIndex(where: { $0.id == updatedSong.id }) {
                playlists[playlistIndex].songs[songIndex] = updatedSong
            }
        }
    }

    private func normalizedPlaylistEntries(_ entries: [PlaylistSong]) -> [PlaylistSong] {
        entries.enumerated().map { index, entry in
            var updatedEntry = entry
            updatedEntry.sortOrder = index
            return updatedEntry
        }
    }

    private func loadLibraryState() {
        do {
            guard let persistenceStore else { return }
            let snapshot = try persistenceStore.loadSnapshot()
            songs = snapshot.songs
            playlists = snapshot.playlists
            blockedSongs = snapshot.blockedSongs
            librarySources = snapshot.librarySources.map {
                MusicLibrarySource(id: $0.id, name: $0.name, path: $0.path, isScanning: false, lastScanned: $0.lastScanned)
            }
        } catch {
            lastScanError = "无法加载音乐库状态：\(error.localizedDescription)"
        }
    }

    private func saveLibraryState() {
        let snapshot = LibraryPersistentSnapshot(
            songs: songs,
            playlists: playlists,
            librarySources: librarySources.map {
                MusicLibrarySource(id: $0.id, name: $0.name, path: $0.path, isScanning: false, lastScanned: $0.lastScanned)
            },
            blockedSongs: blockedSongs
        )

        do {
            try persistenceStore?.saveSnapshot(snapshot)
        } catch {
            lastScanError = "无法保存音乐库状态：\(error.localizedDescription)"
        }
    }

    private func reorder<T>(_ values: inout [T], from source: IndexSet, to destination: Int) {
        let sourceIndexes = source.sorted()
        let movingValues = sourceIndexes.map { values[$0] }

        for index in sourceIndexes.reversed() {
            values.remove(at: index)
        }

        let adjustedDestination = destination - sourceIndexes.filter { $0 < destination }.count
        values.insert(contentsOf: movingValues, at: min(max(adjustedDestination, 0), values.count))
    }

    private struct LibraryIndexes {
        let albumSummaries: [AlbumSummary]
        let artistSummaries: [ArtistSummary]
        let albumSongIDs: [AlbumSummary.ID: [Song.ID]]
        let artistSongIDs: [ArtistSummary.ID: [Song.ID]]
        let artistAlbumIDs: [ArtistSummary.ID: [AlbumSummary.ID]]
    }

    private struct AlbumIndexDraft {
        let id: AlbumSummary.ID
        var title: String
        var artist: String
        var coverPath: String
        var year: Int
        var songIDs: [Song.ID]
    }

    private struct ArtistIndexDraft {
        let id: ArtistSummary.ID
        var name: String
        var coverPath: String?
        var songIDs: [Song.ID]
        var albumIDs: [AlbumSummary.ID]
        var albumIDSet: Set<AlbumSummary.ID>
    }

    private static func buildLibraryIndexes(from songs: [Song]) -> LibraryIndexes {
        var albumDrafts: [AlbumSummary.ID: AlbumIndexDraft] = [:]
        var artistDrafts: [ArtistSummary.ID: ArtistIndexDraft] = [:]

        for song in songs {
            let albumID = albumSummaryID(title: song.album, artist: song.artist)
            let artistNames = indexedArtistNames(from: song.artist)

            if var albumDraft = albumDrafts[albumID] {
                albumDraft.songIDs.append(song.id)
                if albumDraft.coverPath.isEmpty, let coverPath = song.coverPath {
                    albumDraft.coverPath = coverPath
                }
                if albumDraft.year == 0, let year = song.year {
                    albumDraft.year = year
                }
                albumDrafts[albumID] = albumDraft
            } else {
                albumDrafts[albumID] = AlbumIndexDraft(
                    id: albumID,
                    title: song.album,
                    artist: song.artist,
                    coverPath: song.coverPath ?? "",
                    year: song.year ?? 0,
                    songIDs: [song.id]
                )
            }

            for artistName in artistNames {
                let artistID = artistSummaryID(name: artistName)
                if var artistDraft = artistDrafts[artistID] {
                    if !artistDraft.songIDs.contains(song.id) {
                        artistDraft.songIDs.append(song.id)
                    }
                    if artistDraft.coverPath == nil {
                        artistDraft.coverPath = song.coverPath
                    }
                    if !artistDraft.albumIDSet.contains(albumID) {
                        artistDraft.albumIDs.append(albumID)
                        artistDraft.albumIDSet.insert(albumID)
                    }
                    artistDrafts[artistID] = artistDraft
                } else {
                    artistDrafts[artistID] = ArtistIndexDraft(
                        id: artistID,
                        name: artistName,
                        coverPath: song.coverPath,
                        songIDs: [song.id],
                        albumIDs: [albumID],
                        albumIDSet: [albumID]
                    )
                }
            }
        }

        let albumSummaries = albumDrafts.values
            .map {
                AlbumSummary(
                    id: $0.id,
                    title: $0.title,
                    artist: $0.artist,
                    coverPath: $0.coverPath,
                    year: $0.year,
                    songCount: $0.songIDs.count
                )
            }
            .sorted(by: albumSummarySort)

        let artistSummaries = artistDrafts.values
            .map {
                ArtistSummary(
                    id: $0.id,
                    name: $0.name,
                    coverPath: $0.coverPath,
                    albumCount: $0.albumIDs.count,
                    songCount: $0.songIDs.count
                )
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return LibraryIndexes(
            albumSummaries: albumSummaries,
            artistSummaries: artistSummaries,
            albumSongIDs: Dictionary(uniqueKeysWithValues: albumDrafts.values.map { ($0.id, $0.songIDs) }),
            artistSongIDs: Dictionary(uniqueKeysWithValues: artistDrafts.values.map { ($0.id, $0.songIDs) }),
            artistAlbumIDs: Dictionary(uniqueKeysWithValues: artistDrafts.values.map { ($0.id, $0.albumIDs) })
        )
    }

    private static func albumSummarySort(_ lhs: AlbumSummary, _ rhs: AlbumSummary) -> Bool {
        if lhs.title == rhs.title {
            return lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) == .orderedAscending
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func albumSummarySort(_ lhs: AlbumSummary, _ rhs: AlbumSummary) -> Bool {
        Self.albumSummarySort(lhs, rhs)
    }

    private static func albumSummaryID(title: String, artist: String) -> String {
        "\(normalizedIndexKey(artist))\u{1F}\(normalizedIndexKey(title))"
    }

    private static func artistSummaryID(name: String) -> String {
        normalizedIndexKey(name)
    }

    private static func indexedArtistNames(from artist: String) -> [String] {
        let names = artist
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if names.isEmpty {
            let fallback = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? [artist] : [fallback]
        }

        var seenNames = Set<String>()
        return names.filter { seenNames.insert(normalizedIndexKey($0)).inserted }
    }

    private static func normalizedIndexKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func isSupportedMusicFile(_ url: URL) -> Bool {
        supportedAudioFileExtensions.contains(url.pathExtension.lowercased())
    }

    private func stringMetadata(for identifiers: [AVMetadataIdentifier], in metadata: [AVMetadataItem]) -> String? {
        for identifier in identifiers {
            if let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first,
               let value = loadOptionalMetadataValue({ try await item.load(.stringValue) }),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        return nil
    }

    private func yearMetadata(in metadata: [AVMetadataItem]) -> Int? {
        let identifiers: [AVMetadataIdentifier] = [
            .commonIdentifierCreationDate,
            .iTunesMetadataReleaseDate,
            .id3MetadataYear
        ]

        guard let rawValue = stringMetadata(for: identifiers, in: metadata) else {
            return nil
        }

        let prefix = rawValue.prefix(4)
        return Int(prefix)
    }

    private func artworkPath(for url: URL, metadata: [AVMetadataItem]) -> String? {
        let artworkItems = metadata.filter { item in
            item.commonKey == .commonKeyArtwork ||
                item.identifier == .commonIdentifierArtwork ||
                item.identifier == .iTunesMetadataCoverArt ||
                item.identifier == .id3MetadataAttachedPicture
        }

        for item in artworkItems {
            if let data = loadOptionalMetadataValue({ try await item.load(.dataValue) }) ?? loadOptionalMetadataValue({ try await item.load(.value) }) as? Data {
                return saveArtwork(data, for: url)
            }
        }

        return nearbyArtworkPath(for: url)
    }

    private func saveArtwork(_ data: Data, for url: URL) -> String? {
        guard let directory = artworkDirectory() else { return nil }

        let fileName = "\(abs(url.path.hashValue)).jpg"
        let fileURL = directory.appendingPathComponent(fileName)

        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: .atomic)
            }
            return fileURL.path
        } catch {
            print("Error saving artwork: \(error)")
            return nil
        }
    }

    private func nearbyArtworkPath(for url: URL) -> String? {
        let directory = url.deletingLastPathComponent()
        let candidateNames = ["cover", "folder", "front", "artwork", "album"]
        let extensions = ["jpg", "jpeg", "png", "heic", "webp"]

        for name in candidateNames {
            for fileExtension in extensions {
                let candidate = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate.path
                }
            }
        }

        return nil
    }

    private func artworkDirectory() -> URL? {
        do {
            let directory = try AppConfiguration.applicationSupportDirectory()
                .appendingPathComponent(artworkFolderName, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            print("Error creating artwork directory: \(error)")
            return nil
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func isPath(_ childPath: String, inside parentPath: String) -> Bool {
        let child = standardizedPath(childPath)
        let parent = standardizedPath(parentPath)
        return child == parent || child.hasPrefix(parent + "/")
    }

    private func source(containing path: String) -> MusicLibrarySource? {
        librarySources.first { isPath(path, inside: $0.path) }
    }

    private func isSong(_ song: Song, from source: MusicLibrarySource) -> Bool {
        if song.librarySourceId == source.id {
            return true
        }
        return isPath(song.path, inside: source.path)
    }

    private func isBlocked(path: String, sourceId: UUID?) -> Bool {
        guard let sourceId else { return false }
        let key = blockedKey(path: path, sourceId: sourceId)
        return blockedSongs.contains { blockedKey(path: $0.path, sourceId: $0.sourceId) == key }
    }

    private func blockedKey(path: String, sourceId: UUID) -> String {
        "\(sourceId.uuidString)|\(standardizedPath(path))"
    }

    private func metadataItems(for asset: AVURLAsset) -> [AVMetadataItem] {
        let commonMetadata = loadMetadataValue { try await asset.load(.commonMetadata) } ?? []
        let metadata = loadMetadataValue { try await asset.load(.metadata) } ?? []
        return commonMetadata + metadata
    }

    private func loadMetadataValue<T>(_ operation: @escaping () async throws -> T) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var loadedValue: T?

        Task {
            loadedValue = try? await operation()
            semaphore.signal()
        }

        semaphore.wait()
        return loadedValue
    }

    private func loadOptionalMetadataValue<T>(_ operation: @escaping () async throws -> T?) -> T? {
        guard let loadedValue = loadMetadataValue(operation) else {
            return nil
        }
        return loadedValue
    }
}
