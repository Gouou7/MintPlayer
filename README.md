# Mint Player

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

Mint Player is a native macOS music player for managing and playing a local music library. It is built for users who keep their own audio files on disk and want a local-first library, playlist, album, artist, and lyrics experience without changing the original folder structure.

## Features

- Local library import from user-selected folders.
- Playback for common local audio files, including `mp3`, `m4a`, `wav`, `aac`, `flac`, `ogg`, `aiff`, and `aif`.
- Songs, Albums, Artists, Favorites, playlists, and library-folder views.
- Native song tables with selection, sorting, column customization, context menus, drag support, and double-click playback.
- Album and artist browsing with artwork thumbnails and animated artwork transitions into detail pages.
- Standalone lyrics window with synced local `.lrc` lyrics, smooth scrolling, optional inactive-line blur, and remembered window size.
- Play queue, shuffle, repeat, previous/next controls, playback restoration, and Dock menu controls.
- Favorites, blocked songs, qualified play-count tracking, and persisted library state.
- System media integration through Now Playing and remote media controls.
- Settings for theme, language, lyrics blur, library folders, rescanning, and blocked-song management.

## Screenshots

![Mint Player main window](docs/images/MintPlayer0.8.0Main.png)

![Mint Player sidebar window](docs/images/MintPlayer0.8.0MainSidebar.png)

![Mint Player lyrics window](docs/images/MintPlayer0.8.0MainLyric.png)


## Requirements

- macOS 26.0 or later
- Xcode with the macOS 26 SDK
- Local audio files stored in folders you can select from the app

## Quick Start

1. Open `MintPlayer.xcodeproj` in Xcode.
2. Select the `MintPlayer` scheme and `My Mac`.
3. Press `Command + R`.
4. Open Settings and add a local music folder.
5. Use the sidebar to browse Songs, Albums, Artists, Favorites, playlists, or library folders.

## Library Management

Mint Player indexes selected folders and stores app metadata separately under Application Support. Removing a library folder inside the app removes the app's reference and internal index entries; it does not delete files from disk.

Rescanning a library folder updates metadata and artwork for the indexed files. If a song is blocked, it stays hidden from normal library views until unblocked from Settings.

## Lyrics

Mint Player supports local `.lrc` lyrics. The standalone lyrics window follows playback, highlights the active line, and can seek when lyrics are tapped. Inactive lyric blur can be turned on or off in Settings.

## Build

Inspect the Xcode project:

```sh
xcodebuild -list -project MintPlayer.xcodeproj
```

Build the default scheme:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

Build a specific configuration:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

Debug builds use a separate app name, bundle identifier, Application Support directory, and preferences prefix from Release builds.

## Development Notes

This repository uses an Xcode project as the only build entry point. It does not currently include a Swift Package manifest, third-party dependency manifest, test target, lint configuration, or custom build script.

For implementation constraints, architecture notes, and agent-specific maintenance rules, see `AGENTS.md`.

## Known Issues

- The main window top `scrollEdgeEffectStyle` effect may fail intermittently.

## License

This project is licensed under GPLv3. See `LICENSE`.

## Disclaimer

> [!WARNING]
> This app was built with agent-assisted development. Review the code before using it.

> [!WARNING]
> Use this app at your own risk. The author is not responsible for issues caused by using it.
