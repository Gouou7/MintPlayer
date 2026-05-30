# Mint Player

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

A native macOS local music player for organizing and playing your own music library.

## Highlights

- Familiar, polished interface with Liquid Glass styling and dedicated Songs, Albums, Artists, Favorites, playlist, and folder views.
- Local-first library management: import folders without changing your original file structure.
- Flexible song organization with custom playlists, a Favorites list, blocked songs, and play count tracking.
- Local lyrics display with `.lrc` file support.

## Screenshots

![Mint Player main window](docs/images/MintPlayer0.3.0Main.png)
![Mint Player lyrics window](docs/images/MintPlayer0.3.0FullScreen.png)

## Roadmap

- ✅ Basic playback and library management
- ✅ More detailed interaction and animation polish
- ✅ Audio fade in/out transitions
- ✅ Standalone lyrics window with synced local lyrics
- ✅ Favorites, blocked songs, play count tracking, and restored playback sessions
- ⬜ Online lyrics search
- ⬜ Online artist image search

## Known Issues

- ❌ The top `scrollEdgeEffectStyle` in the main window may randomly fail.

## Build

### Requirements

- macOS 26.0 or later
- Xcode with the macOS 26 SDK

### Run With Xcode

1. Open `MintPlayer.xcodeproj` in Xcode.
2. Select the `MintPlayer` scheme and `My Mac`.
3. Press `Command + R`.
4. Add a local music folder in Settings.

### Command Line Build

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

> [!TIP]
> - Debug builds generate `Mint Player Debug.app`.
> - Release builds generate `Mint Player.app`.

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

## License

This project is licensed under GPLv3. See `LICENSE`.

## Disclaimer

> [!WARNING]
> This app was built with agent-assisted development. Review the code before using it.

> [!WARNING]
> Use this app at your own risk. The author is not responsible for any issues caused by using it.
