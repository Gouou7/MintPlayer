import MCP

enum MCPToolCatalog {
    enum Name: String {
        case searchSongs = "search_songs"
        case searchArtists = "search_artists"
        case searchAlbums = "search_albums"

        case getPlaybackState = "get_playback_state"
        case getCurrentLyrics = "get_current_lyrics"
        case playSong = "play_song"
        case playArtist = "play_artist"
        case playAlbum = "play_album"
        case pause
        case resume
        case next
        case previous
        case setVolume = "set_volume"
        case seek

        case getQueue = "get_queue"
        case queueSong = "queue_song"
        case removeUpcoming = "remove_upcoming"
        case moveUpcoming = "move_upcoming"
        case clearUpcoming = "clear_upcoming"
        case undoClearUpcoming = "undo_clear_upcoming"

        case listPlaylists = "list_playlists"
        case getPlaylist = "get_playlist"
        case createPlaylist = "create_playlist"
        case addPlaylistSongs = "add_playlist_songs"
        case removePlaylistSongs = "remove_playlist_songs"
        case movePlaylistSong = "move_playlist_song"

        case blockSong = "block_song"
        case listBlockedSongs = "list_blocked_songs"
        case unblockSong = "unblock_song"
    }

    static let pageDefaultLimit = 50
    static let pageMaximumLimit = 100

    static let tools = searchTools + playbackTools + queueTools + playlistTools + blockingTools

    private static let searchTools = [
        tool(.searchSongs, "Find songs by title, artist, or album.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true),
        tool(.searchArtists, "Find artists and their IDs for playback.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true),
        tool(.searchAlbums, "Find albums and their IDs for playback.", [
            "query": ["type": "string"], "limit": ["type": "integer", "minimum": 1, "maximum": 50]
        ], required: ["query"], readOnly: true)
    ]

    private static let playbackTools = [
        tool(.getPlaybackState, "Get the current playback state.", [:], readOnly: true),
        tool(.getCurrentLyrics, "Get the full displayed lyrics of the current song, using the app's lyrics settings.", [:], readOnly: true),
        tool(.playSong, "Play a song now and preserve the existing upcoming songs.", [
            "song_id": uuid
        ], required: ["song_id"]),
        tool(.playArtist, "Replace the queue with an artist's songs in order or shuffled, and start playing.", [
            "artist_id": ["type": "string"],
            "mode": ["type": "string", "enum": ["sequential", "shuffle"]]
        ], required: ["artist_id", "mode"]),
        tool(.playAlbum, "Replace the queue with an album's songs in track order or shuffled, and start playing.", [
            "album_id": ["type": "string"],
            "mode": ["type": "string", "enum": ["sequential", "shuffle"]]
        ], required: ["album_id", "mode"]),
        tool(.pause, "Pause playback without toggling it.", [:]),
        tool(.resume, "Resume playback without toggling it.", [:]),
        tool(.next, "Play the next song.", [:]),
        tool(.previous, "Restart the current song or play the previous song.", [:]),
        tool(.setVolume, "Set playback volume from 0 to 1.", [
            "value": ["type": "number", "minimum": 0, "maximum": 1]
        ], required: ["value"]),
        tool(.seek, "Seek to a position in seconds.", [
            "seconds": ["type": "number", "minimum": 0]
        ], required: ["seconds"])
    ]

    private static let queueTools = [
        tool(.getQueue, "Get the current song and ordered upcoming songs.", [:], readOnly: true),
        tool(.queueSong, "Place a library song next or at the end of the queue.", [
            "song_id": uuid,
            "position": ["type": "string", "enum": ["next", "end"]]
        ], required: ["song_id", "position"]),
        tool(.removeUpcoming, "Remove a song from the upcoming queue.", [
            "song_id": uuid
        ], required: ["song_id"]),
        tool(.moveUpcoming, "Move an upcoming song before another; omit before_song_id to move it to the end.", [
            "song_id": uuid,
            "before_song_id": uuid
        ], required: ["song_id"]),
        tool(.clearUpcoming, "Clear upcoming songs and retain an undo snapshot.", [:]),
        tool(.undoClearUpcoming, "Undo the most recent queue clear if still available.", [:])
    ]

    private static let playlistTools = [
        tool(.listPlaylists, "List saved playlists in sidebar order, with their IDs and track counts.", pageProperties, readOnly: true),
        tool(.getPlaylist, "Get a saved playlist and a page of tracks in their saved order.", [
            "playlist_id": uuid, "offset": pageOffset, "limit": pageLimit
        ], required: ["playlist_id"], readOnly: true),
        tool(.createPlaylist, "Create an empty saved playlist and return its ID.", [
            "name": ["type": "string", "minLength": 1],
            "description": ["type": "string"]
        ], required: ["name"]),
        tool(.addPlaylistSongs, "Append library songs to a saved playlist in input order, skipping songs already present.", [
            "playlist_id": uuid, "song_ids": songIDs
        ], required: ["playlist_id", "song_ids"], idempotent: true),
        tool(.removePlaylistSongs, "Remove songs from a saved playlist without removing them from the library.", [
            "playlist_id": uuid, "song_ids": songIDs
        ], required: ["playlist_id", "song_ids"], destructive: true, idempotent: true),
        tool(.movePlaylistSong, "Move a saved playlist song before another song. Omit before_song_id to move it to the end.", [
            "playlist_id": uuid, "song_id": uuid, "before_song_id": uuid
        ], required: ["playlist_id", "song_id"], destructive: true, idempotent: true)
    ]

    private static let blockingTools = [
        tool(.blockSong, "Block one song from a library folder and remove it from the library and playlists. Keeps the audio file.", [
            "song_id": uuid
        ], required: ["song_id"], destructive: true),
        tool(.listBlockedSongs, "List blocked song records newest first. Use a record ID to unblock a song.", pageProperties, readOnly: true),
        tool(.unblockSong, "Remove a blocked song record and rescan its library folder to restore the track if available.", [
            "blocked_song_id": uuid
        ], required: ["blocked_song_id"], destructive: true)
    ]

    private static let uuid: Value = ["type": "string", "format": "uuid"]
    private static let songIDs: Value = ["type": "array", "items": uuid, "minItems": 1]
    private static let pageOffset: Value = ["type": "integer", "minimum": 0, "default": 0]
    private static let pageLimit: Value = [
        "type": "integer", "minimum": 1, "maximum": .int(pageMaximumLimit), "default": .int(pageDefaultLimit)
    ]
    private static let pageProperties = ["offset": pageOffset, "limit": pageLimit]

    private static let libraryToolInputs = Dictionary(uniqueKeysWithValues: (playlistTools + blockingTools).map { tool in
        let properties = tool.inputSchema.objectValue?["properties"]?.objectValue ?? [:]
        return (tool.name, Set(properties.keys))
    })

    static func libraryArgumentKeys(for name: Name) -> Set<String>? {
        libraryToolInputs[name.rawValue]
    }

    private static func tool(
        _ name: Name,
        _ description: String,
        _ properties: [String: Value],
        required: [String] = [],
        readOnly: Bool = false,
        destructive: Bool = false,
        idempotent: Bool? = nil
    ) -> Tool {
        .init(
            name: name.rawValue,
            description: description,
            inputSchema: .object([
                "type": "object",
                "properties": .object(properties),
                "required": .array(required.map(Value.string)),
                "additionalProperties": false
            ]),
            annotations: .init(readOnlyHint: readOnly, destructiveHint: destructive, idempotentHint: idempotent, openWorldHint: false)
        )
    }
}
