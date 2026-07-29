# Mint Player Development Guide

## Repository Structure

```text
MintPlayer/
├── MintPlayer/
│   ├── App/              # App entry, app delegate, configuration, Info.plist
│   ├── Models/           # Song, album, artist, playlist, source, and theme models
│   ├── Stores/           # Observable app state such as MusicLibrary and SettingsManager
│   ├── Services/         # Audio playback, SQLite persistence, lyrics parsing, Now Playing
│   └── Views/
│       ├── Root/         # Main window, split view, toolbar, collapsed sidebar tab bar
│       ├── Sidebar/      # Sidebar sections, rows, selection, playlist editing, drops
│       ├── Library/      # Songs, Albums, Artists, Favorites, and folder/detail views
│       ├── Player/       # Player bar, queue, lyrics window, lyrics scrolling
│       ├── Settings/     # Settings window and library management UI
│       └── Shared/       # Theme, search, artwork, native tables, empty states, controls
├── MintPlayer.xcodeproj/ # Only build entry point
├── docs/                 # Screenshots and focused implementation/maintenance notes
├── README.md             # English user/developer overview
├── README_zh.md          # Chinese translation of README.md
├── CHANGELOG.md          # Keep a Changelog release notes
├── VERSION               # Current release version
└── AGENTS.md             # Concise agent rules and documentation entry point
```

## Coding Standards

### Naming

- Use PascalCase for types, enums, and protocols.
- Use camelCase for methods, variables, properties, and bindings.
- Name SwiftUI view files after their primary type.
- Use `Native...View` or focused helper names for AppKit bridges.
- Keep model, store, service, and view files in their matching directories.

### Formatting

- Use 4 spaces for indentation.
- Put opening braces on the declaration line.
- Leave a blank line between methods.
- Avoid unrelated formatting churn and large mechanical rewrites.

### State And Types

- Prefer Swift type inference unless explicit types clarify complex generics, closures, or public APIs.
- Prefer `guard let` and `if let`; avoid force unwraps.
- Use SwiftUI state wrappers for view-local state and `@EnvironmentObject` for shared app state.
- Keep AppKit objects inside representables, coordinators, helpers, or services.
- Preserve persistence compatibility unless a migration or breaking change is explicitly approved.

### Comments

- Add comments only for platform constraints, non-obvious behavior, or complex logic.
- Do not add comments that restate the code.

## Build, Run, Test, And Lint

No third-party dependency installation is required.

Inspect the project:

```sh
xcodebuild -list -project MintPlayer.xcodeproj
```

To run in Xcode, open `MintPlayer.xcodeproj`, select the `MintPlayer` scheme, choose `My Mac`, and press `Command + R`.

Build:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

Build a specific configuration:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

Clean build:

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build
```

The repository currently has no test target and no SwiftLint or other lint configuration. Do not assume a test or lint command exists.

Debug builds use `Mint Player Debug.app`, `dev.govo.mintplayer.debug`, the `MintPlayer-Debug` Application Support directory, and the `mintPlayer.debug` preferences prefix.

Release builds use `Mint Player.app` and the release Application Support and preferences namespace.

## Manual Regression Guide

- **Library**: folder add/remove, duplicate folder prevention, rescan, blocked-song hiding/unblocking, and missing-folder behavior.
- **Playback**: double-click playback, play/pause fade, seek, stop, previous/next, natural completion, shuffle, repeat, volume, session restoration, Now Playing, and Dock menu actions.
- **Tables**: click, Shift selection, Command selection, double-click, context menu, trailing actions, column resize, column visibility, sorting, and drag to playlist or Finder.
- **Albums and Artists**: grid responsiveness, detail navigation, artwork matched transitions, search, playback buttons, and return animations.
- **Lyrics**: both presentation settings, embedded open/close and `Esc`, complete-surface animation, reduced motion, repeated toggles, repeated green-button full-screen entry and exit, full top-edge coverage in full screen, track changes while open, `.lrc` parsing, highlighted-line timing, smooth scrolling, tap-to-seek, inactive-line blur, missing artwork, artwork/background crossfade, and standalone-window restoration.
- **Settings**: theme, language, lyrics presentation, lyrics blur, library-folder layout, rescan, delete confirmation, blocked-song list, resizing, scroll coverage, and top scroll-edge effect.
- **Layout**: narrow windows, sidebar shown or hidden before opening embedded lyrics, sidebar-toggle restoration after closing lyrics, stable traffic-light positions, windowed trailing lyrics close button, immersive full-screen lyrics close button, toolbar restoration after leaving lyrics, toolbar tab bar, sidebar width, floating player-bar hit testing, and search-field placement.

## Git Workflow

- Work on the current branch by default.
- Use English Conventional Commits.
- Before committing, run `git status --short` and confirm that only task-related files are staged.
- Do not stage personal files, build products, Xcode user state, DerivedData, `.DS_Store`, local caches, or user music files.

Authorization requirements for commits, tags, pushes, pull requests, and commit-message confirmation remain in the root [AGENTS.md](../AGENTS.md).

## Versioning And Releases

Versions follow Semantic Versioning. `CHANGELOG.md` follows Keep a Changelog and keeps `Unreleased` at the top. Move user-facing `Unreleased` entries into a dated release section only when preparing a release.

`VERSION`, Xcode `MARKETING_VERSION`, release headings in `CHANGELOG.md`, and Git tags must match for a release.
