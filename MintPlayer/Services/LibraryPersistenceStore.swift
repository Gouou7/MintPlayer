import Foundation
import SQLite3

struct LibraryPersistentSnapshot {
    var songs: [Song]
    var playlists: [Playlist]
    var librarySources: [MusicLibrarySource]
    var blockedSongs: [BlockedSong]
}

final class LibraryPersistenceStore {
    enum StoreError: LocalizedError {
        case databaseOpenFailed(String)
        case statementFailed(String)
        case missingDatabase

        var errorDescription: String? {
            switch self {
            case .databaseOpenFailed(let message):
                return "无法打开资料库数据库：\(message)"
            case .statementFailed(let message):
                return "数据库操作失败：\(message)"
            case .missingDatabase:
                return "资料库数据库尚未初始化"
            }
        }
    }

    private let databaseURL: URL
    private var database: OpaquePointer?
    private let schemaVersion: Int32 = 3

    init() throws {
        let appSupportURL = try AppConfiguration.applicationSupportDirectory()
        databaseURL = appSupportURL.appendingPathComponent("MintPlayer.sqlite")

        try open()
        try configureDatabase()
        try createSchema()
    }

    deinit {
        sqlite3_close(database)
    }

    func loadSnapshot() throws -> LibraryPersistentSnapshot {
        let sources = try loadLibrarySources()
        let songs = try loadSongs()
        let songsByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        let playlists = try loadPlaylists(songsByID: songsByID)
        let blockedSongs = try loadBlockedSongs()
        return LibraryPersistentSnapshot(
            songs: songs,
            playlists: playlists,
            librarySources: sources,
            blockedSongs: blockedSongs
        )
    }

    func saveSnapshot(_ snapshot: LibraryPersistentSnapshot) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try execute("DELETE FROM playlist_songs")
            try execute("DELETE FROM playlists")
            try execute("DELETE FROM songs")
            try execute("DELETE FROM blocked_songs")
            try execute("DELETE FROM library_sources")

            try saveLibrarySources(snapshot.librarySources)
            try saveSongs(snapshot.songs)
            try savePlaylists(snapshot.playlists)
            try saveBlockedSongs(snapshot.blockedSongs)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func open() throws {
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            let message = databaseErrorMessage
            sqlite3_close(database)
            database = nil
            throw StoreError.databaseOpenFailed(message)
        }
    }

    private func configureDatabase() throws {
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    private func createSchema() throws {
        if try userVersion() != schemaVersion {
            try resetSchema()
        }

        try execute(
            """
            CREATE TABLE IF NOT EXISTS songs (
                id TEXT PRIMARY KEY NOT NULL,
                sourceId TEXT,
                path TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT NOT NULL,
                duration REAL NOT NULL,
                coverPath TEXT,
                genre TEXT,
                year INTEGER,
                dateAdded REAL NOT NULL,
                playCount INTEGER NOT NULL DEFAULT 0,
                lastPlayedAt REAL,
                isFavorite INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (sourceId) REFERENCES library_sources(id) ON DELETE CASCADE
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS playlists (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                description TEXT NOT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                sortOrder INTEGER NOT NULL
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS playlist_songs (
                playlistId TEXT NOT NULL,
                songId TEXT NOT NULL,
                addedAt REAL NOT NULL,
                sortOrder INTEGER NOT NULL,
                PRIMARY KEY (playlistId, songId),
                FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE,
                FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS library_sources (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                path TEXT NOT NULL,
                lastScanned REAL
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS blocked_songs (
                id TEXT PRIMARY KEY NOT NULL,
                sourceId TEXT NOT NULL,
                path TEXT NOT NULL,
                title TEXT NOT NULL,
                artist TEXT NOT NULL,
                album TEXT NOT NULL,
                blockedAt REAL NOT NULL,
                UNIQUE (sourceId, path),
                FOREIGN KEY (sourceId) REFERENCES library_sources(id) ON DELETE CASCADE
            )
            """
        )

        try execute("PRAGMA user_version = \(schemaVersion)")
    }

    private func loadSongs() throws -> [Song] {
        try readRows(
            """
            SELECT id, sourceId, title, artist, album, duration, path, coverPath, genre, year, dateAdded, playCount, lastPlayedAt, isFavorite
            FROM songs
            ORDER BY title COLLATE NOCASE ASC
            """
        ) { statement in
            Song(
                id: uuid(statement, 0),
                title: text(statement, 2),
                artist: text(statement, 3),
                album: text(statement, 4),
                duration: double(statement, 5),
                path: text(statement, 6),
                coverPath: optionalText(statement, 7),
                genre: optionalText(statement, 8),
                year: optionalInt(statement, 9),
                librarySourceId: optionalUUID(statement, 1),
                dateAdded: date(statement, 10),
                playCount: int(statement, 11),
                lastPlayedAt: optionalDate(statement, 12),
                isFavorite: bool(statement, 13)
            )
        }
    }

    private func loadPlaylists(songsByID: [Song.ID: Song]) throws -> [Playlist] {
        let rows = try readRows(
            """
            SELECT id, name, description, createdAt, updatedAt
            FROM playlists
            ORDER BY sortOrder ASC
            """
        ) { statement in
            (
                id: uuid(statement, 0),
                name: text(statement, 1),
                description: text(statement, 2),
                createdAt: date(statement, 3),
                updatedAt: date(statement, 4)
            )
        }

        var playlists: [Playlist] = []
        for row in rows {
            let entries = try loadPlaylistEntries(playlistID: row.id)
            let playlistSongs = entries.compactMap { songsByID[$0.songId] }
            playlists.append(
                Playlist(
                    id: row.id,
                    name: row.name,
                    description: row.description,
                    songs: playlistSongs,
                    songEntries: entries,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt
                )
            )
        }
        return playlists
    }

    private func loadPlaylistEntries(playlistID: UUID) throws -> [PlaylistSong] {
        var statement = try prepare(
            """
            SELECT songId, addedAt, sortOrder
            FROM playlist_songs
            WHERE playlistId = ?
            ORDER BY sortOrder ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        bindText(playlistID.uuidString, to: statement, at: 1)

        var entries: [PlaylistSong] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            entries.append(
                PlaylistSong(
                    songId: uuid(statement, 0),
                    addedAt: date(statement, 1),
                    sortOrder: int(statement, 2)
                )
            )
        }
        return entries
    }

    private func loadLibrarySources() throws -> [MusicLibrarySource] {
        try readRows(
            """
            SELECT id, name, path, lastScanned
            FROM library_sources
            ORDER BY name COLLATE NOCASE ASC
            """
        ) { statement in
            MusicLibrarySource(
                id: uuid(statement, 0),
                name: text(statement, 1),
                path: text(statement, 2),
                isScanning: false,
                lastScanned: optionalDate(statement, 3)
            )
        }
    }

    private func loadBlockedSongs() throws -> [BlockedSong] {
        try readRows(
            """
            SELECT id, sourceId, path, title, artist, album, blockedAt
            FROM blocked_songs
            ORDER BY blockedAt DESC
            """
        ) { statement in
            BlockedSong(
                id: uuid(statement, 0),
                sourceId: uuid(statement, 1),
                path: text(statement, 2),
                title: text(statement, 3),
                artist: text(statement, 4),
                album: text(statement, 5),
                blockedAt: date(statement, 6)
            )
        }
    }

    private func saveSongs(_ songs: [Song]) throws {
        var statement = try prepare(
            """
            INSERT INTO songs (id, sourceId, path, title, artist, album, duration, coverPath, genre, year, dateAdded, playCount, lastPlayedAt, isFavorite)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { sqlite3_finalize(statement) }

        for song in songs {
            sqlite3_reset(statement)
            bindText(song.id.uuidString, to: statement, at: 1)
            bindOptionalText(song.librarySourceId?.uuidString, to: statement, at: 2)
            bindText(song.path, to: statement, at: 3)
            bindText(song.title, to: statement, at: 4)
            bindText(song.artist, to: statement, at: 5)
            bindText(song.album, to: statement, at: 6)
            bindDouble(song.duration, to: statement, at: 7)
            bindOptionalText(song.coverPath, to: statement, at: 8)
            bindOptionalText(song.genre, to: statement, at: 9)
            bindOptionalInt(song.year, to: statement, at: 10)
            bindDate(song.dateAdded, to: statement, at: 11)
            bindInt(song.playCount, to: statement, at: 12)
            bindOptionalDate(song.lastPlayedAt, to: statement, at: 13)
            bindBool(song.isFavorite, to: statement, at: 14)
            try stepDone(statement)
        }
    }

    private func savePlaylists(_ playlists: [Playlist]) throws {
        var playlistStatement = try prepare(
            """
            INSERT INTO playlists (id, name, description, createdAt, updatedAt, sortOrder)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        )
        defer { sqlite3_finalize(playlistStatement) }

        var entryStatement = try prepare(
            """
            INSERT INTO playlist_songs (playlistId, songId, addedAt, sortOrder)
            VALUES (?, ?, ?, ?)
            """
        )
        defer { sqlite3_finalize(entryStatement) }

        for (playlistIndex, playlist) in playlists.enumerated() {
            sqlite3_reset(playlistStatement)
            bindText(playlist.id.uuidString, to: playlistStatement, at: 1)
            bindText(playlist.name, to: playlistStatement, at: 2)
            bindText(playlist.description, to: playlistStatement, at: 3)
            bindDate(playlist.createdAt, to: playlistStatement, at: 4)
            bindDate(playlist.updatedAt, to: playlistStatement, at: 5)
            bindInt(playlistIndex, to: playlistStatement, at: 6)
            try stepDone(playlistStatement)

            let entries = normalizedEntries(for: playlist)
            for entry in entries {
                sqlite3_reset(entryStatement)
                bindText(playlist.id.uuidString, to: entryStatement, at: 1)
                bindText(entry.songId.uuidString, to: entryStatement, at: 2)
                bindDate(entry.addedAt, to: entryStatement, at: 3)
                bindInt(entry.sortOrder, to: entryStatement, at: 4)
                try stepDone(entryStatement)
            }
        }
    }

    private func saveLibrarySources(_ sources: [MusicLibrarySource]) throws {
        var statement = try prepare(
            """
            INSERT INTO library_sources (id, name, path, lastScanned)
            VALUES (?, ?, ?, ?)
            """
        )
        defer { sqlite3_finalize(statement) }

        for source in sources {
            sqlite3_reset(statement)
            bindText(source.id.uuidString, to: statement, at: 1)
            bindText(source.name, to: statement, at: 2)
            bindText(source.path, to: statement, at: 3)
            bindOptionalDate(source.lastScanned, to: statement, at: 4)
            try stepDone(statement)
        }
    }

    private func saveBlockedSongs(_ songs: [BlockedSong]) throws {
        var statement = try prepare(
            """
            INSERT INTO blocked_songs (id, sourceId, path, title, artist, album, blockedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        )
        defer { sqlite3_finalize(statement) }

        for song in songs {
            sqlite3_reset(statement)
            bindText(song.id.uuidString, to: statement, at: 1)
            bindText(song.sourceId.uuidString, to: statement, at: 2)
            bindText(song.path, to: statement, at: 3)
            bindText(song.title, to: statement, at: 4)
            bindText(song.artist, to: statement, at: 5)
            bindText(song.album, to: statement, at: 6)
            bindDate(song.blockedAt, to: statement, at: 7)
            try stepDone(statement)
        }
    }

    private func userVersion() throws -> Int32 {
        try readRows("PRAGMA user_version") { statement in
            sqlite3_column_int(statement, 0)
        }.first ?? 0
    }

    private func resetSchema() throws {
        try execute("DROP TABLE IF EXISTS playlist_songs")
        try execute("DROP TABLE IF EXISTS playlists")
        try execute("DROP TABLE IF EXISTS play_history")
        try execute("DROP TABLE IF EXISTS songs")
        try execute("DROP TABLE IF EXISTS blocked_songs")
        try execute("DROP TABLE IF EXISTS library_sources")
    }

    private func normalizedEntries(for playlist: Playlist) -> [PlaylistSong] {
        let entriesByID = Dictionary(uniqueKeysWithValues: playlist.songEntries.map { ($0.songId, $0) })
        return playlist.songs.enumerated().map { index, song in
            var entry = entriesByID[song.id] ?? PlaylistSong(songId: song.id, addedAt: playlist.updatedAt, sortOrder: index)
            entry.sortOrder = index
            return entry
        }
    }

    private func execute(_ sql: String) throws {
        guard let database else { throw StoreError.missingDatabase }
        if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
            throw StoreError.statementFailed(databaseErrorMessage)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        guard let database else { throw StoreError.missingDatabase }
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            throw StoreError.statementFailed(databaseErrorMessage)
        }
        return statement
    }

    private func readRows<T>(_ sql: String, mapper: (OpaquePointer?) -> T) throws -> [T] {
        var statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(mapper(statement))
        }
        return rows
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        if sqlite3_step(statement) != SQLITE_DONE {
            throw StoreError.statementFailed(databaseErrorMessage)
        }
    }

    private var databaseErrorMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "未知错误"
        }
        return String(cString: message)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
    optionalText(statement, index) ?? ""
}

private func optionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let value = sqlite3_column_text(statement, index)
    else { return nil }
    return String(cString: value)
}

private func uuid(_ statement: OpaquePointer?, _ index: Int32) -> UUID {
    UUID(uuidString: text(statement, index)) ?? UUID()
}

private func optionalUUID(_ statement: OpaquePointer?, _ index: Int32) -> UUID? {
    optionalText(statement, index).flatMap(UUID.init(uuidString:))
}

private func int(_ statement: OpaquePointer?, _ index: Int32) -> Int {
    Int(sqlite3_column_int64(statement, index))
}

private func bool(_ statement: OpaquePointer?, _ index: Int32) -> Bool {
    sqlite3_column_int64(statement, index) != 0
}

private func optionalInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return int(statement, index)
}

private func double(_ statement: OpaquePointer?, _ index: Int32) -> Double {
    sqlite3_column_double(statement, index)
}

private func date(_ statement: OpaquePointer?, _ index: Int32) -> Date {
    Date(timeIntervalSince1970: double(statement, index))
}

private func optionalDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return date(statement, index)
}

private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

private func bindOptionalText(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    bindText(value, to: statement, at: index)
}

private func bindInt(_ value: Int, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

private func bindBool(_ value: Bool, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_int64(statement, index, value ? 1 : 0)
}

private func bindOptionalInt(_ value: Int?, to statement: OpaquePointer?, at index: Int32) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    bindInt(value, to: statement, at: index)
}

private func bindDouble(_ value: Double, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_double(statement, index, value)
}

private func bindDate(_ value: Date, to statement: OpaquePointer?, at index: Int32) {
    bindDouble(value.timeIntervalSince1970, to: statement, at: index)
}

private func bindOptionalDate(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    bindDate(value, to: statement, at: index)
}
