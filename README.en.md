# Mint Player

English | [简体中文](README.md)

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

Mint Player is a native macOS local music player with the familiar Liquid Glass design.

## Features

- Plays common audio files and recursively scans subfolders when importing music folders
- Browses tracks by album or artist and supports custom playlists
- Lets you favorite or block songs and tracks play counts
- Displays scrolling lyrics

## Screenshots

![Mint Player main window](docs/images/MintPlayer0.8.0Main.png)

![Mint Player sidebar window](docs/images/MintPlayer0.8.0MainSidebar.png)

![Mint Player lyrics window](docs/images/MintPlayer0.8.0MainLyric.png)

## Build

### Requirements

- macOS 26.0 or later
- Xcode with the macOS 26 SDK

### Quick Start

1. Open `MintPlayer.xcodeproj` in Xcode.
2. Select the `MintPlayer` scheme and `My Mac`.
3. Press `Command + R` to run the app.
4. Open Settings and add a local music folder.
5. Use the sidebar to browse Songs, Albums, Artists, Favorites, playlists, or library folders.

### Command Line

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

> [!NOTE]
> Debug builds use a separate app name, bundle identifier, Application Support directory, and preferences prefix from Release builds.

## License

This project is licensed under GPLv3. See `LICENSE`.

## Disclaimer

> [!WARNING]
> This app was built with agent-assisted development. Review the code before using it.

> [!WARNING]
> Use this app at your own risk. The author is not responsible for issues caused by using it.
