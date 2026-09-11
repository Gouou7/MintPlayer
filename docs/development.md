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
├── Scripts/              # Build-time Git version embedding
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

- **Library**: folder add/remove, duplicate folder prevention, background folder import and progress, failed-import retry, rescans preserving IDs/favorites/play counts/playlists, unreadable files and offline folders preserving existing records, removal during a scan, blocked-song hiding/unblocking, and database read failures preserving stored data.
- **Playback**: double-click playback, play/pause fade, seek, stop, previous/next, natural completion, shuffle, repeat, volume, session restoration, Now Playing, localized Dock/menu actions, missing-file and decode-error retry, queue multi-selection/reordering/removal/clear undo, history replay preserving upcoming songs, and Play Next repositioning existing songs.
- **Tables**: click, Shift selection, Command selection, double-click, context menu, trailing actions, column resize, column visibility, sorting, and drag to playlist or Finder.
- **Albums and Artists**: grid responsiveness, empty-state import actions, detail navigation, artwork matched transitions, search, playback buttons, return animations, album-artist grouping for compilations, and disc/track ordering with missing metadata.
- **Lyrics**: both presentation settings, embedded open/close and `Esc`, complete-surface animation, reduced motion, repeated toggles, repeated green-button full-screen entry and exit, full top-edge coverage in full screen, track changes while open, `.lrc` parsing, highlighted-line timing, smooth scrolling, tap-to-seek, inactive-line blur, missing artwork, artwork/background crossfade, and standalone-window restoration.
- **Settings**: theme, language, lyrics presentation, lyrics blur, library-folder layout, rescan, delete confirmation, blocked-song list, resizing, scroll coverage, and top scroll-edge effect. Check English and Chinese for new progress, errors, menus, and empty states.
- **Lyrics files and timing**: positive/negative LRC offsets, per-song earlier/later/reset adjustment, UTF-8/UTF-16/GB18030/Big5 files and encoding overrides, custom file selection and reloading, missing selected files, and rapid track changes while loading.
- **Keyboard and accessibility**: Command-F targets only the current visible library search, Command-P toggles playback, Command-Left/Right changes tracks, Command-Shift-O adds folders, and both progress sliders support keyboard focus, arrow keys, and VoiceOver adjustment.
- **Layout**: narrow windows, sidebar shown or hidden before opening embedded lyrics, sidebar-toggle restoration after closing lyrics, stable traffic-light positions, windowed trailing lyrics close button, immersive full-screen lyrics close button, toolbar restoration after leaving lyrics, toolbar tab bar, sidebar width, floating player-bar hit testing, and search-field placement.

## Git Workflow

- Work on the current branch by default.
- Use English Conventional Commits.
- Before committing, run `git status --short` and confirm that only task-related files are staged.
- Do not stage personal files, build products, Xcode user state, DerivedData, `.DS_Store`, local caches, or user music files.

Authorization requirements for commits, tags, pushes, pull requests, and commit-message confirmation remain in the root [AGENTS.md](../AGENTS.md).

## Versioning And Releases

Versions follow Semantic Versioning. `CHANGELOG.md` follows Keep a Changelog and keeps `Unreleased` at the top. Move user-facing `Unreleased` entries into a dated release section only when preparing a release.

Git tags matching `vMAJOR.MINOR.PATCH` are the only release version source. Every build runs `Scripts/embed-git-version.sh`, which generates the target's `Info.plist` in DerivedData, strips the leading `v`, and writes the release version to `CFBundleShortVersionString`. Debug builds use the most recent matching tag reachable from the commit; Release builds require the current commit itself to have a matching tag. The script writes the Git commit count to `CFBundleVersion` and an app-facing version to `MintDisplayVersion`: Release uses `MAJOR.MINOR.PATCH`, while Debug uses `MAJOR.MINOR.PATCH-COMMIT-debug` with a seven-character commit hash. The About view reads `MintDisplayVersion`. Xcode's checked-in `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` values are template placeholders and must not be maintained manually.

To prepare a release:

1. Move the relevant `Unreleased` entries into a dated `CHANGELOG.md` section named for the new version and commit the change.
2. Create a Git tag such as `v0.11.0` on that release commit.
3. Build or archive the tagged commit. A Release build from an untagged commit, or any build without a reachable semantic version tag, fails instead of producing an incorrectly versioned app.

The release heading and Git tag must match. Source archives without Git metadata cannot derive a version and are not supported as release build inputs.
