# MCP Playback Control

MCP clients on the same Mac can use stdio to search the Mint Player library and control playback and the upcoming queue. The client can connect and discover tools while Mint Player is closed. The first tool call opens the player automatically.

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

## Access token

MCP is off by default and requires an access token once enabled. If you turn off **Require Access Token**, omit `MINTPLAYER_MCP_TOKEN`. Processes running under your macOS account can then control playback without a token. After rotating the token, update your client configuration and reconnect.

Mint Player stores the token in its application database. Keep actual tokens in your personal client configuration and out of the repository.

## Startup and shutdown

When Mint Player is already open, tool calls control the same player instance. Mint Player can keep playing after you close the client. Turning off MCP in the app settings blocks tool calls.

## Available tools

| Capability | Tool behavior |
| --- | --- |
| Search | Search for songs, artists, and albums |
| Play | Play a song or play an artist or album in order or shuffled |
| Read | Read the current song's full lyrics, playback state, and upcoming queue |
| Control | Resume, pause, go to the previous or next song, set volume, or seek |
| Queue | Add, remove, reorder, and clear upcoming songs, or undo the last clear |

Select songs by library UUID and select artists and albums by ID from search results. Tool results omit local audio paths.
