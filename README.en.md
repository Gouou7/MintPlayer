# Mint Player

English | [简体中文](README.md)

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

Mint Player is a native macOS local music player for macOS 26, using the Liquid Glass design language. It scans the local folders you choose to build its library and only reads audio files; it never modifies, moves, or deletes them.

## Requirements

- macOS 26.0 or later
- Xcode with the macOS 26 SDK, if you build the app yourself

## Features

- Plays common audio files and scans subfolders recursively when importing folders
- Browses tracks by album or artist, and supports custom playlists
- Favorites or blocks songs, and keeps play counts
- Shows lyrics inside the main window or in a separate window, with LRC scrolling highlights and timing adjustment
- Can optionally expose a local MCP server so agents can search songs and control playback and the upcoming queue

## Screenshots

![Mint Player main window](docs/images/Main.png)

![Mint Player sidebar window](docs/images/MainSidebar.png)

![Mint Player lyrics window](docs/images/MainLyric.png)

## Usage

### Getting Started

1. Open Settings and add a local music folder; you can also press `⌘⇧O` or drag a folder into the window.
2. Use the sidebar to browse Songs, Albums, Artists, Favorites, playlists, or library folders.

### Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘P` | Play or pause |
| `⌘←` / `⌘→` | Previous / next track |
| `⌘F` | Focus the search field |
| `⌘⇧O` | Import a folder |

### Language and Theme

Settings let you follow the system or pick English or Simplified Chinese, and follow the system, light, or dark appearance.

### System Integration

Playback can also be controlled from macOS Now Playing, media keys, Control Center, and the Dock menu.

### Data Locations

The library database and cover cache live in the app's folder under your Application Support directory, and preferences live in the system preferences store. Debug and Release use separate, isolated locations and do not share a library; removing this data only clears records and caches inside the app and never touches your audio files.

## MCP Playback Control

Mint Player can optionally expose a local MCP server so MCP clients on the same Mac, such as agents, can search your library and control playback and the upcoming queue. The server is off by default, listens only on `127.0.0.1`, and requires an access token by default.

See [MCP Playback Control](docs/mcp.en.md) for setup, tokens, ports, and available tools.

## Tech Stack

- Swift 5 and SwiftUI, with AppKit bridges for native controls
- AVFoundation for audio playback and MediaPlayer for system media information
- SQLite for library records and `UserDefaults` for preferences

## Build

Open `MintPlayer.xcodeproj` in Xcode, select the `MintPlayer` scheme and `My Mac`, then press `Command + R`. The first build resolves SwiftPM dependencies and needs network access.

### Command Line

Build the Debug configuration:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme MintPlayer -configuration Debug -destination 'platform=macOS' build
```

> [!NOTE]
> Debug builds use a separate app name, bundle identifier, Application Support directory, and preferences prefix from Release builds.

## FAQ

- **No songs after adding a folder**: make sure the folder contains supported audio files; subfolders are scanned recursively; blocked songs do not appear in the library.
- **Debug and Release do not share a library**: they use separate, isolated storage locations. This is expected.
- **No lyrics**: lyrics come from an LRC file with the same name as the audio file. You can also pick another file and text encoding in the lyrics view.
- **The MCP client cannot connect**: check that the server is on, the address and port match, and the token is current. See [MCP Playback Control](docs/mcp.en.md).

## License

This project is licensed under GPLv3. See [LICENSE](LICENSE).

## Disclaimer

> [!WARNING]
> This app was built with agent-assisted development; review the code before using it. Use the app at your own risk — the author is not responsible for issues caused by using it.
