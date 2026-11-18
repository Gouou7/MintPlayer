# MCP Client Setup

MCP clients on the same Mac can connect to Mint Player over stdio. The client can connect and discover tools while Mint Player is closed. The first tool call opens the player automatically.

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

MCP is off by default. When enabled, it requires an access token by default. If you turn off **Require Access Token**, you can omit `MINTPLAYER_MCP_TOKEN`. Processes running under your macOS account can then use all MCP tools without a token. After rotating the token, update your client configuration and reconnect.

Mint Player stores the token in its application database. Keep actual tokens in your personal client configuration and out of the repository.

## Startup and shutdown

When Mint Player is already open, tool calls control the same player instance. Mint Player can keep playing after you close the client. Turning off MCP in the app settings blocks tool calls.

## MCP tools

See the [MCP Tool Reference](mcp-tools.en.md) for the full list, arguments, and examples.
