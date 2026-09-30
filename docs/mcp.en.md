# MCP Playback Control

English | [简体中文](mcp.md)

Mint Player can optionally expose a local MCP server so MCP clients on the same Mac, such as agents, can search your library and control playback and the upcoming queue. The server is off by default and listens only on the loopback address `127.0.0.1`.

## Enabling the Server

1. Open the **MCP** section in Settings.
2. Turn on **Enable MCP**.
3. Keep Mint Player running, then enter the address shown in Settings in your local MCP client.

Turning the server off or quitting the app makes that address unavailable immediately.

## Access Token

An access token is required by default: use **Copy Token** and configure an `Authorization: Bearer <token>` request header in your client. If you turn off **Require Access Token**, any local process can control playback without the header.

The token is stored in the current user's app data directory without accessing Keychain: the directory uses `0700` permissions and the token file uses `0600`. Processes running as the same system user may still read the file.

After upgrading from a version that stored the token in Keychain, copy the new token and update your MCP client; the same applies after rotating the token.

## Port

The default ports are `49431` for Release and `49432` for Debug. You can change the port in Settings; valid values are 1024–65535, and changing it restarts the service. If a port is occupied, Settings shows the startup error so you can choose another port and retry.

## Available Tools

| Ability | Tool behavior |
| --- | --- |
| Search | Searches songs, artists, and albums |
| Playback | Plays a single song, or plays an artist or album sequentially or shuffled |
| Read | Reads the current song's full lyrics, playback state, and queue |
| Control | Play, pause, previous, next, volume, and position |
| Queue | Adds an upcoming song, and removes, moves, clears, or restores the upcoming queue |

Songs are selected by library UUID, while artists and albums use IDs from search results. Tool results do not include local audio paths.
