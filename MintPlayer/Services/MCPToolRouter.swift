import Foundation
import MCP

@MainActor
final class MCPToolRouter {
    private let audioPlayer: AudioPlayer
    private let musicLibrary: MusicLibrary
    private let settings: SettingsManager

    init(audioPlayer: AudioPlayer, musicLibrary: MusicLibrary, settings: SettingsManager) {
        self.audioPlayer = audioPlayer
        self.musicLibrary = musicLibrary
        self.settings = settings
    }

    func call(_ params: CallTool.Parameters) async -> CallTool.Result {
        let arguments = params.arguments ?? [:]
        guard let name = MCPToolCatalog.Name(rawValue: params.name) else {
            return error("unknown_tool", "Unknown tool: \(params.name)")
        }
        if let keys = MCPToolCatalog.libraryArgumentKeys(for: name) {
            guard musicLibrary.isLibraryReady else {
                return localizedError("library_unavailable", .databaseUnavailable)
            }
            guard keys.isSuperset(of: arguments.keys) else {
                return localizedError("invalid_argument", .mcpUnexpectedArguments)
            }
        }
        switch name {
        // MARK: - Library search

        case .searchSongs:
            guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
            guard let query = arguments["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else { return error("invalid_argument", "query must not be empty.") }
            guard query.count <= 200 else { return error("invalid_argument", "query must be at most 200 characters.") }
            let limit: Int
            if let rawLimit = arguments["limit"] {
                guard let value = rawLimit.intValue else { return error("invalid_argument", "limit must be an integer.") }
                limit = value
            } else {
                limit = 20
            }
            guard (1...50).contains(limit) else { return error("invalid_argument", "limit must be between 1 and 50.") }
            let snapshot = musicLibrary.songs.map(MCPTrack.init)
            let matches = await Task.detached(priority: .userInitiated) {
                snapshot.filter { track in
                    track.title.localizedStandardContains(query)
                        || track.artist.localizedStandardContains(query)
                        || track.album.localizedStandardContains(query)
                }
                .sorted { lhs, rhs in
                    let leftTitle = lhs.title.localizedStandardContains(query)
                    let rightTitle = rhs.title.localizedStandardContains(query)
                    if leftTitle != rightTitle { return leftTitle }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                .prefix(limit)
                .map(\.value)
            }.value
            return result(["songs": .array(matches)])

        case .searchArtists:
            guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
            guard let (query, limit) = searchArguments(arguments) else {
                return error("invalid_argument", "query must be 1 to 200 characters and limit must be 1 to 50.")
            }
            let snapshot = musicLibrary.artistSummaries.map(MCPArtist.init)
            let matches = await Task.detached(priority: .userInitiated) {
                snapshot.filter { $0.name.localizedStandardContains(query) }
                    .prefix(limit).map(\.value)
            }.value
            return result(["artists": .array(matches)])

        case .searchAlbums:
            guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
            guard let (query, limit) = searchArguments(arguments) else {
                return error("invalid_argument", "query must be 1 to 200 characters and limit must be 1 to 50.")
            }
            let snapshot = musicLibrary.albumSummaries.map(MCPAlbum.init)
            let matches = await Task.detached(priority: .userInitiated) {
                snapshot.filter { $0.title.localizedStandardContains(query) || $0.artist.localizedStandardContains(query) }
                    .prefix(limit).map(\.value)
            }.value
            return result(["albums": .array(matches)])

        // MARK: - Playback and lyrics

        case .getPlaybackState: return result(playbackState)
        case .getCurrentLyrics:
            guard let song = audioPlayer.currentSong else { return error("no_current_song", "No song is selected.") }
            let fileURL = settings.lyricsFileURL(for: song)
            let timingOffset = settings.lyricsTimingOffset(for: song)
            let encoding = settings.lyricsEncoding(for: song)
            let lyrics = await Task.detached(priority: .userInitiated) {
                LyricsService.loadLyrics(for: song, fileURL: fileURL, timingOffset: timingOffset, encoding: encoding)
            }.value
            switch lyrics {
            case .synced(let lines):
                return result([
                    "song": MCPTrack(song).value,
                    "format": "synced",
                    "lyrics": .string(lines.map(\.text).joined(separator: "\n")),
                    "lines": .array(lines.map { ["time": .double($0.time), "text": .string($0.text)] as Value })
                ])
            case .plainText(let lines):
                guard !lines.isEmpty else { return error("lyrics_empty", "The lyrics file has no displayable text.") }
                return result(["song": MCPTrack(song).value, "format": "plain_text", "lyrics": .string(lines.joined(separator: "\n"))])
            case .missing:
                return error("lyrics_missing", "No lyrics file is available for the current song.")
            case .failed:
                return error("lyrics_unavailable", "Could not load lyrics for the current song.")
            case .loading:
                return error("lyrics_unavailable", "Lyrics are not available yet.")
            }

        case .playSong:
            guard let song = resolvedSong(arguments) else { return songError(arguments) }
            audioPlayer.playImmediatelyPreservingUpcoming(song)
            if let playbackError = audioPlayer.playbackError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)

        case .playArtist:
            guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
            guard let id = arguments["artist_id"]?.stringValue, !id.isEmpty else {
                return error("invalid_argument", "artist_id is required.")
            }
            guard let mode = playbackMode(arguments) else { return error("invalid_argument", "mode must be sequential or shuffle.") }
            guard let artist = musicLibrary.artistSummaries.first(where: { $0.id == id }) else {
                return error("artist_not_found", "The artist is no longer in the library.")
            }
            let songs = musicLibrary.songsForArtistPlayback(artist)
            guard !songs.isEmpty else { return error("artist_empty", "The artist has no available songs.") }
            if mode == "shuffle" { audioPlayer.shuffle(songs: songs) }
            else { audioPlayer.play(songs: songs) }
            if let playbackError = audioPlayer.playbackError { return error("playback_failed", playbackError) }
            guard audioPlayer.isPlaying else { return error("playback_failed", "Playback did not start.") }
            return result(playbackState)

        case .playAlbum:
            guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
            guard let id = arguments["album_id"]?.stringValue, !id.isEmpty else {
                return error("invalid_argument", "album_id is required.")
            }
            guard let mode = playbackMode(arguments) else { return error("invalid_argument", "mode must be sequential or shuffle.") }
            guard let album = musicLibrary.albumSummaries.first(where: { $0.id == id }) else {
                return error("album_not_found", "The album is no longer in the library.")
            }
            let songs = musicLibrary.songs(forAlbum: album)
            guard !songs.isEmpty else { return error("album_empty", "The album has no available songs.") }
            if mode == "shuffle" { audioPlayer.shuffle(songs: songs) }
            else { audioPlayer.play(songs: songs) }
            if let playbackError = audioPlayer.playbackError { return error("playback_failed", playbackError) }
            guard audioPlayer.isPlaying else { return error("playback_failed", "Playback did not start.") }
            return result(playbackState)

        case .pause:
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            audioPlayer.pause()
            return result(playbackState)
        case .resume:
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            audioPlayer.resume()
            if let playbackError = audioPlayer.playbackError { return error("playback_failed", playbackError) }
            return result(playbackState)
        case .next:
            guard !audioPlayer.queue.isEmpty else { return error("queue_empty", "The playback queue is empty.") }
            let previousError = audioPlayer.playbackError
            audioPlayer.next()
            if let playbackError = audioPlayer.playbackError, playbackError != previousError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)
        case .previous:
            guard !audioPlayer.queue.isEmpty else { return error("queue_empty", "The playback queue is empty.") }
            let previousError = audioPlayer.playbackError
            audioPlayer.previous()
            if let playbackError = audioPlayer.playbackError, playbackError != previousError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)
        case .setVolume:
            guard let value = number(arguments["value"]), value.isFinite, (0...1).contains(value) else {
                return error("invalid_argument", "value must be a number from 0 to 1.")
            }
            audioPlayer.setVolume(Float(value))
            return result(playbackState)
        case .seek:
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            guard let seconds = number(arguments["seconds"]), seconds.isFinite, seconds >= 0 else {
                return error("invalid_argument", "seconds must be a nonnegative number.")
            }
            audioPlayer.seek(to: seconds)
            return result(playbackState)

        // MARK: - Upcoming queue

        case .getQueue: return result(queueState)
        case .queueSong:
            guard let song = resolvedSong(arguments) else { return songError(arguments) }
            guard let position = arguments["position"]?.stringValue, ["next", "end"].contains(position) else {
                return error("invalid_argument", "position must be next or end.")
            }
            if position == "next" { audioPlayer.playNext(song) }
            else { audioPlayer.addToQueue(song) }
            return result(queueState)
        case .removeUpcoming:
            guard let id = songID(arguments) else { return error("invalid_argument", "song_id must be a UUID.") }
            guard audioPlayer.upcomingSongs.contains(where: { $0.id == id }) else {
                return error("song_not_upcoming", "The song is not in the upcoming queue.")
            }
            audioPlayer.removeUpcomingSongs(withIDs: [id])
            return result(queueState)
        case .moveUpcoming:
            guard let id = songID(arguments) else { return error("invalid_argument", "song_id must be a UUID.") }
            let target: UUID?
            if let raw = arguments["before_song_id"], !raw.isNull {
                guard let value = raw.stringValue, let parsed = UUID(uuidString: value) else {
                    return error("invalid_argument", "before_song_id must be a UUID.")
                }
                target = parsed
            } else { target = nil }
            guard audioPlayer.moveUpcomingSong(id, before: target) else {
                return error("song_not_upcoming", "Both songs must be in the upcoming queue.")
            }
            return result(queueState)
        case .clearUpcoming:
            audioPlayer.clearQueue()
            return result(queueState)
        case .undoClearUpcoming:
            guard audioPlayer.canUndoClearQueue else { return error("undo_unavailable", "There is no queue clear to undo.") }
            audioPlayer.undoClearQueue()
            return result(queueState)

        // MARK: - Playlists

        case .listPlaylists:
            guard let output = page(musicLibrary.playlists, arguments: arguments, key: "playlists", value: playlistValue) else {
                return pageError()
            }
            return result(output)

        case .getPlaylist:
            guard let playlistID = uuid(arguments["playlist_id"]) else { return invalidUUID("playlist_id") }
            guard let playlist = musicLibrary.playlists.first(where: { $0.id == playlistID }) else {
                return localizedError("playlist_not_found", .playlistNotFound)
            }
            guard var output = page(playlist.songs, arguments: arguments, key: "songs", value: { MCPTrack($0).value }) else {
                return pageError()
            }
            output["playlist"] = playlistValue(playlist)
            return result(output)

        case .createPlaylist:
            guard let playlistName = arguments["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !playlistName.isEmpty else {
                return localizedError("invalid_argument", .mcpInvalidPlaylistName)
            }
            guard let description = (arguments["description"] ?? .string("")).stringValue else {
                return localizedError("invalid_argument", .mcpInvalidPlaylistDescription)
            }
            guard let playlist = musicLibrary.createPlaylist(
                name: playlistName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            ) else {
                return localizedError("library_save_failed", .mcpLibrarySaveFailed)
            }
            return result(["playlist": playlistValue(playlist)])

        case .addPlaylistSongs, .removePlaylistSongs:
            return editPlaylistSongs(arguments, adding: name == .addPlaylistSongs)

        case .movePlaylistSong:
            guard let playlistID = uuid(arguments["playlist_id"]) else { return invalidUUID("playlist_id") }
            guard let songID = songID(arguments) else { return invalidUUID("song_id") }
            let targetID = uuid(arguments["before_song_id"])
            if arguments["before_song_id"] != nil, targetID == nil {
                return invalidUUID("before_song_id")
            }
            guard let index = musicLibrary.playlists.firstIndex(where: { $0.id == playlistID }) else {
                return localizedError("playlist_not_found", .playlistNotFound)
            }
            let playlist = musicLibrary.playlists[index]
            guard playlist.songs.contains(where: { $0.id == songID }),
                  targetID.map({ target in playlist.songs.contains { $0.id == target } }) ?? true else {
                return localizedError("song_not_in_playlist", .mcpSongNotInPlaylist)
            }
            guard musicLibrary.movePlaylistSong(songID, in: playlistID, before: targetID) else {
                return localizedError("library_save_failed", .mcpLibrarySaveFailed)
            }
            return result(["playlist": playlistValue(musicLibrary.playlists[index])])

        // MARK: - Blocked songs

        case .blockSong:
            guard let songID = songID(arguments) else { return invalidUUID("song_id") }
            guard musicLibrary.songs.contains(where: { $0.id == songID }) else {
                return localizedError("song_not_found", .mcpSongNotFound)
            }
            guard let records = musicLibrary.blockSongs(withIds: [songID]) else {
                return localizedError("library_save_failed", .mcpLibrarySaveFailed)
            }
            guard let record = records[songID] else {
                return localizedError("song_source_unavailable", .mcpSongSourceUnavailable)
            }
            return result(["blocked_song": blockedSongValue(record)])

        case .listBlockedSongs:
            let records = musicLibrary.blockedSongs.sorted { lhs, rhs in
                if lhs.blockedAt != rhs.blockedAt { return lhs.blockedAt > rhs.blockedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let output = page(records, arguments: arguments, key: "blocked_songs", value: blockedSongValue) else {
                return pageError()
            }
            return result(output)

        case .unblockSong:
            guard let id = uuid(arguments["blocked_song_id"]) else { return invalidUUID("blocked_song_id") }
            guard let record = musicLibrary.blockedSongs.first(where: { $0.id == id }) else {
                return localizedError("blocked_song_not_found", .mcpBlockedSongNotFound)
            }
            guard musicLibrary.unblockSong(record) else {
                return localizedError("library_save_failed", .mcpLibrarySaveFailed)
            }
            return result(["blocked_song_id": .string(id.uuidString)])
        }
    }

    private func editPlaylistSongs(_ arguments: [String: Value], adding: Bool) -> CallTool.Result {
        guard let playlistID = uuid(arguments["playlist_id"]) else { return invalidUUID("playlist_id") }
        guard let values = arguments["song_ids"]?.arrayValue, !values.isEmpty else {
            return localizedError("invalid_argument", .mcpInvalidSongIDs)
        }
        let ids = values.compactMap { uuid($0) }
        guard ids.count == values.count else { return localizedError("invalid_argument", .mcpInvalidSongIDs) }
        guard let index = musicLibrary.playlists.firstIndex(where: { $0.id == playlistID }) else {
            return localizedError("playlist_not_found", .playlistNotFound)
        }

        let count: Int?
        if adding {
            let songsByID = Dictionary(uniqueKeysWithValues: musicLibrary.songs.map { ($0.id, $0) })
            let songs = ids.compactMap { songsByID[$0] }
            guard songs.count == ids.count else { return localizedError("song_not_found", .mcpSongNotFound) }
            count = musicLibrary.addSongsToPlaylist(songs, playlistId: playlistID)
        } else {
            count = musicLibrary.removeSongsFromPlaylist(songIds: Set(ids), playlistId: playlistID)
        }
        guard let count else { return localizedError("library_save_failed", .mcpLibrarySaveFailed) }
        let countKey = adding ? "added_count" : "removed_count"
        return result([
            "playlist": playlistValue(musicLibrary.playlists[index]),
            countKey: .int(count)
        ])
    }

    private func playlistValue(_ playlist: Playlist) -> Value {
        [
            "id": .string(playlist.id.uuidString),
            "name": .string(playlist.name),
            "description": .string(playlist.description),
            "song_count": .int(playlist.songs.count)
        ]
    }

    private func blockedSongValue(_ song: BlockedSong) -> Value {
        [
            "id": .string(song.id.uuidString),
            "title": .string(song.title),
            "artist": .string(song.artist),
            "album": .string(song.album),
            "blocked_at": .string(song.blockedAt.ISO8601Format())
        ]
    }

    private func page<Item>(
        _ items: [Item], arguments: [String: Value], key: String, value: (Item) -> Value
    ) -> [String: Value]? {
        guard let offset = (arguments["offset"] ?? .int(0)).intValue, offset >= 0,
              let limit = (arguments["limit"] ?? .int(MCPToolCatalog.pageDefaultLimit)).intValue,
              (1...MCPToolCatalog.pageMaximumLimit).contains(limit) else { return nil }
        let entries = items.dropFirst(offset).prefix(limit)
        let nextOffset = offset + entries.count
        return [
            key: .array(entries.map(value)),
            "total": .int(items.count),
            "next_offset": nextOffset < items.count ? .int(nextOffset) : .null
        ]
    }

    private func pageError() -> CallTool.Result {
        localizedError("invalid_argument", .mcpInvalidPage, MCPToolCatalog.pageMaximumLimit)
    }

    private func invalidUUID(_ field: String) -> CallTool.Result {
        localizedError("invalid_argument", .mcpInvalidUUID, field)
    }

    private func resolvedSong(_ arguments: [String: Value]) -> Song? {
        guard musicLibrary.isLibraryReady, let id = songID(arguments) else { return nil }
        return musicLibrary.songs.first { $0.id == id }
    }

    private func songError(_ arguments: [String: Value]) -> CallTool.Result {
        guard musicLibrary.isLibraryReady else { return error("library_unavailable", "The music library is unavailable.") }
        guard songID(arguments) != nil else { return error("invalid_argument", "song_id must be a UUID.") }
        return error("song_not_found", "The song is no longer in the library.")
    }

    private func songID(_ arguments: [String: Value]) -> UUID? {
        uuid(arguments["song_id"])
    }

    private func uuid(_ value: Value?) -> UUID? {
        value?.stringValue.flatMap(UUID.init(uuidString:))
    }

    private func searchArguments(_ arguments: [String: Value]) -> (String, Int)? {
        guard let query = arguments["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty, query.count <= 200 else { return nil }
        let limit: Int
        if let rawLimit = arguments["limit"] {
            guard let value = rawLimit.intValue else { return nil }
            limit = value
        } else {
            limit = 20
        }
        guard (1...50).contains(limit) else { return nil }
        return (query, limit)
    }

    private func playbackMode(_ arguments: [String: Value]) -> String? {
        guard let mode = arguments["mode"]?.stringValue, ["sequential", "shuffle"].contains(mode) else { return nil }
        return mode
    }

    private func number(_ value: Value?) -> Double? {
        value?.doubleValue ?? value?.intValue.map(Double.init)
    }

    private var playbackState: [String: Value] {
        [
            "current_song": audioPlayer.currentSong.map { MCPTrack($0).value } ?? .null,
            "is_playing": .bool(audioPlayer.isPlaying),
            "current_time": .double(audioPlayer.currentTime),
            "duration": .double(audioPlayer.duration),
            "volume": .double(Double(audioPlayer.volume)),
            "shuffle_enabled": .bool(audioPlayer.isShuffleEnabled),
            "repeat_enabled": .bool(audioPlayer.isRepeatEnabled)
        ]
    }

    private var queueState: [String: Value] {
        [
            "current_song": audioPlayer.currentSong.map { MCPTrack($0).value } ?? .null,
            "upcoming_songs": .array(audioPlayer.upcomingSongs.map { MCPTrack($0).value }),
            "can_undo_clear": .bool(audioPlayer.canUndoClearQueue)
        ]
    }

    private func result(_ object: [String: Value]) -> CallTool.Result {
        let value = Value.object(object)
        let text = (try? String(data: JSONEncoder().encode(value), encoding: .utf8)) ?? "{}"
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: Optional.some(value), isError: false)
    }

    private func error(_ code: String, _ message: String) -> CallTool.Result {
        let value: Value = ["code": .string(code), "message": .string(message)]
        let text = (try? String(data: JSONEncoder().encode(value), encoding: .utf8)) ?? message
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: Optional.some(value), isError: true)
    }

    private func localizedError(_ code: String, _ key: L10n.Key, _ arguments: CVarArg...) -> CallTool.Result {
        let message = settings.text(key)
        return error(code, arguments.isEmpty ? message : String(format: message, arguments: arguments))
    }
}

private struct MCPTrack: Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: Double

    init(_ song: Song) {
        id = song.id
        title = song.title
        artist = song.artist
        album = song.album
        duration = song.duration
    }

    var value: Value {
        [
            "id": .string(id.uuidString),
            "title": .string(title),
            "artist": .string(artist),
            "album": .string(album),
            "duration": .double(duration)
        ]
    }
}

private struct MCPArtist: Sendable {
    let id: String
    let name: String
    let albumCount: Int
    let songCount: Int

    init(_ artist: ArtistSummary) {
        id = artist.id
        name = artist.name
        albumCount = artist.albumCount
        songCount = artist.songCount
    }

    var value: Value {
        ["id": .string(id), "name": .string(name), "album_count": .int(albumCount), "song_count": .int(songCount)]
    }
}

private struct MCPAlbum: Sendable {
    let id: String
    let title: String
    let artist: String
    let year: Int
    let songCount: Int

    init(_ album: AlbumSummary) {
        id = album.id
        title = album.title
        artist = album.artist
        year = album.year
        songCount = album.songCount
    }

    var value: Value {
        ["id": .string(id), "title": .string(title), "artist": .string(artist), "year": .int(year), "song_count": .int(songCount)]
    }
}
