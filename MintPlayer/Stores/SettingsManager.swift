import Foundation
#if !MCP_HELPER
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var theme: ThemeMode = .dark
    @Published var language: AppLanguage = .system
    @Published var lyricsPresentationMode: LyricsPresentationMode = .embedded
    @Published var lyricsBlurEnabled = true
    @Published private(set) var mcpEnabled = false
    @Published private(set) var mcpRequiresToken = true
    @Published private(set) var lyricsFilePaths: [String: String] = [:]
    @Published private(set) var lyricsTimingOffsets: [String: Double] = [:]
    @Published private(set) var lyricsEncodings: [String: String] = [:]
    private let lyricsFilesKey = AppConfiguration.userDefaultsKey("settings.lyrics.files")
    private let lyricsEncodingsKey = AppConfiguration.userDefaultsKey("settings.lyrics.encodings")
    private let lyricsOffsetsKey = AppConfiguration.userDefaultsKey("settings.lyrics.offsets")

    private let userDefaults = UserDefaults.standard
    private let themeKey = AppConfiguration.userDefaultsKey("settings.theme")
    private let languageKey = AppConfiguration.userDefaultsKey("settings.language")
    private let lyricsPresentationModeKey = AppConfiguration.userDefaultsKey("settings.lyrics.presentationMode")
    private let lyricsBlurEnabledKey = AppConfiguration.userDefaultsKey("settings.lyrics.blurEnabled")
    private let mcpRequiresTokenKey = AppConfiguration.userDefaultsKey("settings.mcp.requiresToken")

    init() {
        loadSettings()
    }

    // 加载设置
    private func loadSettings() {
        lyricsEncodings = userDefaults.dictionary(forKey: lyricsEncodingsKey) as? [String: String] ?? [:]
        lyricsFilePaths = userDefaults.dictionary(forKey: lyricsFilesKey) as? [String: String] ?? [:]
        lyricsTimingOffsets = userDefaults.dictionary(forKey: lyricsOffsetsKey) as? [String: Double] ?? [:]
        if let themeString = userDefaults.string(forKey: themeKey), let savedTheme = ThemeMode(rawValue: themeString) {
            theme = savedTheme
        }
        if let languageString = userDefaults.string(forKey: languageKey), let savedLanguage = AppLanguage(rawValue: languageString) {
            language = savedLanguage
        }
        if let modeString = userDefaults.string(forKey: lyricsPresentationModeKey),
           let savedMode = LyricsPresentationMode(rawValue: modeString) {
            lyricsPresentationMode = savedMode
        }
        if userDefaults.object(forKey: lyricsBlurEnabledKey) != nil {
            lyricsBlurEnabled = userDefaults.bool(forKey: lyricsBlurEnabledKey)
        }
        mcpEnabled = userDefaults.bool(forKey: AppConfiguration.mcpEnabledKey)
        if userDefaults.object(forKey: mcpRequiresTokenKey) != nil {
            mcpRequiresToken = userDefaults.bool(forKey: mcpRequiresTokenKey)
        }
    }

    // 保存设置
    func saveSettings() {
        userDefaults.set(theme.rawValue, forKey: themeKey)
        userDefaults.set(language.rawValue, forKey: languageKey)
        userDefaults.set(lyricsPresentationMode.rawValue, forKey: lyricsPresentationModeKey)
        userDefaults.set(lyricsBlurEnabled, forKey: lyricsBlurEnabledKey)
    }

    // 更新主题
    func updateTheme(_ newTheme: ThemeMode) {
        theme = newTheme
        saveSettings()
    }

    func updateLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage
        saveSettings()
    }

    func updateLyricsPresentationMode(_ newMode: LyricsPresentationMode) {
        lyricsPresentationMode = newMode
        saveSettings()
    }

    func updateLyricsBlurEnabled(_ isEnabled: Bool) {
        lyricsBlurEnabled = isEnabled
        saveSettings()
    }

    func updateMCPEnabled(_ enabled: Bool) {
        mcpEnabled = enabled
        userDefaults.set(enabled, forKey: AppConfiguration.mcpEnabledKey)
    }

    func updateMCPRequiresToken(_ requiresToken: Bool) {
        mcpRequiresToken = requiresToken
        userDefaults.set(requiresToken, forKey: mcpRequiresTokenKey)
    }

    func lyricsEncoding(for song: Song) -> LyricsTextEncoding {
        lyricsEncodings[song.path].flatMap(LyricsTextEncoding.init(rawValue:)) ?? .automatic
    }

    func updateLyricsEncoding(_ encoding: LyricsTextEncoding, for song: Song) {
        lyricsEncodings[song.path] = encoding == .automatic ? nil : encoding.rawValue
        userDefaults.set(lyricsEncodings, forKey: lyricsEncodingsKey)
    }

    func lyricsFileURL(for song: Song) -> URL? {
        lyricsFilePaths[song.path].map { URL(fileURLWithPath: $0) }
    }

    func updateLyricsFile(_ url: URL?, for song: Song) {
        lyricsFilePaths[song.path] = url?.path
        userDefaults.set(lyricsFilePaths, forKey: lyricsFilesKey)
    }

    func lyricsTimingOffset(for song: Song) -> TimeInterval {
        let value = lyricsTimingOffsets[song.path] ?? 0
        return value.isFinite ? min(max(value, -60), 60) : 0
    }

    func updateLyricsTimingOffset(_ offset: TimeInterval, for song: Song) {
        guard offset.isFinite else { return }
        lyricsTimingOffsets[song.path] = offset == 0 ? nil : min(max(offset, -60), 60)
        userDefaults.set(lyricsTimingOffsets, forKey: lyricsOffsetsKey)
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var effectiveLanguage: AppLanguage {
        language.resolved
    }

    func text(_ key: L10n.Key, _ arguments: CVarArg...) -> String {
        L10n.text(key, language: effectiveLanguage, arguments: arguments)
    }

    func songCount(_ count: Int) -> String {
        text(count == 1 ? .oneSong : .songCount, count)
    }

    func albumCount(_ count: Int) -> String {
        text(count == 1 ? .oneAlbum : .albumCount, count)
    }

    func artistName(_ name: String) -> String {
        name.isEmpty || name == Song.unknownArtistName ? text(.unknownArtist) : name
    }

    func albumName(_ name: String) -> String {
        name.isEmpty || name == Song.unknownAlbumName ? text(.unknownAlbum) : name
    }

    func songSubtitle(artist: String, album: String) -> String {
        "\(artistName(artist)) · \(albumName(album))"
    }

    var versionText: String {
        text(.version, AppConfiguration.displayVersion)
    }
}

enum LyricsPresentationMode: String, CaseIterable {
    case embedded
    case separateWindow
}

#endif

enum AppLanguage: String, CaseIterable {
    case system = "System"
    case english = "English"
    case chinese = "简体中文"

    var resolved: AppLanguage {
        switch self {
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferredLanguage.hasPrefix("zh") ? .chinese : .english
        case .english, .chinese:
            return self
        }
    }
}

enum L10n {
    enum Key: String {
        case back
        case englishLanguage
        case chineseLanguage
        case songCount
        case oneSong
        case albumCount
        case oneAlbum
        case playbackQueue
        case queueSummary
        case oneScanFailure
        case mcpRotateTokenHint
        case noMatchingArtistMusic
        case choose
        case lyricsEncoding
        case automaticEncoding
        case utf8Encoding
        case utf16Encoding
        case gb18030Encoding
        case big5Encoding

        case retry
        case scanningFiles
        case importingFiles
        case folderUnavailable
        case folderScanFailed
        case scanFailureCount
        case unsupportedAudio
        case saveStatsFailed
        case loadLibraryFailed
        case saveLibraryFailed
        case databaseOpenFailed
        case databaseOperationFailed
        case unsupportedDatabase
        case databaseUnavailable
        case unknownError
        case playbackFailed
        case audioFileMissing
        case audioFileUnreadable
        case audioDecodeFailed
        case undoClearQueue
        case playbackMenu
        case playPause
        case focusSearch
        case playbackPosition
        case positionValue
        case addMusicFolder
        case chooseLyricsFile
        case lyricsOptions
        case useMatchingLyrics
        case lyricsTiming
        case lyricsEarlier
        case lyricsLater
        case resetLyricsTiming
        case lyricsTimingValue
        case lyricsEncodingFailed
        case lyricsParsingFailed
        case selectedLyricsMissing
        case noAlbumsYet
        case lyricsLoading
        case lyricsReload
        case lyricsFileReadFailed
        case noFavoriteSongs
        case favoriteSongsHint
        case emptyPlaylist
        case emptyPlaylistHint
        case showDetails
        case mcpSection
        case mcpEnable
        case mcpDescription
        case mcpRequireToken
        case mcpRequireTokenDescription
        case mcpStatus
        case mcpOff
        case mcpStarting
        case mcpRunning
        case mcpFailed
        case mcpCopyCommand
        case mcpCopyToken
        case mcpRotateToken
        case mcpAuthenticationHint
        case mcpNoAuthenticationHint
        case mcpPlayerNotReady
        case mcpTokenInvalid
        case mcpDisabled
        case mcpUnauthorized
        case mcpLocalConnectionFailed
        case mcpHelperNotInstalled
        case mcpStdioStartError
        case mcpAppLaunchError
        case mcpRequestTooLarge
        case mcpUnexpectedArguments
        case mcpInvalidUUID
        case mcpInvalidPage
        case mcpInvalidPlaylistName
        case mcpInvalidPlaylistDescription
        case mcpInvalidSongIDs
        case mcpSongNotFound
        case mcpSongNotInPlaylist
        case mcpBlockedSongNotFound
        case mcpSongSourceUnavailable
        case mcpLibrarySaveFailed

        case general
        case appearance
        case interfaceTheme
        case theme
        case language
        case themeDescription
        case languageDescription
        case playbackPage
        case lyrics
        case lyricsPresentation
        case lyricsPresentationDescription
        case embeddedLyrics
        case separateLyricsWindow
        case lyricsBlur
        case lyricsBlurEffect
        case lyricsBlurDescription
        case library
        case musicLibrary
        case addMusicLibrary
        case rescanAll
        case libraryDescription
        case folders
        case noMusicLibraries
        case addFolderDescription
        case lastScanned
        case rescan
        case remove
        case blockedSongs
        case unblock
        case unblockSong
        case about
        case version
        case add
        case cancel
        case enterLibraryName
        case home
        case startListening
        case resumePlayback
        case resumeFromTime
        case quickPlay
        case favoriteWidgetSubtitle
        case shuffleWidgetSubtitle
        case lyricsWidgetIdle
        case showFullScreenLyrics
        case playFavoriteSongs
        case shuffleLibrary
        case browseAlbums
        case recentlyPlayed
        case noRecentlyPlayed
        case showMore
        case songs
        case albums
        case artists
        case favorites
        case playlists
        case foldersSection
        case noPlaylists
        case noFolders
        case newPlaylist
        case editPlaylist
        case deletePlaylist
        case deleteFolder
        case deletePlaylistQuestion
        case deleteFolderQuestion
        case deletePlaylistMessage
        case deleteFolderMessage
        case settings
        case playlistNotFound
        case folderNotFound
        case noSongsYet
        case noMatchingSongs
        case importPrompt
        case searchSongs
        case searchAlbums
        case searchInAlbum
        case searchArtists
        case searchInArtist
        case noMatchingAlbums
        case noArtistsYet
        case noMatchingArtists
        case play
        case pause
        case shuffle
        case notPlaying
        case nowPlaying
        case chooseSong
        case upNext
        case volume
        case showLyrics
        case addToFavorites
        case removeFromFavorites
        case queueEmpty
        case removeFromQueue
        case clearQueue
        case closeUpNext
        case history
        case sortSongs
        case ascending
        case descending
        case title
        case titleDescending
        case artist
        case artistDescending
        case album
        case albumDescending
        case duration
        case durationDescending
        case playCount
        case playCountAscending
        case dateAdded
        case dateAddedAscending
        case columns
        case columnSong
        case columnTrackNumber
        case columnArtist
        case columnDuration
        case columnPlayCount
        case columnDateAdded
        case columnFavorite
        case columnTitle
        case columnAlbum
        case columnGenre
        case columnType
        case playNext
        case addToQueue
        case addToPlaylist
        case removeFromPlaylist
        case showInFinder
        case blockSong
        case previous
        case next
        case repeatMode
        case noLyrics
        case noLyricsFile
        case lyricsUnavailable
        case emptyLyrics
        case noSongPlaying
        case close
        case showSidebar
        case hideSidebar
        case name
        case description
        case playlistName
        case create
        case save
        case playlistDescriptionHint
        case systemTheme
        case lightTheme
        case darkTheme
        case systemLanguage
        case minutesShort
        case unknownArtist
        case unknownAlbum
        case unknownGenre
    }

    static func current(_ key: Key, _ arguments: CVarArg...) -> String {
        let storedLanguage = UserDefaults.standard.string(forKey: AppConfiguration.userDefaultsKey("settings.language"))
        let language = (storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system).resolved
        return text(key, language: language, arguments: arguments)
    }

    static func text(_ key: Key, language: AppLanguage, arguments: [CVarArg] = []) -> String {
        let table = language == .chinese ? zh : en
        let format = table[key] ?? en[key] ?? key.rawValue
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static let en: [Key: String] = [
        .noMatchingArtistMusic: "No matching albums or songs",
        .choose: "Choose",
        .back: "Back",
        .englishLanguage: "English",
        .chineseLanguage: "简体中文",
        .songCount: "%ld songs",
        .oneSong: "%ld song",
        .albumCount: "%ld albums",
        .oneAlbum: "%ld album",
        .playbackQueue: "Playback Queue",
        .queueSummary: "%ld in history · %ld up next",
        .oneScanFailure: "Could not process %ld file.",
        .mcpRotateTokenHint: "Generating a new token invalidates the current token.",
        .lyricsEncoding: "Text Encoding",
        .automaticEncoding: "Automatic",
        .utf8Encoding: "UTF-8",
        .utf16Encoding: "UTF-16",
        .gb18030Encoding: "GB18030 / GBK",
        .big5Encoding: "Big5",
        .retry: "Retry",
        .scanningFiles: "Scanning · %ld processed",
        .importingFiles: "Importing · %ld processed",
        .folderUnavailable: "Scan incomplete",
        .folderScanFailed: "Could not scan “%@”. Existing songs were kept.\n%@",
        .scanFailureCount: "Could not process %ld files.",
        .unsupportedAudio: "This audio format is not supported.",
        .saveStatsFailed: "Could not save play counts.\n%@",
        .loadLibraryFailed: "Could not load the library.\n%@",
        .saveLibraryFailed: "Could not save the library.\n%@",
        .databaseOpenFailed: "Could not open the library database.\n%@",
        .databaseOperationFailed: "A library database operation failed.\n%@",
        .unsupportedDatabase: "This database version is not supported. The existing database was kept.",
        .databaseUnavailable: "The library database is unavailable.",
        .unknownError: "Unknown error",
        .playbackFailed: "Could not play “%@”. %@",
        .audioFileMissing: "The audio file is missing. Reconnect the drive or rescan the folder.",
        .audioFileUnreadable: "Could not read the audio file. Check the folder’s permissions.",
        .audioDecodeFailed: "Could not decode the file or start playback.",
        .undoClearQueue: "Undo Clear Upcoming Songs",
        .playbackMenu: "Playback",
        .playPause: "Play/Pause",
        .focusSearch: "Focus Search",
        .playbackPosition: "Playback Position",
        .positionValue: "%@ of %@",
        .addMusicFolder: "Add Music Folder…",
        .chooseLyricsFile: "Choose Lyrics File…",
        .lyricsOptions: "Lyrics Options",
        .useMatchingLyrics: "Use Matching Lyrics File",
        .lyricsTiming: "Lyrics Timing",
        .lyricsEarlier: "0.5 Seconds Earlier",
        .lyricsLater: "0.5 Seconds Later",
        .resetLyricsTiming: "Reset Timing",
        .lyricsTimingValue: "Timing Offset %+.1f s",
        .lyricsEncodingFailed: "Could not decode the lyrics file. Choose a different encoding.",
        .lyricsParsingFailed: "Could not read the lyric timestamps.",
        .selectedLyricsMissing: "Could not find “%@”. Choose another file or use the matching lyrics file.",
        .noAlbumsYet: "No albums",
        .lyricsLoading: "Loading lyrics…",
        .lyricsReload: "Reload Lyrics",
        .lyricsFileReadFailed: "Could not read the lyrics file.\n%@",
        .noFavoriteSongs: "No favorite songs",
        .favoriteSongsHint: "Mark a song as a favorite to add it to this list.",
        .emptyPlaylist: "No songs in this playlist",
        .emptyPlaylistHint: "Drag songs onto this playlist in the sidebar.",
        .showDetails: "Show Details",
        .mcpSection: "MCP",
        .mcpEnable: "Enable MCP",
        .mcpDescription: "Allow local clients to search the library, control playback, manage playlists, and block songs.",
        .mcpRequireToken: "Require Access Token",
        .mcpRequireTokenDescription: "With this off, processes under your macOS account can use all MCP tools without a token.",
        .mcpStatus: "Status",
        .mcpOff: "Off",
        .mcpStarting: "Starting…",
        .mcpRunning: "Running",
        .mcpFailed: "Failed to start",
        .mcpCopyCommand: "Copy Command Path",
        .mcpCopyToken: "Copy Token",
        .mcpRotateToken: "Rotate Token",
        .mcpAuthenticationHint: "Use this path as the stdio command in your MCP client. Set MINTPLAYER_MCP_TOKEN to your access token.",
        .mcpNoAuthenticationHint: "Use this path as the stdio command in your MCP client.",
        .mcpPlayerNotReady: "The player is not ready yet.",
        .mcpTokenInvalid: "The MCP access token could not be read. Rotate it in Settings.",
        .mcpDisabled: "Open Mint Player and enable MCP in Settings.",
        .mcpUnauthorized: "Set MINTPLAYER_MCP_TOKEN in your MCP client to the current access token from Mint Player.",
        .mcpLocalConnectionFailed: "Could not connect to Mint Player. Check MCP in Settings.",
        .mcpHelperNotInstalled: "Use the MCP command inside the Mint Player app bundle.",
        .mcpStdioStartError: "The MCP command could not start its standard input and output connection.",
        .mcpAppLaunchError: "Mint Player could not be opened.",
        .mcpRequestTooLarge: "The MCP request is too large.",
        .mcpUnexpectedArguments: "The tool does not accept one or more supplied arguments.",
        .mcpInvalidUUID: "%@ must be a UUID.",
        .mcpInvalidPage: "offset must be a nonnegative integer and limit must be an integer from 1 to %ld.",
        .mcpInvalidPlaylistName: "Enter a playlist name.",
        .mcpInvalidPlaylistDescription: "description must be a string.",
        .mcpInvalidSongIDs: "song_ids must be a nonempty array of song UUIDs.",
        .mcpSongNotFound: "One or more songs are no longer in the library.",
        .mcpSongNotInPlaylist: "Every song in the move request must be in the playlist.",
        .mcpBlockedSongNotFound: "The blocked song record no longer exists.",
        .mcpSongSourceUnavailable: "Only songs associated with a library folder can be blocked.",
        .mcpLibrarySaveFailed: "The library change could not be saved.",
        .general: "General",
        .appearance: "Appearance",
        .interfaceTheme: "Theme",
        .theme: "Theme",
        .language: "Language",
        .themeDescription: "The lyrics player always uses a dark appearance.",
        .languageDescription: "System uses your preferred macOS language. Mint Player supports English and Simplified Chinese.",
        .playbackPage: "Playback",
        .lyrics: "Lyrics",
        .lyricsPresentation: "Lyrics Display",
        .lyricsPresentationDescription: "Applies when you open lyrics from the player bar.",
        .embeddedLyrics: "Main Window",
        .separateLyricsWindow: "Separate Window",
        .lyricsBlur: "Blur inactive lyrics",
        .lyricsBlurEffect: "Lyrics Blur",
        .lyricsBlurDescription: "Blur lines around the current lyric.",
        .library: "Library",
        .musicLibrary: "Music Library",
        .addMusicLibrary: "Name Music Folder",
        .rescanAll: "Rescan All Folders",
        .libraryDescription: "Add folders that contain local music files. Rescanning updates metadata and artwork for existing library folders.",
        .folders: "Folders",
        .noMusicLibraries: "No music folders",
        .addFolderDescription: "Choose a folder that contains audio files.",
        .lastScanned: "Last scanned %@",
        .rescan: "Rescan Folder",
        .remove: "Remove",
        .blockedSongs: "Blocked Songs",
        .unblock: "Unblock",
        .unblockSong: "Unblock Song",
        .about: "About",
        .version: "Version %@",
        .add: "Add",
        .cancel: "Cancel",
        .enterLibraryName: "Enter a name for this folder in the library.",
        .home: "Home",
        .startListening: "Start Playback",
        .resumePlayback: "Resume Playback",
        .resumeFromTime: "Resume from %@",
        .quickPlay: "Quick play",
        .favoriteWidgetSubtitle: "Play favorite songs",
        .shuffleWidgetSubtitle: "All songs in the library",
        .lyricsWidgetIdle: "Play a song to see lyrics",
        .showFullScreenLyrics: "Open Lyrics in Main Window",
        .playFavoriteSongs: "Play your favorite songs",
        .shuffleLibrary: "Shuffle your library",
        .browseAlbums: "Browse your albums",
        .recentlyPlayed: "Recently Played",
        .noRecentlyPlayed: "No playback history",
        .showMore: "Show More",
        .songs: "Songs",
        .albums: "Albums",
        .artists: "Artists",
        .favorites: "Favorites",
        .playlists: "Playlists",
        .foldersSection: "Music Folders",
        .noPlaylists: "No playlists",
        .noFolders: "No folders",
        .newPlaylist: "New Playlist",
        .editPlaylist: "Edit Playlist",
        .deletePlaylist: "Delete Playlist",
        .deleteFolder: "Remove Folder",
        .deletePlaylistQuestion: "Delete Playlist?",
        .deleteFolderQuestion: "Remove Folder?",
        .deletePlaylistMessage: "Delete “%@”. Its songs will stay in your library.",
        .deleteFolderMessage: "Songs in “%@” will be removed from the library and playlists. The folder’s blocked-song records will be cleared. Audio files will stay on disk.",
        .settings: "Settings",
        .playlistNotFound: "Playlist not found",
        .folderNotFound: "Folder not found",
        .noSongsYet: "No songs",
        .noMatchingSongs: "No songs match your search",
        .importPrompt: "Add a music folder or drag audio files into the window.",
        .searchSongs: "Search Songs",
        .searchAlbums: "Search Albums",
        .searchInAlbum: "Search in Album",
        .searchArtists: "Search Artists",
        .searchInArtist: "Search in Artist",
        .noMatchingAlbums: "No albums match your search",
        .noArtistsYet: "No artists",
        .noMatchingArtists: "No artists match your search",
        .play: "Play",
        .pause: "Pause",
        .shuffle: "Shuffle",
        .notPlaying: "Nothing Playing",
        .nowPlaying: "Now Playing",
        .chooseSong: "Choose a song to play",
        .upNext: "Up Next",
        .volume: "Volume",
        .showLyrics: "Show Lyrics",
        .addToFavorites: "Add to Favorites",
        .removeFromFavorites: "Remove from Favorites",
        .queueEmpty: "No songs in the queue",
        .removeFromQueue: "Remove from Queue",
        .clearQueue: "Clear Upcoming Songs",
        .closeUpNext: "Close Playback Queue",
        .history: "Playback History",
        .sortSongs: "Sort Songs",
        .ascending: "Ascending",
        .descending: "Descending",
        .title: "Title",
        .titleDescending: "Title Descending",
        .artist: "Artist",
        .artistDescending: "Artist Descending",
        .album: "Album",
        .albumDescending: "Album Descending",
        .duration: "Duration",
        .durationDescending: "Duration Descending",
        .playCount: "Play Count",
        .playCountAscending: "Play Count Ascending",
        .dateAdded: "Date Added",
        .dateAddedAscending: "Date Added Ascending",
        .columns: "Columns",
        .columnSong: "Song",
        .columnTrackNumber: "#",
        .columnArtist: "Artist",
        .columnDuration: "Duration",
        .columnPlayCount: "Play Count",
        .columnDateAdded: "Date Added",
        .columnFavorite: "Favorite",
        .columnTitle: "Title",
        .columnAlbum: "Album",
        .columnGenre: "Genre",
        .columnType: "Type",
        .playNext: "Play Next",
        .addToQueue: "Add to Queue",
        .addToPlaylist: "Add to Playlist",
        .removeFromPlaylist: "Remove from Playlist",
        .showInFinder: "Show in Finder",
        .blockSong: "Block Song",
        .previous: "Previous Song",
        .next: "Next Song",
        .repeatMode: "Repeat",
        .noLyrics: "No Lyrics",
        .noLyricsFile: "No matching .lrc file was found next to the audio file.",
        .lyricsUnavailable: "Lyrics Unavailable",
        .emptyLyrics: "The lyrics file contains no lyrics.",
        .noSongPlaying: "No song selected",
        .close: "Close",
        .showSidebar: "Show Sidebar",
        .hideSidebar: "Hide Sidebar",
        .name: "Name",
        .description: "Description",
        .playlistName: "Playlist Name",
        .create: "Create",
        .save: "Save",
        .playlistDescriptionHint: "Add a note",
        .systemTheme: "System",
        .lightTheme: "Light",
        .darkTheme: "Dark",
        .systemLanguage: "System",
        .minutesShort: "min",
        .unknownArtist: "Unknown Artist",
        .unknownAlbum: "Unknown Album",
        .unknownGenre: "Unknown Genre"
    ]

    private static let zh: [Key: String] = [
        .noMatchingArtistMusic: "未找到匹配的专辑或歌曲",
        .choose: "选取",
        .back: "返回",
        .englishLanguage: "English",
        .chineseLanguage: "简体中文",
        .songCount: "%ld 首歌曲",
        .oneSong: "%ld 首歌曲",
        .albumCount: "%ld 张专辑",
        .oneAlbum: "%ld 张专辑",
        .playbackQueue: "播放队列",
        .queueSummary: "历史 %ld 首 · 待播 %ld 首",
        .oneScanFailure: "无法处理 %ld 个文件。",
        .mcpRotateTokenHint: "生成新令牌后，现有令牌将失效。",
        .lyricsEncoding: "文本编码",
        .automaticEncoding: "自动",
        .utf8Encoding: "UTF-8",
        .utf16Encoding: "UTF-16",
        .gb18030Encoding: "GB18030 / GBK",
        .big5Encoding: "Big5",
        .retry: "重试",
        .scanningFiles: "正在扫描 · 已处理 %ld 个文件",
        .importingFiles: "正在导入 · 已处理 %ld 个文件",
        .folderUnavailable: "扫描未完成",
        .folderScanFailed: "无法扫描“%@”。已保留原有歌曲。\n%@",
        .scanFailureCount: "无法处理 %ld 个文件。",
        .unsupportedAudio: "不支持此音频格式。",
        .saveStatsFailed: "无法保存播放次数。\n%@",
        .loadLibraryFailed: "无法加载资料库。\n%@",
        .saveLibraryFailed: "无法保存资料库。\n%@",
        .databaseOpenFailed: "无法打开资料库数据库。\n%@",
        .databaseOperationFailed: "资料库数据库操作失败。\n%@",
        .unsupportedDatabase: "不支持此资料库版本。已保留现有资料库。",
        .databaseUnavailable: "资料库数据库不可用。",
        .unknownError: "未知错误",
        .playbackFailed: "无法播放“%@”。%@",
        .audioFileMissing: "找不到音频文件。请重新连接磁盘或重新扫描文件夹。",
        .audioFileUnreadable: "无法读取音频文件。请检查文件夹权限。",
        .audioDecodeFailed: "无法解码文件或启动播放。",
        .undoClearQueue: "撤销清空待播歌曲",
        .playbackMenu: "播放控制",
        .playPause: "播放／暂停",
        .focusSearch: "聚焦搜索框",
        .playbackPosition: "播放进度",
        .positionValue: "%@，共 %@",
        .addMusicFolder: "添加音乐文件夹…",
        .chooseLyricsFile: "选择歌词文件…",
        .lyricsOptions: "歌词选项",
        .useMatchingLyrics: "使用同名歌词文件",
        .lyricsTiming: "歌词时间",
        .lyricsEarlier: "提前 0.5 秒",
        .lyricsLater: "延后 0.5 秒",
        .resetLyricsTiming: "重置时间",
        .lyricsTimingValue: "时间偏移 %+.1f 秒",
        .lyricsEncodingFailed: "无法解读歌词文件。请选择其他文本编码。",
        .lyricsParsingFailed: "无法读取歌词时间戳。",
        .selectedLyricsMissing: "找不到歌词文件“%@”。请选择其他文件，或使用同名歌词文件。",
        .noAlbumsYet: "暂无专辑",
        .lyricsLoading: "正在加载歌词…",
        .lyricsReload: "重新加载歌词",
        .lyricsFileReadFailed: "无法读取歌词文件。\n%@",
        .noFavoriteSongs: "暂无喜欢的歌曲",
        .favoriteSongsHint: "将歌曲标记为喜欢，即可加入此列表。",
        .emptyPlaylist: "播放列表为空",
        .emptyPlaylistHint: "将歌曲拖到侧栏中的此播放列表。",
        .showDetails: "查看详情",
        .mcpSection: "MCP",
        .mcpEnable: "启用 MCP",
        .mcpDescription: "允许本机客户端搜索资料库、控制播放、管理播放列表和屏蔽歌曲。",
        .mcpRequireToken: "要求访问令牌",
        .mcpRequireTokenDescription: "关闭后，当前 macOS 账户下的进程无需令牌即可调用所有 MCP 工具。",
        .mcpStatus: "状态",
        .mcpOff: "已关闭",
        .mcpStarting: "正在启动…",
        .mcpRunning: "运行中",
        .mcpFailed: "启动失败",
        .mcpCopyCommand: "复制命令路径",
        .mcpCopyToken: "复制令牌",
        .mcpRotateToken: "重新生成令牌",
        .mcpAuthenticationHint: "在 MCP 客户端中将此路径设为 stdio 命令。将访问令牌填入 MINTPLAYER_MCP_TOKEN 环境变量。",
        .mcpNoAuthenticationHint: "在 MCP 客户端中将此路径设为 stdio 命令。",
        .mcpPlayerNotReady: "播放器尚未就绪。",
        .mcpTokenInvalid: "无法读取 MCP 访问令牌。请在设置中重新生成令牌。",
        .mcpDisabled: "请打开 Mint Player 并在设置中启用 MCP。",
        .mcpUnauthorized: "请将 MCP 客户端的 MINTPLAYER_MCP_TOKEN 更新为 Mint Player 当前的访问令牌。",
        .mcpLocalConnectionFailed: "无法连接 Mint Player。请检查设置中的 MCP 状态。",
        .mcpHelperNotInstalled: "请使用 Mint Player 应用包内的 MCP 命令。",
        .mcpStdioStartError: "MCP 命令无法启动标准输入输出连接。",
        .mcpAppLaunchError: "无法打开 Mint Player。",
        .mcpRequestTooLarge: "MCP 请求过大。",
        .mcpUnexpectedArguments: "工具不接受请求中的一个或多个参数。",
        .mcpInvalidUUID: "%@ 必须是 UUID。",
        .mcpInvalidPage: "offset 必须是非负整数，limit 必须是 1 到 %ld 之间的整数。",
        .mcpInvalidPlaylistName: "请输入播放列表名称。",
        .mcpInvalidPlaylistDescription: "description 必须是字符串。",
        .mcpInvalidSongIDs: "song_ids 必须是包含至少一个歌曲 UUID 的数组。",
        .mcpSongNotFound: "资料库中找不到一首或多首指定歌曲。",
        .mcpSongNotInPlaylist: "要移动的歌曲及作为目标的歌曲都必须在播放列表中。",
        .mcpBlockedSongNotFound: "找不到指定的屏蔽记录。",
        .mcpSongSourceUnavailable: "只有关联到资料库文件夹的歌曲才能屏蔽。",
        .mcpLibrarySaveFailed: "无法保存资料库更改。",
        .general: "通用",
        .appearance: "外观",
        .interfaceTheme: "主题",
        .theme: "主题",
        .language: "语言",
        .themeDescription: "歌词播放界面始终采用深色外观。",
        .languageDescription: "跟随系统时使用 macOS 首选语言。应用支持简体中文和英语。",
        .playbackPage: "播放",
        .lyrics: "歌词",
        .lyricsPresentation: "歌词显示方式",
        .lyricsPresentationDescription: "此设置适用于从播放器栏打开歌词。",
        .embeddedLyrics: "主窗口内",
        .separateLyricsWindow: "独立窗口",
        .lyricsBlur: "模糊非当前歌词",
        .lyricsBlurEffect: "歌词模糊",
        .lyricsBlurDescription: "模糊当前歌词行周围的其他行。",
        .library: "资料库",
        .musicLibrary: "音乐资料库",
        .addMusicLibrary: "命名音乐文件夹",
        .rescanAll: "重新扫描所有文件夹",
        .libraryDescription: "添加包含本地音乐文件的文件夹。重新扫描会更新已有资料库文件夹的元数据和封面。",
        .folders: "文件夹",
        .noMusicLibraries: "未添加音乐文件夹",
        .addFolderDescription: "请选择包含音频文件的文件夹。",
        .lastScanned: "上次扫描 %@",
        .rescan: "重新扫描文件夹",
        .remove: "移除",
        .blockedSongs: "已屏蔽歌曲",
        .unblock: "取消屏蔽",
        .unblockSong: "取消屏蔽歌曲",
        .about: "关于",
        .version: "版本 %@",
        .add: "添加",
        .cancel: "取消",
        .enterLibraryName: "输入此文件夹在资料库中的显示名称。",
        .home: "首页",
        .startListening: "开始播放",
        .resumePlayback: "继续播放",
        .resumeFromTime: "从 %@ 继续播放",
        .quickPlay: "快速播放",
        .favoriteWidgetSubtitle: "播放喜欢的歌曲",
        .shuffleWidgetSubtitle: "资料库中的所有歌曲",
        .lyricsWidgetIdle: "播放歌曲后显示歌词",
        .showFullScreenLyrics: "在主窗口中打开歌词",
        .playFavoriteSongs: "播放收藏的歌曲",
        .shuffleLibrary: "从整个资料库开始",
        .browseAlbums: "浏览资料库中的专辑",
        .recentlyPlayed: "最近播放",
        .noRecentlyPlayed: "暂无播放记录",
        .showMore: "显示更多",
        .songs: "歌曲",
        .albums: "专辑",
        .artists: "艺人",
        .favorites: "喜欢的音乐",
        .playlists: "播放列表",
        .foldersSection: "音乐文件夹",
        .noPlaylists: "暂无播放列表",
        .noFolders: "暂无文件夹",
        .newPlaylist: "新建播放列表",
        .editPlaylist: "编辑播放列表",
        .deletePlaylist: "删除播放列表",
        .deleteFolder: "移除文件夹",
        .deletePlaylistQuestion: "删除播放列表？",
        .deleteFolderQuestion: "移除文件夹？",
        .deletePlaylistMessage: "删除“%@”。其中的歌曲仍保留在资料库中。",
        .deleteFolderMessage: "“%@”中的歌曲将从资料库和播放列表中移除。该文件夹的屏蔽记录将被清除。磁盘上的音频文件会保留。",
        .settings: "设置",
        .playlistNotFound: "找不到播放列表",
        .folderNotFound: "找不到文件夹",
        .noSongsYet: "暂无歌曲",
        .noMatchingSongs: "未找到匹配的歌曲",
        .importPrompt: "添加音乐文件夹，或将音频文件拖入窗口。",
        .searchSongs: "搜索歌曲",
        .searchAlbums: "搜索专辑",
        .searchInAlbum: "在专辑中搜索",
        .searchArtists: "搜索艺人",
        .searchInArtist: "在艺人中搜索",
        .noMatchingAlbums: "未找到匹配的专辑",
        .noArtistsYet: "暂无艺人",
        .noMatchingArtists: "未找到匹配的艺人",
        .play: "播放",
        .pause: "暂停",
        .shuffle: "随机播放",
        .notPlaying: "未播放",
        .nowPlaying: "正在播放",
        .chooseSong: "请选择要播放的歌曲",
        .upNext: "待播",
        .volume: "音量",
        .showLyrics: "显示歌词",
        .addToFavorites: "添加到喜欢的音乐",
        .removeFromFavorites: "从喜欢的音乐中移除",
        .queueEmpty: "播放队列为空",
        .removeFromQueue: "移出播放队列",
        .clearQueue: "清空待播歌曲",
        .closeUpNext: "关闭播放队列",
        .history: "播放历史",
        .sortSongs: "歌曲排序",
        .ascending: "升序",
        .descending: "降序",
        .title: "标题",
        .titleDescending: "标题降序",
        .artist: "艺人",
        .artistDescending: "艺人降序",
        .album: "专辑",
        .albumDescending: "专辑降序",
        .duration: "时长",
        .durationDescending: "时长降序",
        .playCount: "播放次数",
        .playCountAscending: "播放次数升序",
        .dateAdded: "添加时间",
        .dateAddedAscending: "添加时间升序",
        .columns: "列",
        .columnSong: "歌曲",
        .columnTrackNumber: "#",
        .columnArtist: "艺人",
        .columnDuration: "时长",
        .columnPlayCount: "播放次数",
        .columnDateAdded: "添加时间",
        .columnFavorite: "喜欢",
        .columnTitle: "标题",
        .columnAlbum: "专辑",
        .columnGenre: "流派",
        .columnType: "类型",
        .playNext: "下一首播放",
        .addToQueue: "加入播放队列",
        .addToPlaylist: "添加到播放列表",
        .removeFromPlaylist: "移出播放列表",
        .showInFinder: "在 Finder 中显示",
        .blockSong: "屏蔽歌曲",
        .previous: "上一首",
        .next: "下一首",
        .repeatMode: "循环",
        .noLyrics: "暂无歌词",
        .noLyricsFile: "音频文件所在的文件夹中没有同名的 .lrc 文件。",
        .lyricsUnavailable: "歌词不可用",
        .emptyLyrics: "歌词文件中没有可显示的内容。",
        .noSongPlaying: "未选择歌曲",
        .close: "关闭",
        .showSidebar: "显示侧栏",
        .hideSidebar: "隐藏侧栏",
        .name: "名称",
        .description: "描述",
        .playlistName: "播放列表名称",
        .create: "创建",
        .save: "保存",
        .playlistDescriptionHint: "添加备注",
        .systemTheme: "跟随系统",
        .lightTheme: "浅色",
        .darkTheme: "深色",
        .systemLanguage: "跟随系统",
        .minutesShort: "分钟",
        .unknownArtist: "未知艺人",
        .unknownAlbum: "未知专辑",
        .unknownGenre: "未知流派"
    ]
}
