import MCP

enum MCPToolCatalog {
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
}
