import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var theme: ThemeMode = .dark
    @Published var language: AppLanguage = .system
    @Published var lyricsBlurEnabled = true

    private let userDefaults = UserDefaults.standard
    private let themeKey = AppConfiguration.userDefaultsKey("settings.theme")
    private let languageKey = AppConfiguration.userDefaultsKey("settings.language")
    private let lyricsBlurEnabledKey = AppConfiguration.userDefaultsKey("settings.lyrics.blurEnabled")

    init() {
        loadSettings()
    }

    // 加载设置
    private func loadSettings() {
        if let themeString = userDefaults.string(forKey: themeKey), let savedTheme = ThemeMode(rawValue: themeString) {
            theme = savedTheme
        }
        if let languageString = userDefaults.string(forKey: languageKey), let savedLanguage = AppLanguage(rawValue: languageString) {
            language = savedLanguage
        }
        if userDefaults.object(forKey: lyricsBlurEnabledKey) != nil {
            lyricsBlurEnabled = userDefaults.bool(forKey: lyricsBlurEnabledKey)
        }
    }

    // 保存设置
    func saveSettings() {
        userDefaults.set(theme.rawValue, forKey: themeKey)
        userDefaults.set(language.rawValue, forKey: languageKey)
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

    func updateLyricsBlurEnabled(_ isEnabled: Bool) {
        lyricsBlurEnabled = isEnabled
        saveSettings()
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

    func text(_ key: L10n.Key) -> String {
        L10n.text(key, language: effectiveLanguage)
    }

    var versionText: String {
        String(format: text(.version), AppConfiguration.versionTag)
    }
}

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
        case general
        case appearance
        case interfaceTheme
        case theme
        case language
        case themeDescription
        case languageDescription
        case playbackPage
        case lyrics
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
        case editPlaylistAction
        case deletePlaylist
        case deleteFolder
        case deletePlaylistQuestion
        case deleteFolderQuestion
        case deletePlaylistMessage
        case deleteFolderMessage
        case settings
        case playlistNotFound
        case folderNotFound
        case tracks
        case noSongsYet
        case noMatchingSongs
        case importPrompt
        case searchSongs
        case searchAlbums
        case searchInAlbum
        case searchArtists
        case searchInArtist
        case noMatchingMusic
        case artistSearchHint
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
        case upNextLower
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
        case items
        case minutesShort
        case unknownArtist
        case unknownAlbum
        case unknownGenre
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let table = language == .chinese ? zh : en
        return table[key] ?? en[key] ?? key.rawValue
    }

    private static let en: [Key: String] = [
        .general: "General",
        .appearance: "Appearance",
        .interfaceTheme: "Interface Theme",
        .theme: "Theme",
        .language: "Language",
        .themeDescription: "Choose the appearance used by Mint Player windows.",
        .languageDescription: "Choose the language used by Mint Player text.",
        .playbackPage: "Playback Page",
        .lyrics: "Lyrics",
        .lyricsBlur: "Blur inactive lyrics",
        .lyricsBlurEffect: "Lyrics Blur Effect",
        .lyricsBlurDescription: "Slightly blur lyrics farther from the current line.",
        .library: "Library",
        .musicLibrary: "Music Library",
        .addMusicLibrary: "Add Library",
        .rescanAll: "Rescan Library",
        .libraryDescription: "Add folders that contain local music files. Rescanning updates metadata and artwork for existing library folders.",
        .folders: "Folders",
        .noMusicLibraries: "No music libraries",
        .addFolderDescription: "Add a folder to start building your local library.",
        .lastScanned: "Last scanned",
        .rescan: "Rescan",
        .remove: "Remove",
        .blockedSongs: "Blocked Songs",
        .unblock: "Unblock",
        .unblockSong: "Unblock Song",
        .about: "About",
        .version: "Version %@",
        .add: "Add",
        .cancel: "Cancel",
        .enterLibraryName: "Enter a name for this music library",
        .songs: "Songs",
        .albums: "Albums",
        .artists: "Artists",
        .favorites: "Favorites",
        .playlists: "Playlists",
        .foldersSection: "Library",
        .noPlaylists: "No playlists",
        .noFolders: "No folders",
        .newPlaylist: "New Playlist",
        .editPlaylist: "Edit Playlist",
        .editPlaylistAction: "Edit Playlist",
        .deletePlaylist: "Delete Playlist",
        .deleteFolder: "Delete Folder",
        .deletePlaylistQuestion: "Delete Playlist?",
        .deleteFolderQuestion: "Delete Folder?",
        .deletePlaylistMessage: "This will remove \"%@\" from Mint Player. Songs will stay in your library.",
        .deleteFolderMessage: "This will remove \"%@\" and its songs from Mint Player. Files on disk will not be deleted.",
        .settings: "Settings",
        .playlistNotFound: "Playlist not found",
        .folderNotFound: "Folder not found",
        .tracks: "tracks",
        .noSongsYet: "No songs yet",
        .noMatchingSongs: "No matching songs",
        .importPrompt: "Import a folder or drag audio files into this window.",
        .searchSongs: "Search Songs",
        .searchAlbums: "Search Albums",
        .searchInAlbum: "Search in Album",
        .searchArtists: "Search Artists",
        .searchInArtist: "Search in Artist",
        .noMatchingMusic: "No matching music",
        .artistSearchHint: "Try a different artist search.",
        .noArtistsYet: "No artists yet",
        .noMatchingArtists: "No matching artists",
        .play: "Play",
        .pause: "Pause",
        .shuffle: "Shuffle",
        .notPlaying: "Not Playing",
        .nowPlaying: "Now Playing",
        .chooseSong: "Choose a song to start listening",
        .upNext: "Up Next",
        .volume: "Volume",
        .showLyrics: "Show Lyrics",
        .addToFavorites: "Add to Favorites",
        .removeFromFavorites: "Remove from Favorites",
        .queueEmpty: "Queue is empty",
        .removeFromQueue: "Remove from Queue",
        .clearQueue: "Clear queue",
        .closeUpNext: "Close Up Next",
        .history: "history",
        .upNextLower: "up next",
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
        .previous: "Previous",
        .next: "Next",
        .repeatMode: "Repeat",
        .noLyrics: "No Lyrics",
        .noLyricsFile: "No .lrc file matching the current song was found in the same folder.",
        .lyricsUnavailable: "Lyrics Unavailable",
        .emptyLyrics: "The lyrics file has no displayable text.",
        .noSongPlaying: "No Song Playing",
        .close: "Close",
        .name: "Name",
        .description: "Description",
        .playlistName: "Playlist Name",
        .create: "Create",
        .save: "Save",
        .playlistDescriptionHint: "Add notes, mood, context, or anything useful for this playlist.",
        .systemTheme: "System",
        .lightTheme: "Light",
        .darkTheme: "Dark",
        .systemLanguage: "System",
        .items: "items",
        .minutesShort: "min",
        .unknownArtist: "Unknown Artist",
        .unknownAlbum: "Unknown Album",
        .unknownGenre: "Unknown Genre"
    ]

    private static let zh: [Key: String] = [
        .general: "通用",
        .appearance: "外观",
        .interfaceTheme: "界面主题",
        .theme: "主题",
        .language: "语言",
        .themeDescription: "选择 Mint Player 窗口使用的外观。",
        .languageDescription: "选择 Mint Player 界面文本使用的语言。",
        .playbackPage: "播放页面",
        .lyrics: "歌词",
        .lyricsBlur: "模糊非当前歌词",
        .lyricsBlurEffect: "歌词模糊效果",
        .lyricsBlurDescription: "对远离当前行的歌词添加轻微模糊。",
        .library: "资料库",
        .musicLibrary: "音乐资料库",
        .addMusicLibrary: "添加资料库",
        .rescanAll: "重新扫描资料库",
        .libraryDescription: "添加包含本地音乐文件的文件夹。重新扫描会更新已有资料库文件夹的元数据和封面。",
        .folders: "文件夹",
        .noMusicLibraries: "没有音乐资料库",
        .addFolderDescription: "添加一个文件夹以开始构建本地资料库。",
        .lastScanned: "上次扫描",
        .rescan: "重新扫描",
        .remove: "移除",
        .blockedSongs: "已屏蔽歌曲",
        .unblock: "取消屏蔽",
        .unblockSong: "取消屏蔽歌曲",
        .about: "关于",
        .version: "版本 %@",
        .add: "添加",
        .cancel: "取消",
        .enterLibraryName: "输入此音乐资料库的名称",
        .songs: "歌曲",
        .albums: "专辑",
        .artists: "艺人",
        .favorites: "喜欢的音乐",
        .playlists: "播放列表",
        .foldersSection: "资料库",
        .noPlaylists: "没有播放列表",
        .noFolders: "没有文件夹",
        .newPlaylist: "新播放列表",
        .editPlaylist: "编辑播放列表",
        .editPlaylistAction: "编辑播放列表",
        .deletePlaylist: "删除播放列表",
        .deleteFolder: "删除文件夹",
        .deletePlaylistQuestion: "删除播放列表？",
        .deleteFolderQuestion: "删除文件夹？",
        .deletePlaylistMessage: "这会从 Mint Player 中移除“%@”。歌曲会保留在资料库中。",
        .deleteFolderMessage: "这会从 Mint Player 中移除“%@”及其中的歌曲。磁盘上的文件不会被删除。",
        .settings: "设置",
        .playlistNotFound: "找不到播放列表",
        .folderNotFound: "找不到文件夹",
        .tracks: "首歌曲",
        .noSongsYet: "还没有歌曲",
        .noMatchingSongs: "没有匹配的歌曲",
        .importPrompt: "导入文件夹，或将音频文件拖入此窗口。",
        .searchSongs: "搜索歌曲",
        .searchAlbums: "搜索专辑",
        .searchInAlbum: "在专辑中搜索",
        .searchArtists: "搜索艺人",
        .searchInArtist: "在艺人中搜索",
        .noMatchingMusic: "没有匹配的音乐",
        .artistSearchHint: "试试搜索其他艺人。",
        .noArtistsYet: "还没有艺人",
        .noMatchingArtists: "没有匹配的艺人",
        .play: "播放",
        .pause: "暂停",
        .shuffle: "随机播放",
        .notPlaying: "未播放",
        .nowPlaying: "正在播放",
        .chooseSong: "选择一首歌开始聆听",
        .upNext: "播放队列",
        .volume: "音量",
        .showLyrics: "显示歌词",
        .addToFavorites: "添加到喜欢的音乐",
        .removeFromFavorites: "从喜欢的音乐中移除",
        .queueEmpty: "队列为空",
        .removeFromQueue: "从队列中移除",
        .clearQueue: "清空队列",
        .closeUpNext: "关闭播放队列",
        .history: "历史",
        .upNextLower: "即将播放",
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
        .addToQueue: "加入队列",
        .addToPlaylist: "添加到播放列表",
        .removeFromPlaylist: "移出播放列表",
        .showInFinder: "在 Finder 中显示",
        .blockSong: "屏蔽歌曲",
        .previous: "上一首",
        .next: "下一首",
        .repeatMode: "循环",
        .noLyrics: "无歌词",
        .noLyricsFile: "未找到与当前歌曲同目录同名的 .lrc 文件。",
        .lyricsUnavailable: "歌词不可用",
        .emptyLyrics: "歌词文件里没有可显示的文本。",
        .noSongPlaying: "没有正在播放的歌曲",
        .close: "关闭",
        .name: "名称",
        .description: "描述",
        .playlistName: "播放列表名称",
        .create: "创建",
        .save: "保存",
        .playlistDescriptionHint: "添加备注、氛围、场景，或任何对这个播放列表有用的信息。",
        .systemTheme: "跟随系统",
        .lightTheme: "浅色",
        .darkTheme: "深色",
        .systemLanguage: "跟随系统",
        .items: "项",
        .minutesShort: "分钟",
        .unknownArtist: "未知艺人",
        .unknownAlbum: "未知专辑",
        .unknownGenre: "未知流派"
    ]
}
