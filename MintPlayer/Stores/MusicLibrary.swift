import Foundation
import AVFoundation

class MusicLibrary: ObservableObject {
    private struct LibrarySnapshot: Codable {
        var songs: [Song]
        var playlists: [Playlist]
        var recentlyPlayed: [PlayHistory]
        var librarySources: [MusicLibrarySource]
    }
    
    @Published var songs: [Song] = []
    @Published private(set) var albumSummaries: [AlbumSummary] = []
    @Published private(set) var artistSummaries: [ArtistSummary] = []
    @Published var playlists: [Playlist] = []
    @Published var recentlyPlayed: [PlayHistory] = []
    @Published var librarySources: [MusicLibrarySource] = []
    @Published var lastScanError: String?
    
    private let libraryStateKey = "mintPlayer.libraryState"
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
    
    // 导入音乐文件
    func importMusic(from urls: [URL]) {
        var importedSongs: [Song] = []
        
        for url in urls {
            if isDirectory(url) {
                importedSongs.append(contentsOf: scanDirectoryForMusic(at: url))
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
            playlists = playlists.map { playlist in
                var updatedPlaylist = playlist
                updatedPlaylist.songs.removeAll { isPath($0.path, inside: source.path) }
                updatedPlaylist.updatedAt = Date()
                return updatedPlaylist
            }
            recentlyPlayed.removeAll { history in
                guard let song = song(withId: history.songId) else { return true }
                return isPath(song.path, inside: source.path)
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
            let scannedSongs = self.scanDirectoryForMusic(at: URL(fileURLWithPath: source.path))
            
            DispatchQueue.main.async {
                self.songs.removeAll { self.isPath($0.path, inside: source.path) }
                self.mergeSongs(scannedSongs, shouldSave: false)
                
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
    private func scanDirectoryForMusic(at directory: URL) -> [Song] {
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
            guard isSupportedMusicFile(fileURL), let song = createSong(from: fileURL) else {
                continue
            }
            
            scannedSongs.append(song)
        }
        return scannedSongs
    }
    
    // 从URL创建歌曲对象
    private func createSong(from url: URL) -> Song? {
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
            year: year
        )
    }
    
    private func mergeSongs(_ newSongs: [Song], shouldSave: Bool = true) {
        guard !newSongs.isEmpty else { return }
        
        var songsByPath = Dictionary(uniqueKeysWithValues: songs.map { (standardizedPath($0.path), $0) })
        for song in newSongs {
            songsByPath[standardizedPath(song.path)] = song
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
        songs.filter { isPath($0.path, inside: source.path) }
    }

    private func songs(from ids: [Song.ID]) -> [Song] {
        ids.compactMap { songsByID[$0] ?? song(withId: $0) }
    }
    
    // 添加歌曲到播放历史
    func addToRecentlyPlayed(song: Song) {
        recentlyPlayed.removeAll { $0.songId == song.id }
        let history = PlayHistory(songId: song.id, playedAt: Date())
        recentlyPlayed.insert(history, at: 0)
        // 限制最近播放记录数量
        if recentlyPlayed.count > 50 {
            recentlyPlayed.removeLast(recentlyPlayed.count - 50)
        }
        saveLibraryState()
    }
    
    // 删除最近播放记录
    func deleteRecentHistory(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where recentlyPlayed.indices.contains(index) {
            recentlyPlayed.remove(at: index)
        }
        saveLibraryState()
    }
    
    // 删除歌曲
    func deleteSongs(withIds ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        
        songs.removeAll { ids.contains($0.id) }
        recentlyPlayed.removeAll { ids.contains($0.songId) }
        playlists = playlists.map { playlist in
            var updatedPlaylist = playlist
            updatedPlaylist.songs.removeAll { ids.contains($0.id) }
            updatedPlaylist.updatedAt = Date()
            return updatedPlaylist
        }
        rebuildAlbumsAndArtists()
        saveLibraryState()
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
            didAddSongs = true
        }
        
        guard didAddSongs else { return }
        
        playlist.updatedAt = Date()
        playlists[index] = playlist
        saveLibraryState()
    }
    
    // 从播放列表移除歌曲
    func removeSongFromPlaylist(songId: UUID, playlistId: UUID) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var playlist = playlists[index]
            playlist.songs.removeAll { $0.id == songId }
            playlist.updatedAt = Date()
            playlists[index] = playlist
            saveLibraryState()
        }
    }
    
    private func loadLibraryState() {
        guard let data = UserDefaults.standard.data(forKey: libraryStateKey) else {
            return
        }
        
        do {
            let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
            songs = snapshot.songs
            playlists = snapshot.playlists
            recentlyPlayed = snapshot.recentlyPlayed
            librarySources = snapshot.librarySources.map {
                MusicLibrarySource(id: $0.id, name: $0.name, path: $0.path, isScanning: false, lastScanned: $0.lastScanned)
            }
        } catch {
            lastScanError = "无法加载音乐库状态：\(error.localizedDescription)"
        }
    }
    
    private func saveLibraryState() {
        let snapshot = LibrarySnapshot(
            songs: songs,
            playlists: playlists,
            recentlyPlayed: recentlyPlayed,
            librarySources: librarySources.map {
                MusicLibrarySource(id: $0.id, name: $0.name, path: $0.path, isScanning: false, lastScanned: $0.lastScanned)
            }
        )
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: libraryStateKey)
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
            let artistID = artistSummaryID(name: song.artist)
            
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
            
            if var artistDraft = artistDrafts[artistID] {
                artistDraft.songIDs.append(song.id)
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
                    name: song.artist,
                    coverPath: song.coverPath,
                    songIDs: [song.id],
                    albumIDs: [albumID],
                    albumIDSet: [albumID]
                )
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
            let baseURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = baseURL.appendingPathComponent("MintPlayer", isDirectory: true)
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
