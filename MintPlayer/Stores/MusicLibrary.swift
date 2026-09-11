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
    @Published private(set) var scanProgress: [UUID: Int] = [:]
    @Published private(set) var sourceErrors: [UUID: String] = [:]
    @Published private(set) var pendingImports = 0
    @Published private(set) var importedFileCount = 0
    private let scanQueue = DispatchQueue(label: "MintPlayer.libraryScan", qos: .userInitiated)
    private var scanTokens: [UUID: UUID] = [:]
    private var failedImportURLs: [URL] = []
    private var lastImportError: String?

    private var persistenceStore: LibraryPersistenceStore?
    private var hasLoadedLibraryState = false
    private let supportedAudioFileExtensions = Set(["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "aif"])
    private let artworkFolderName = "Artwork"
    private var albumSongIDs: [AlbumSummary.ID: [Song.ID]] = [:]
    private var artistSongIDs: [ArtistSummary.ID: [Song.ID]] = [:]
    private var artistAlbumIDs: [ArtistSummary.ID: [AlbumSummary.ID]] = [:]
    private var songsByID: [Song.ID: Song] = [:]
    private var albumSummariesByID: [AlbumSummary.ID: AlbumSummary] = [:]
    private var indexBuildGeneration = 0

    init() {
        loadLibraryState()
        rebuildAlbumsAndArtists()
    }

    var isScanning: Bool { pendingImports > 0 || librarySources.contains(where: \.isScanning) }

    func retryFailedOperations() {
        lastScanError = nil
        if !hasLoadedLibraryState {
            loadLibraryState()
            rebuildAlbumsAndArtists()
            return
        }
        for source in librarySources where sourceErrors[source.id] != nil {
            scanLibrarySource(source)
        }
        let urls = failedImportURLs
        failedImportURLs = []
        if !urls.isEmpty { importMusic(from: urls) }
        saveLibraryState()
    }

    private func requireLoadedLibrary() -> Bool {
        guard hasLoadedLibraryState else {
            if lastScanError == nil { lastScanError = L10n.current(.databaseUnavailable) }
            return false
        }
        return true
    }

    // Metadata extraction is serialized off the main thread; only completed results mutate library state.
    func importMusic(from urls: [URL]) {
        guard requireLoadedLibrary() else { return }
        guard !urls.isEmpty else { return }
        if pendingImports == 0 { importedFileCount = 0 }
        pendingImports += 1
        let sourceSnapshot = librarySources
        scanQueue.async {
            var importedSongs: [Song] = []
            var failures: [URL: String] = [:]
            var processed = 0
            let progress: (Int) -> Void = { count in
                let delta = count - processed
                processed = count
                DispatchQueue.main.async { self.importedFileCount += delta }
            }
            for url in urls {
                do {
                    if self.isDirectory(url) {
                        let baseCount = processed
                        let result = try self.scanDirectoryForMusic(at: url, sourceId: nil) { progress(baseCount + $0) }
                        importedSongs += result.songs
                        failures.merge(result.failures) { _, new in new }
                    } else if self.isSupportedMusicFile(url) {
                        defer { progress(processed + 1) }
                        if let song = try self.createSong(from: url) { importedSongs.append(song) }
                    } else {
                        failures[url] = L10n.current(.unsupportedAudio)
                    }
                } catch {
                    failures[url] = error.localizedDescription
                }
            }
            let completedSongs = importedSongs
            let completedFailures = failures
            DispatchQueue.main.async {
                // Ignore results owned by a folder removed while this import was running.
                let removedSources = sourceSnapshot.filter { old in !self.librarySources.contains { $0.id == old.id } }
                let visibleSongs = completedSongs.compactMap { song -> Song? in
                    guard !removedSources.contains(where: { self.isPath(song.path, inside: $0.path) }) else { return nil }
                    let source = self.source(containing: song.path)
                    guard !self.isBlocked(path: song.path, sourceId: source?.id) else { return nil }
                    return song.assigningLibrarySource(source?.id)
                }
                self.mergeSongs(visibleSongs)
                self.pendingImports -= 1
                let succeededURLs = Set(urls).subtracting(completedFailures.keys)
                self.failedImportURLs.removeAll { succeededURLs.contains($0) }
                if !completedFailures.isEmpty {
                    self.failedImportURLs = Array(Set(self.failedImportURLs + Array(completedFailures.keys)))
                    let message = Self.failureSummary(completedFailures)
                    self.lastImportError = message
                    self.lastScanError = message
                } else if self.failedImportURLs.isEmpty {
                    if self.lastScanError == self.lastImportError { self.lastScanError = nil }
                    self.lastImportError = nil
                }
            }
        }
    }

    // 添加资料库
    func addLibrarySource(name: String, path: String) {
        guard requireLoadedLibrary() else { return }
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
            scanTokens[id] = nil
            scanProgress[id] = nil
            sourceErrors[id] = nil
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

    func rescanAllLibraries() {
        for source in librarySources { scanLibrarySource(source) }
    }

    func scanLibrarySource(_ source: MusicLibrarySource) {
        guard requireLoadedLibrary() else { return }
        guard let index = librarySources.firstIndex(where: { $0.id == source.id }),
              !librarySources[index].isScanning else { return }
        let token = UUID()
        scanTokens[source.id] = token
        librarySources[index].isScanning = true
        scanProgress[source.id] = 0
        if let previousError = sourceErrors[source.id], lastScanError == previousError { lastScanError = nil }
        sourceErrors[source.id] = nil

        scanQueue.async {
            let result = Result {
                try self.scanDirectoryForMusic(at: URL(fileURLWithPath: source.path), sourceId: source.id) { count in
                    DispatchQueue.main.async {
                        guard self.scanTokens[source.id] == token else { return }
                        self.scanProgress[source.id] = count
                    }
                }
            }
            DispatchQueue.main.async {
                guard self.scanTokens[source.id] == token,
                      let index = self.librarySources.firstIndex(where: { $0.id == source.id }) else { return }
                self.scanTokens[source.id] = nil
                self.librarySources[index].isScanning = false
                switch result {
                case .success(let scan):
                    let existingSongs = self.songs.filter { self.isSong($0, from: source) }
                    let failedPaths = Set(scan.failures.keys.map { self.standardizedPath($0.path) })
                    // Keep unreadable tracks and their user data; only a complete traversal can remove absent files.
                    self.songs.removeAll {
                        self.isSong($0, from: source) && !failedPaths.contains(self.standardizedPath($0.path))
                    }
                    let newSongs = scan.songs.compactMap { song -> Song? in
                        let owner = self.source(containing: song.path) ?? source
                        guard !self.isBlocked(path: song.path, sourceId: owner.id) else { return nil }
                        return song.assigningLibrarySource(owner.id)
                    }
                    if newSongs.isEmpty {
                        self.reconcilePlaylistSongs()
                        self.rebuildAlbumsAndArtists()
                    } else {
                        self.mergeSongs(newSongs, existingSongs: existingSongs, shouldSave: false)
                    }
                    self.librarySources[index].lastScanned = Date()
                    if !scan.failures.isEmpty {
                        let message = Self.failureSummary(scan.failures)
                        self.sourceErrors[source.id] = message
                        self.lastScanError = message
                    }
                    self.saveLibraryState()
                case .failure(let error):
                    let message = L10n.current(.folderScanFailed, source.name, error.localizedDescription)
                    self.sourceErrors[source.id] = message
                    self.lastScanError = message
                }
            }
        }
    }

    private struct ScanResult {
        var songs: [Song] = []
        var failures: [URL: String] = [:]
    }

    private func scanDirectoryForMusic(at directory: URL, sourceId: UUID?, progress: (Int) -> Void) throws -> ScanResult {
        let fileManager = FileManager.default
        guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true,
              fileManager.isReadableFile(atPath: directory.path) else {
            throw CocoaError(.fileReadNoPermission)
        }
        var traversalError: Error?
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, error in
                traversalError = error
                return false
            }
        ) else { throw CocoaError(.fileReadUnknown) }

        var result = ScanResult()
        var count = 0
        for case let fileURL as URL in enumerator {
            guard isSupportedMusicFile(fileURL) else { continue }
            do {
                guard try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
                if let song = try createSong(from: fileURL, librarySourceId: sourceId) { result.songs.append(song) }
            } catch {
                result.failures[fileURL] = error.localizedDescription
            }
            count += 1
            if count.isMultiple(of: 25) { progress(count) }
        }
        progress(count)
        if let traversalError { throw traversalError }
        return result
    }

    private static func failureSummary(_ failures: [URL: String]) -> String {
        let details = failures.sorted { $0.key.path < $1.key.path }.prefix(8)
            .map { "\($0.key.lastPathComponent): \($0.value)" }.joined(separator: "\n")
        return L10n.current(.scanFailureCount, failures.count) + "\n" + details
    }

    private func reconcilePlaylistSongs() {
        let songsByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        for index in playlists.indices {
            playlists[index].songs = playlists[index].songs.compactMap { songsByID[$0.id] }
            playlists[index].songEntries = normalizedPlaylistEntries(
                playlists[index].songEntries.filter { songsByID[$0.songId] != nil }
            )
        }
    }

    // 从URL创建歌曲对象
    private func createSong(from url: URL, librarySourceId: UUID? = nil) throws -> Song? {
        guard isSupportedMusicFile(url) else { return nil }

        let fileName = url.lastPathComponent
        var title = fileName.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var duration: TimeInterval = 0
        var coverPath: String?
        var genre: String?
        var year: Int?

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CocoaError(.fileReadNoPermission)
        }
        let audioFile = try AVAudioFile(forReading: url)
        let sampleRate = audioFile.processingFormat.sampleRate
        guard sampleRate > 0 else { throw CocoaError(.fileReadCorruptFile) }
        duration = Double(audioFile.length) / sampleRate

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
            librarySourceId: librarySourceId,
            trackNumber: numberMetadata(in: metadata, identifiers: [.iTunesMetadataTrackNumber, .id3MetadataTrackNumber], keys: ["TRCK", "TRACKNUMBER"]),
            discNumber: numberMetadata(in: metadata, identifiers: [.iTunesMetadataDiscNumber, .id3MetadataPartOfASet], keys: ["TPOS", "DISCNUMBER"]),
            albumArtist: stringMetadata(for: [.iTunesMetadataAlbumArtist, .id3MetadataBand], in: metadata)
                ?? stringMetadataValue(in: metadata, keys: ["TPE2", "ALBUMARTIST", "ALBUM ARTIST"])
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
        reconcilePlaylistSongs()
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
        // Detail views can refresh before the background summary index has finished rebuilding.
        songs.filter { Self.albumSummaryID(title: $0.album, artist: $0.effectiveAlbumArtist) == album.id }
            .sorted(by: Song.albumOrder)
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
        guard requireLoadedLibrary() else { return }
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
            guard hasLoadedLibraryState, let persistenceStore else { throw LibraryPersistenceStore.StoreError.missingDatabase }
            try persistenceStore.updatePlaybackStats(for: updatedSong)
        } catch {
            lastScanError = L10n.current(.saveStatsFailed, error.localizedDescription)
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
            if persistenceStore == nil { persistenceStore = try LibraryPersistenceStore() }
            guard let persistenceStore else { throw LibraryPersistenceStore.StoreError.missingDatabase }
            let snapshot = try persistenceStore.loadSnapshot()
            hasLoadedLibraryState = true
            songs = snapshot.songs
            playlists = snapshot.playlists
            blockedSongs = snapshot.blockedSongs
            librarySources = snapshot.librarySources.map {
                MusicLibrarySource(id: $0.id, name: $0.name, path: $0.path, isScanning: false, lastScanned: $0.lastScanned)
            }
        } catch {
            lastScanError = L10n.current(.loadLibraryFailed, error.localizedDescription)
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
            guard hasLoadedLibraryState, let persistenceStore else { throw LibraryPersistenceStore.StoreError.missingDatabase }
            try persistenceStore.saveSnapshot(snapshot)
        } catch {
            lastScanError = L10n.current(.saveLibraryFailed, error.localizedDescription)
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
            let albumID = albumSummaryID(title: song.album, artist: song.effectiveAlbumArtist)
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
                    artist: song.effectiveAlbumArtist,
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

    private func stringMetadataValue(in metadata: [AVMetadataItem], keys: [String]) -> String? {
        for item in metadata {
            guard let key = item.key as? String, keys.contains(key.uppercased()),
                  let value = loadOptionalMetadataValue({ try await item.load(.stringValue) }),
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            return value
        }
        return nil
    }

    private func numberMetadata(in metadata: [AVMetadataItem], identifiers: [AVMetadataIdentifier], keys: [String]) -> Int? {
        if let value = stringMetadata(for: identifiers, in: metadata) ?? stringMetadataValue(in: metadata, keys: keys),
           let number = Int(value.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? ""), number > 0 {
            return number
        }
        // iTunes stores track/disc indexes as a big-endian integer pair after two reserved bytes.
        for item in metadata where item.identifier == .iTunesMetadataTrackNumber || item.identifier == .iTunesMetadataDiscNumber {
            guard item.identifier.map({ identifiers.contains($0) }) == true else { continue }
            if let data = loadOptionalMetadataValue({ try await item.load(.dataValue) }), data.count >= 4 {
                let bytes = Array(data)
                let number = Int(bytes[2]) << 8 | Int(bytes[3])
                if number > 0 { return number }
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
        librarySources.filter { isPath(path, inside: $0.path) }.max { $0.path.count < $1.path.count }
    }

    private func isSong(_ song: Song, from source: MusicLibrarySource) -> Bool {
        if let sourceID = song.librarySourceId { return sourceID == source.id }
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
