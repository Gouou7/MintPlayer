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

    static let tools: [Tool] = [
        tool("search_songs", "Find songs by title, artist, or album.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true),
        tool("search_artists", "Find artists and their IDs for playback.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true),
        tool("search_albums", "Find albums and their IDs for playback.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true),
        tool("get_playback_state", "Get the current playback state.", [:], readOnly: true),
        tool("get_queue", "Get the current song and ordered upcoming songs.", [:], readOnly: true),
        tool("get_current_lyrics", "Get the full displayed lyrics of the current song, using the app's lyrics settings.", [:], readOnly: true),
        tool("play_song", "Play a song now and preserve the existing upcoming songs.", [
            "song_id": ["type": "string", "format": "uuid"]
        ], required: ["song_id"]),
        tool("play_artist", "Replace the queue with an artist's songs in order or shuffled, and start playing.", [
            "artist_id": ["type": "string"],
            "mode": ["type": "string", "enum": ["sequential", "shuffle"]]
        ], required: ["artist_id", "mode"]),
        tool("play_album", "Replace the queue with an album's songs in track order or shuffled, and start playing.", [
            "album_id": ["type": "string"],
            "mode": ["type": "string", "enum": ["sequential", "shuffle"]]
        ], required: ["album_id", "mode"]),
        tool("pause", "Pause playback without toggling it.", [:]),
        tool("resume", "Resume playback without toggling it.", [:]),
        tool("next", "Play the next song.", [:]),
        tool("previous", "Restart the current song or play the previous song.", [:]),
        tool("set_volume", "Set playback volume from 0 to 1.", [
            "value": ["type": "number", "minimum": 0, "maximum": 1]
        ], required: ["value"]),
        tool("seek", "Seek to a position in seconds.", [
            "seconds": ["type": "number", "minimum": 0]
        ], required: ["seconds"]),
        tool("queue_song", "Place a library song next or at the end of the queue.", [
            "song_id": ["type": "string", "format": "uuid"],
            "position": ["type": "string", "enum": ["next", "end"]]
        ], required: ["song_id", "position"]),
        tool("remove_upcoming", "Remove a song from the upcoming queue.", [
            "song_id": ["type": "string", "format": "uuid"]
        ], required: ["song_id"]),
        tool("move_upcoming", "Move an upcoming song before another; omit before_song_id to move it to the end.", [
            "song_id": ["type": "string", "format": "uuid"],
            "before_song_id": ["type": "string", "format": "uuid"]
        ], required: ["song_id"]),
        tool("clear_upcoming", "Clear upcoming songs and retain an undo snapshot.", [:]),
        tool("undo_clear_upcoming", "Undo the most recent queue clear if still available.", [:])
    ]

    private static func tool(
        _ name: String,
        _ description: String,
        _ properties: [String: Value],
        required: [String] = [],
        readOnly: Bool = false
    ) -> Tool {
        .init(
            name: name,
            description: description,
            inputSchema: .object([
                "type": "object",
                "properties": .object(properties),
                "required": .array(required.map(Value.string)),
                "additionalProperties": false
            ]),
            annotations: .init(readOnlyHint: readOnly, destructiveHint: false, openWorldHint: false)
        )
    }

    func call(_ params: CallTool.Parameters) async -> CallTool.Result {
        let arguments = params.arguments ?? [:]
        switch params.name {
        case "search_songs":
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

        case "search_artists":
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

        case "search_albums":
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

        case "get_playback_state": return result(playbackState)
        case "get_queue": return result(queueState)
        case "get_current_lyrics":
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

        case "play_song":
            guard let song = resolvedSong(arguments) else { return songError(arguments) }
            audioPlayer.playImmediatelyPreservingUpcoming(song)
            if let playbackError = audioPlayer.playbackError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)

        case "play_artist":
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

        case "play_album":
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

        case "pause":
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            audioPlayer.pause()
            return result(playbackState)
        case "resume":
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            audioPlayer.resume()
            if let playbackError = audioPlayer.playbackError { return error("playback_failed", playbackError) }
            return result(playbackState)
        case "next":
            guard !audioPlayer.queue.isEmpty else { return error("queue_empty", "The playback queue is empty.") }
            let previousError = audioPlayer.playbackError
            audioPlayer.next()
            if let playbackError = audioPlayer.playbackError, playbackError != previousError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)
        case "previous":
            guard !audioPlayer.queue.isEmpty else { return error("queue_empty", "The playback queue is empty.") }
            let previousError = audioPlayer.playbackError
            audioPlayer.previous()
            if let playbackError = audioPlayer.playbackError, playbackError != previousError {
                return error("playback_failed", playbackError)
            }
            return result(playbackState)
        case "set_volume":
            guard let value = number(arguments["value"]), value.isFinite, (0...1).contains(value) else {
                return error("invalid_argument", "value must be a number from 0 to 1.")
            }
            audioPlayer.setVolume(Float(value))
            return result(playbackState)
        case "seek":
            guard audioPlayer.currentSong != nil else { return error("no_current_song", "No song is selected.") }
            guard let seconds = number(arguments["seconds"]), seconds.isFinite, seconds >= 0 else {
                return error("invalid_argument", "seconds must be a nonnegative number.")
            }
            audioPlayer.seek(to: seconds)
            return result(playbackState)
        case "queue_song":
            guard let song = resolvedSong(arguments) else { return songError(arguments) }
            guard let position = arguments["position"]?.stringValue, ["next", "end"].contains(position) else {
                return error("invalid_argument", "position must be next or end.")
            }
            if position == "next" { audioPlayer.playNext(song) }
            else { audioPlayer.addToQueue(song) }
            return result(queueState)
        case "remove_upcoming":
            guard let id = songID(arguments) else { return error("invalid_argument", "song_id must be a UUID.") }
            guard audioPlayer.upcomingSongs.contains(where: { $0.id == id }) else {
                return error("song_not_upcoming", "The song is not in the upcoming queue.")
            }
            audioPlayer.removeUpcomingSongs(withIDs: [id])
            return result(queueState)
        case "move_upcoming":
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
        case "clear_upcoming":
            audioPlayer.clearQueue()
            return result(queueState)
        case "undo_clear_upcoming":
            guard audioPlayer.canUndoClearQueue else { return error("undo_unavailable", "There is no queue clear to undo.") }
            audioPlayer.undoClearQueue()
            return result(queueState)
        default:
            return error("unknown_tool", "Unknown tool: \(params.name)")
        }
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
        arguments["song_id"]?.stringValue.flatMap(UUID.init(uuidString:))
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
