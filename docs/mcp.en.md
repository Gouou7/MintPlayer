# MCP Guide

[简体中文](mcp.md) · [Tool reference](#tool-reference)

Starting with `v0.18.0`, MCP clients on the same Mac can connect to Mint Player over stdio. With MCP enabled, clients can discover tools while Mint Player is closed. The first tool call opens the player automatically.

## Configure the client

1. Turn on **Enable MCP** in Mint Player's MCP settings.
2. Click **Copy Command Path** and use the full path as the client's stdio command. It points to `mintplayer-mcp` inside the app bundle.
3. Click **Copy Token** and set `MINTPLAYER_MCP_TOKEN` in the command's environment. Reconnect the client to apply the configuration.

For clients that use the `mcpServers` format, use the following example. Replace the example command and token with the values copied from Settings.

```json
{
  "mcpServers": {
    "mint-player": {
      "command": "/Applications/Mint Player.app/Contents/MacOS/mintplayer-mcp",
      "env": {
        "MINTPLAYER_MCP_TOKEN": "REPLACE_WITH_COPIED_TOKEN"
      }
    }
  }
}
```

In Codex, put the same command and environment variable under `[mcp_servers.mint-player]` and `[mcp_servers.mint-player.env]` in your user configuration.

When upgrading, replace the previous HTTP URL configuration with the stdio command. You can keep your existing token. Use the command and token from the corresponding app bundle for Debug and Release. Update the command path if you move or rename the app.

## Verify the connection

Call `get_playback_state` in your client with no arguments. If the call returns playback state, the connection is working. Listing tools is possible before the access token is checked. If the call returns `mcp_unauthorized`, copy the token again from the corresponding app's settings, update `MINTPLAYER_MCP_TOKEN`, and reconnect the client.

## Access token

MCP is off by default. When enabled, it requires an access token by default. If you turn off **Require Access Token**, you can omit `MINTPLAYER_MCP_TOKEN`. Processes running under your macOS account can then use all MCP tools without a token. After rotating the token, update your client configuration and reconnect.

Mint Player stores the token in its application database. Keep actual tokens in your personal client configuration and out of the repository.

## Startup and shutdown

When Mint Player is already open, tool calls control the same player instance. Mint Player can keep playing after you close the client. Turning off MCP in the app settings blocks tool calls.

## Tool reference

Discover Mint Player tools with MCP `tools/list` and invoke them with `tools/call`. Arguments are required unless marked optional. Failed calls return `isError: true` with a `code` and `message`.

Song objects use library UUIDs and include `id`, `title`, `artist`, `album`, and `duration` in seconds. Tool results omit local audio paths.

### Library search

Each search takes `query` and an optional `limit`. A query must contain 1 to 200 characters after trimming whitespace. The default limit is 20 and the allowed range is 1 to 50.

| Tool | Result |
| --- | --- |
| `search_songs` | Searches titles, artists, and albums, then returns `songs`. Use a result's `id` to play it, add it to a playlist, or block it. |
| `search_artists` | Searches artist names and returns `artists`, each with `id`, `name`, `album_count`, and `song_count`. |
| `search_albums` | Searches album titles or artist names and returns `albums`, each with `id`, `title`, `artist`, `year`, and `song_count`. |

### Playback and lyrics

| Tool | Arguments | Behavior |
| --- | --- | --- |
| `get_playback_state` | None | Returns the current playback state. |
| `get_current_lyrics` | None | Returns the current song and its full lyrics using the app's lyrics file, encoding, and timing settings. |
| `play_song` | `song_id` | Plays one song immediately and preserves the existing upcoming songs. |
| `play_artist` | `artist_id`, `mode` | Replaces the queue with the artist's songs and starts playback. |
| `play_album` | `album_id`, `mode` | Replaces the queue with the album's songs and starts playback. Sequential mode follows album track order. |
| `pause` | None | Pauses playback. |
| `resume` | None | Resumes playback. |
| `next` | None | Advances to the next song. |
| `previous` | None | Restarts the current song or plays the previous one. |
| `set_volume` | `value` | Sets volume from 0 to 1. |
| `seek` | `seconds` | Seeks to a nonnegative position in seconds. |

Use IDs from search results for `artist_id` and `album_id`. Pass `sequential` or `shuffle` as `mode`.

Playback state contains `current_song`, `is_playing`, `current_time`, `duration`, `volume`, `shuffle_enabled`, and `repeat_enabled`. All tools in this section except `get_current_lyrics` return it. `current_song` is `null` when no song is selected. Time and duration are in seconds. The lyrics result contains `song`, `format` (`synced` or `plain_text`), and `lyrics`. Synced lyrics also include `lines` with `time` in seconds and `text` for each line.

### Upcoming queue

| Tool | Arguments | Behavior |
| --- | --- | --- |
| `get_queue` | None | Reads the current song and the upcoming songs in playback order. |
| `queue_song` | `song_id`, `position` | Queues a song. Use `next` or `end` as the position. |
| `remove_upcoming` | `song_id` | Removes an upcoming song. |
| `move_upcoming` | `song_id`, `before_song_id` (optional) | Moves an upcoming song before another. Omit the target to move it to the end. |
| `clear_upcoming` | None | Clears the upcoming songs and keeps an undo snapshot. |
| `undo_clear_upcoming` | None | Restores the last cleared queue if the snapshot is still available. |

These tools return `current_song`, `upcoming_songs`, and `can_undo_clear`. `current_song` is `null` when no song is selected.

### Playlist management

| Tool | Arguments | Result and behavior |
| --- | --- | --- |
| `list_playlists` | `offset`, `limit` (both optional) | Returns `playlists` in sidebar order. |
| `get_playlist` | `playlist_id`, `offset` (optional), `limit` (optional) | Returns `playlist` and its `songs` in saved order. |
| `create_playlist` | `name`, `description` (optional) | Creates an empty playlist and returns `playlist`. The name must be nonempty after trimming whitespace. UUIDs distinguish playlists with the same name. |
| `add_playlist_songs` | `playlist_id`, `song_ids` | Appends songs in input order, skipping songs already present. If any song is missing from the library, the entire request fails. Returns `playlist` and `added_count`. |
| `remove_playlist_songs` | `playlist_id`, `song_ids` | Removes songs from the playlist and skips those already absent. Returns `playlist` and `removed_count`. |
| `move_playlist_song` | `playlist_id`, `song_id`, `before_song_id` (optional) | Moves a song before another or to the end if the target is omitted. Both song IDs must belong to the playlist. Returns `playlist`. |

A playlist summary contains `id`, `name`, `description`, and `song_count`. Pass a nonempty array of song UUIDs as `song_ids`. To edit playlist names or descriptions or delete a playlist, use the app.

`list_playlists`, `get_playlist`, and `list_blocked_songs` support pagination. The default `offset` is 0 and `limit` defaults to 50 with an allowed range of 1 to 100. Each paginated result contains `total` and `next_offset`, which is `null` on the last page.

To create and fill a playlist:

1. Use `search_songs` and keep the song IDs from the results.
2. Call `create_playlist` with arguments such as `{"name":"Late Night"}` and keep the returned `playlist.id`.
3. Call `add_playlist_songs` with the `playlist_id` and the `song_ids` in your desired order. Use `get_playlist` to see the saved order.

### Blocked songs

| Tool | Arguments | Result and behavior |
| --- | --- | --- |
| `block_song` | `song_id` | Blocks one song associated with a library folder and returns `blocked_song`. |
| `list_blocked_songs` | `offset`, `limit` (both optional) | Returns `blocked_songs`, newest first. |
| `unblock_song` | `blocked_song_id` | Removes the blocked record and rescans its library folder. Returns the removed record's `blocked_song_id`. |

A blocked record has its own `id`, along with `title`, `artist`, `album`, and an ISO 8601 `blocked_at` timestamp. Blocking removes the track from the library and playlists. The upcoming queue refreshes with the library. The current song stays selected until the player changes tracks, and the local file stays on disk. An individually imported song with no associated library folder stays in the library, and the call returns `song_source_unavailable`.

For example, pass a song's `id` from `search_songs` to `block_song`. To restore it later, get the blocked record from `list_blocked_songs` and pass that record's `id` as `blocked_song_id` to `unblock_song`. If the file is available, the song returns to the library after the rescan. Add it back to any playlists as needed.
