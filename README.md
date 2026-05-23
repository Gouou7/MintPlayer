# Mint Player

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

A beautiful, Apple Music-like local music player for macOS.

## Highlights

- Familiar, polished interface with Liquid Glass styling and dedicated Songs, Albums, and Artists views.
- Local-first library management: import folders without changing your original file structure.
- Flexible organization with custom playlists, a Favorites list, blocked songs, and play count tracking.
- Lyrics window with local `.lrc` support. Lyrics files must share the same name and folder as the audio file. Timestamped lyrics sync with playback; plain text lyrics are shown as static text.
- Native macOS playback controls, including queue, shuffle, repeat, volume, media keys, and Now Playing integration.
- Separate Debug and Release app names and storage, so test data does not pollute the release library.

## Screenshots

![Mint Player main window](docs/images/MintPlayer0.3.0Main.png)
![Mint Player lyrics window](docs/images/MintPlayer0.3.0FullScreen.png)

## Roadmap

- ✅ Basic playback and library management
- ⬜ More detailed interaction and animation polish
- ⬜ Audio fade in/out transitions
- ⬜ Dynamic blurred backgrounds
- ⬜ Unified main and lyrics experience
- ⬜ Online lyrics search

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
