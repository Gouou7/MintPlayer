# Mint Player Development Guide

## 全局要求

- 不要擅自修改或向 README.md 写入内容，每次写入要请求许可
- README_zh.md 是 README.md 的中文翻译，两者同步更新
- 每次提交的 commit 消息需要向用户确认，同意后再提交

## Project Overview

Mint Player is a native macOS local music player built with an Xcode project.

- **Language**: Swift 5
- **UI framework**: SwiftUI; complex song and artist lists bridge to AppKit `NSTableView`
- **Audio framework**: AVFoundation
- **System media controls**: MediaPlayer / Now Playing / Remote Command Center
- **Desktop interop**: AppKit for folder picking, Finder integration, native tables, and small window/sidebar behaviors
- **State management**: `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`
- **Persistence**: SQLite and `UserDefaults`; artwork cache files live under Application Support
- **Build tool**: Xcode project
- **Minimum OS**: macOS 26.0

The repository root does not currently contain `Package.swift`, third-party dependency manifests, test targets, or lint configuration.
There is no `package.json`, `go.mod`, `requirements.txt`, `Makefile`, or custom build script.
If a `Reference Proj.` directory exists, it is reference material only and is not the Mint Player build entry point.

## Directory Structure

```text
MintPlayer/
├── MintPlayer/
│   ├── App/              # `MintPlayerApp` and `Info.plist`
│   ├── Models/           # `Song`, `Album`, `Artist`, `Playlist`, and related models
│   ├── Stores/           # `MusicLibrary`, `SettingsManager`
│   ├── Services/         # `AudioPlayer`, `NowPlayingService`
│   └── Views/
│       ├── Root/         # Main window layout and NavigationSplitView routing
│       ├── Sidebar/      # Sidebar, selection model, playlist editing
│       ├── Library/      # Songs, Albums, Artists, Favorites, and folder views
│       ├── Player/       # Player bar, queue popover, and lyrics window
│       ├── Settings/     # Settings window
│       └── Shared/       # Theme, search field, artwork, empty states, shared modifiers
├── MintPlayer.xcodeproj/ # The only build entry point
├── README.md             # English user-facing overview
├── README_zh.md          # Chinese user-facing overview
├── CHANGELOG.md          # Keep a Changelog release notes
├── VERSION               # Current version
└── AGENTS.md             # This file
```

## Coding Standards

### Naming

- Use PascalCase for types, enums, and protocols, such as `MusicLibrary` and `LibrarySelection`.
- Use camelCase for methods, variables, and properties, such as `play(song:)` and `currentSong`.
- Name SwiftUI view files after their primary type, such as `PlayerBarView.swift`.
- Place files by responsibility: models in `Models/`, state in `Stores/`, platform services in `Services/`, and UI components in the matching `Views/` subdirectory.
- Use clear `Native...View` names or dedicated helper names for AppKit bridge types, and keep them in `Views/Shared/` or the relevant feature directory.

### Formatting

- Use 4 spaces for indentation.
- Put opening braces `{` on the declaration line.
- Leave a blank line between methods.
- Avoid unrelated formatting churn.

### Types And State

- Prefer Swift type inference; add explicit types for complex generics, closures, or public APIs when useful.
- Prefer `guard let` or `if let` for optionals. Avoid force unwraps.
- Use SwiftUI state properties in views; inject cross-page shared state through `@EnvironmentObject`.
- Do not spread AppKit objects through ordinary SwiftUI views. Keep AppKit usage in narrow `NSViewRepresentable`, helper, or service boundaries.
- Keep the main sidebar aligned with native `NavigationSplitView` and system Liquid Glass behavior. Do not replace the system sidebar with a custom painted background.
- Song, playlist, Folder, and detail-page song lists currently depend on `NativeSongTableView`; preserve native `NSTableView` selection, multi-selection, double-click, menus, and drag behavior when changing interactions.
- Albums and Artists browsing pages should remain responsive grids, with at least four primary items visible per row at the minimum window width.
- Artists use a drill-in structure across artist browsing, artist detail, and album detail. Do not reintroduce a permanent three-column artist layout.
- Search fields live in the top-right page toolbar by default, use native macOS search controls, and their search semantics should follow the current page or detail level.
- When the main sidebar is hidden, the top toolbar uses a native segmented tab bar for the primary library destinations. Preserve the system sidebar and toolbar behavior instead of replacing them with custom-painted chrome.
- The bottom player bar is a fixed-width, centered floating Liquid Glass control and must intercept clicks so events do not pass through to content underneath.
- Playback counts are recorded only after a song has actually played for 60% of its duration. Do not count clicks, seeks, or short previews as plays.
- Full-screen lyrics scrolling uses a narrow AppKit `NSScrollView` bridge for deterministic animated offsets. Keep SwiftUI as the source of truth for lyric content and highlighting; use the bridge only for scroll-position control.
- Full-screen lyrics artwork and blurred backgrounds should crossfade directly between old and new images. Do not clear to a black or empty intermediate frame during normal covered-song transitions.
- Songs without artwork should show the gray `rectangle.stack.fill` placeholder and gray lyrics background rather than reusing the previous song's artwork or blurred background.
- Playback pause and resume use short audio fade out/in transitions in `AudioPlayer`. Preserve user volume separately from temporary fade volume.

### Comments

- Keep comments concise and only add them for complex logic, platform constraints, or non-obvious behavior.
- Do not add comments that merely restate the code.

## Common Commands

### Dependencies

No third-party dependency installation is required. Open `MintPlayer.xcodeproj` to develop.

### Inspect Project

```sh
xcodebuild -list -project MintPlayer.xcodeproj
```

### Build

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" build
```

Build for macOS explicitly:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

Build a specific configuration:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

### Clean Build

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build
```

### Run

For daily development, open `MintPlayer.xcodeproj`, select the `MintPlayer` scheme, and press `Command + R`.

### Test

There is currently no test target. After changes, run at least one clean build and perform manual regression based on the affected area.

### Lint

There is currently no SwiftLint or other lint configuration. Do not assume a lint command exists.

### Build Configuration

Debug builds use `Mint Player Debug.app`, `dev.govo.mintplayer.debug`, the `MintPlayer-Debug` Application Support directory, and the `mintPlayer.debug` preferences prefix.
Release builds use `Mint Player.app` and the release configuration directory.

## Testing Strategy

- **Build verification**: Run `xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build` after code changes.
- **Manual regression**: Cover folder import, music scanning, Songs double-click playback, Albums/Artists playback, playlist editing, queue, volume, Settings, and system media controls as relevant.
- **Table interaction regression**: For `NativeSongTableView` or `NativeArtistTableView` changes, verify normal click, Shift range selection, Command multi-selection, double-click playback, context menus, trailing action menus, column resizing, and dragging to playlist / Finder.
- **Layout regression**: For main window, sidebar, Artists, or Albums detail changes, verify narrow window behavior, sidebar width, Scroll Edge Effect, floating player bar, and search field placement.
- **Playback regression**: For `AudioPlayer` changes, verify pause fade-out, resume fade-in, stop, seek, previous/next, natural track completion, repeat, shuffle, volume changes, Now Playing state, and play count qualification.
- **Lyrics regression**: For full-screen lyrics changes, verify synced scrolling, highlighted-line position, seek by tapping lyrics, missing artwork placeholders, artwork/background crossfades, and no dark intermediate frame during track changes.
- **Unit tests**: There is currently no test target. Confirm with the user before creating one for complex pure logic.
- **Integration/e2e**: There are no automated integration or e2e tests. Use local manual verification for UI and playback behavior.

## Git Workflow

- Work on the current branch by default. Do not create commits unless the user explicitly asks.
- Suggested branch names: `feature/<name>`, `bugfix/<name>`, `refactor/<name>`.
- Use English commit messages in Conventional Commits style, for example `feat: improve playback controls`.
- Suggested types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
- Before committing, run `git status --short` and confirm there are no unrelated files, personal environment files, or build outputs staged.

## Agent Constraints

- Do not automatically commit, push, or create pull requests unless explicitly asked.
- Read existing code and documentation before making changes; do not invent architecture from assumptions.
- After changes, run the smallest useful verification command. The default is the clean `xcodebuild` command above.
- Ask the user before decisions that affect architecture or data compatibility when the answer cannot be discovered locally.
- Do not revert or overwrite user changes. In a dirty worktree, touch only task-related files.
- Do not introduce a new package manager entry, test target, or script unless explicitly requested.
- Do not write internal documentation maintenance into `CHANGELOG.md`.
- Do not leave fake or placeholder features in the UI. Remove them or ask the user if backend logic is missing.
- Do not hide native control issues with timers, forced view rebuilds, or close-and-reopen workarounds. Understand the SwiftUI/AppKit boundary first, then use the narrowest bridge.

## Security Notes

- Do not commit secrets, tokens, `.env` files, personal paths, user music files, or real user data.
- Do not hardcode absolute paths. Use user-selected URLs or project-relative paths for file access.
- Do not commit Xcode user state, DerivedData, `.xcuserstate`, local caches, or build products.
- Folder deletion should only remove the app's library reference and internal index entries. It must not delete user files from disk.
- Keep permission requests minimal and limited to local music management.

## Versioning

- Versions follow Semantic Versioning and are recorded in `VERSION` and Xcode `MARKETING_VERSION`.
- `Info.plist` should receive the short version through Xcode `MARKETING_VERSION`; Settings About reads from the bundle and appends `-Debug` or `-Release`.
- Before release, sync `VERSION`, Xcode `MARKETING_VERSION`, `CHANGELOG.md`, and the Git tag.
- `CHANGELOG.md` follows Keep a Changelog and keeps an `Unreleased` section at the top.

### Release Checklist

- Move user-facing changes from `Unreleased` into the new version section with the release date.
- Keep internal documentation-only maintenance out of `CHANGELOG.md` unless it affects users or contributors.
- Confirm `VERSION`, Xcode `MARKETING_VERSION`, the release heading, and the Git tag all use the same version.
- Leave unrelated local files such as reference projects, Xcode user state, DerivedData, and build products unstaged.
