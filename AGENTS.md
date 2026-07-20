# Mint Player Development Guide

## Global Requirements

- Unless explicitly requested, do not run builds or tests by default.
- Unless explicitly requested, use native macOS controls and system behavior before custom implementations.
- Unless explicitly requested, do not change the version, create Git commits, or write changes into an existing released section of `CHANGELOG.md`; user-facing unreleased changes belong in `Unreleased`.
- Do not write to `README.md` without explicit permission. When `README.md` changes, keep `README_zh.md` synchronized.
- Commit messages must be confirmed by the user before committing.
- When changing user-facing text, buttons, labels, or descriptions, update every supported language in `SettingsManager`.

## Project Overview

Mint Player is a native macOS local music player built from a single Xcode project. It manages user-selected music folders, indexes metadata and artwork, plays local audio files, displays local synchronized lyrics, and exposes native macOS table, window, sidebar, toolbar, and media-control behavior.

- **Language**: Swift 5
- **UI**: SwiftUI, with AppKit bridges for native tables, windows, search fields, file pickers, and narrow platform behavior
- **Audio**: AVFoundation / `AVAudioPlayer`
- **System media controls**: MediaPlayer, Now Playing, Remote Command Center, and Dock menu actions
- **Persistence**: SQLite for library state, `UserDefaults` for preferences and window/table state, artwork cache files under Application Support
- **Build entry point**: `MintPlayer.xcodeproj`
- **Minimum OS**: macOS 26.0

The repository currently has no Swift Package manifest, third-party dependency manifest, test target, lint configuration, CI configuration, or custom build script. If a `Reference Proj.` directory exists, treat it as reference material only; it is not part of the Mint Player build.

## Project Structure

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
└── AGENTS.md             # Agent and maintainer guide
```

## Architecture Notes

`MintPlayerApp` creates three scene families: the main app window, the lyrics window, and the Settings scene. Shared state is created once with `@StateObject` and injected through `@EnvironmentObject`.

`MusicLibrary` owns library sources, songs, playlists, blocked songs, album summaries, and artist summaries. It scans folders on background queues, extracts metadata with AVFoundation, caches artwork, rebuilds album/artist indexes, and persists app state through `LibraryPersistenceStore`.

`AudioPlayer` wraps `AVAudioPlayer`, queue state, shuffle/repeat behavior, playback restoration, play-count qualification, volume, fade in/out, and Now Playing updates. Playback count is based on actual listened duration, not clicks.

SwiftUI owns high-level view state and layout. AppKit is used only where native macOS behavior is required: `NSTableView`, `NSSearchField`, `NSWindow`, file import, event monitoring, drag/drop boundaries, and deterministic lyrics scrolling.

Lyrics support two presentation containers around the same `LyricsOverlayView`: the existing standalone window and an embedded main-window overlay. The embedded container keeps the library `NavigationSplitView` mounted underneath, isolates its interaction, and owns only presentation animation and temporary main-window chrome changes. Read `docs/内嵌歌词实现说明.md` and `docs/内嵌歌词实现经验.md` before changing this boundary.

## Data Flow

1. The user adds a library folder in Settings or imports files.
2. `MusicLibrary` scans supported audio files and extracts metadata.
3. `LibraryPersistenceStore` saves songs, playlists, blocked records, sources, favorites, and play counts into SQLite.
4. Album and artist indexes are rebuilt from the current song snapshot.
5. Library views read summaries and song lists from `MusicLibrary`.
6. Playback actions call `AudioPlayer`, which updates queue state, `AVAudioPlayer`, Now Playing, session restoration, and qualified play counts.
7. Lyrics views read current playback state and parsed lyrics, then drive highlighting, scrolling, blur, and tap-to-seek behavior.

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
- Keep AppKit objects inside representables, coordinators, helpers, or services. Do not pass AppKit objects broadly through SwiftUI view trees.
- Preserve existing persistence compatibility unless the user explicitly approves a migration or breaking change.

### Comments

- Add comments only for platform constraints, non-obvious behavior, or complex logic.
- Do not add comments that restate the code.

## UI And Interaction Rules

- Keep the main sidebar aligned with native `NavigationSplitView` and system Liquid Glass behavior. Do not replace it with custom-painted chrome.
- The bottom player bar is a centered floating Liquid Glass control and must intercept clicks so events do not pass through to content underneath.
- Search fields live in the top-right toolbar by default and should use native macOS search controls. Do not customize `NSSearchField` text layout unless the native control is demonstrably insufficient.
- Songs, playlists, folder views, and detail-page song lists depend on `NativeSongTableView`; preserve native selection, multi-selection, double-click playback, sorting, context menus, trailing actions, column resizing, and dragging.
- Albums and Artists browsing pages should remain responsive grids with at least four primary items visible per row at the minimum window width.
- Artists use a drill-in flow across artist browsing, artist detail, and album detail. Do not reintroduce a permanent three-column artist layout.
- Use `matchedGeometryEffect` only for artwork continuity between grids and detail pages. Do not apply matched geometry to page containers, text, tables, or whole cards.
- Full-screen lyrics scrolling uses a narrow AppKit `NSScrollView` bridge for deterministic animated offsets. SwiftUI remains the source of truth for lyric content and highlighting.
- Full-screen lyrics artwork and blurred backgrounds should crossfade directly between old and new images. Do not clear to black or an empty frame during normal track changes.
- Songs without artwork should show the gray placeholder artwork and gray lyrics background, never a previous song's artwork.
- Embedded lyrics must keep the underlying library mounted so sidebar state, scrolling, table selection, and album/artist navigation survive dismissal. Disable and accessibility-hide the library while the overlay is mounted instead of replacing it.
- Animate embedded lyrics with separate mounted and visible states. Apply movement or reduced-motion opacity to one fixed-size composited shell containing the complete lyrics surface; do not give its background, artwork, scrolling content, or controls independent page transitions.
- Remove the default sidebar toggle dynamically from the `SidebarView` that owns it: use `.toolbar(removing: isLyricsMounted ? .sidebarToggle : nil)`. Applying permanent removal breaks normal sidebar control, while disabling the split view only grays the button.
- Keep the native window toolbar mounted during embedded lyrics. Hiding the whole toolbar moves the traffic lights. Temporarily make the titlebar transparent through the focused `NSWindow` bridge and restore every captured window property on dismissal or teardown.
- On macOS 26, keep the embedded lyrics close action at the toolbar tail with `ToolbarSpacer(.flexible)` followed by an `.automatic` toolbar item. `.topBarTrailing` is unavailable on macOS, and `.secondaryAction` may be placed near the center.
- Library search and detail-navigation toolbar items must honor the `isPlayerOverlayPresented` environment value so they do not appear above embedded lyrics.

## Build, Run, Test, And Lint

### Dependencies

No third-party dependency installation is required.

### Inspect

```sh
xcodebuild -list -project MintPlayer.xcodeproj
```

### Run

Open `MintPlayer.xcodeproj`, select the `MintPlayer` scheme, choose `My Mac`, and press `Command + R`.

### Build

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

### Clean Build

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build
```

### Tests

There is currently no test target. Do not create one without user approval.

### Lint

There is currently no SwiftLint or other lint configuration. Do not assume a lint command exists.

### Build Configurations

Debug builds use `Mint Player Debug.app`, `dev.govo.mintplayer.debug`, the `MintPlayer-Debug` Application Support directory, and the `mintPlayer.debug` preferences prefix.

Release builds use `Mint Player.app` and the release Application Support/preferences namespace.

## Manual Regression Guide

- **Library**: folder add/remove, duplicate folder prevention, rescan, blocked-song hiding/unblocking, missing folder behavior.
- **Playback**: double-click playback, play/pause fade, seek, stop, previous/next, natural completion, shuffle, repeat, volume, session restoration, Now Playing, Dock menu actions.
- **Tables**: click, Shift selection, Command selection, double-click, context menu, trailing actions, column resize, column visibility, sorting, drag to playlist/Finder.
- **Albums and Artists**: grid responsiveness, detail navigation, artwork matched transitions, search, playback buttons, return animations.
- **Lyrics**: both presentation settings, embedded open/close and `Esc`, complete-surface animation, reduced motion, repeated toggles, track changes while open, `.lrc` parsing, highlighted line timing, smooth scrolling, tap-to-seek, inactive-line blur, missing artwork, artwork/background crossfade, and standalone window restoration.
- **Settings**: theme, language, lyrics presentation, lyrics blur, library folder layout, rescan, delete confirmation, blocked-song list, resizing, scroll coverage, top scroll edge effect.
- **Layout**: narrow windows, sidebar shown/hidden before opening embedded lyrics, sidebar toggle restoration after closing lyrics, stable traffic-light positions, trailing lyrics close button, toolbar tab bar, sidebar width, floating player bar hit testing, and search field placement.

## Git Workflow

- Work on the current branch by default.
- Do not commit, tag, push, or create pull requests unless explicitly requested.
- Use English Conventional Commits, for example `feat: improve playback controls`.
- Before committing, run `git status --short` and confirm that only task-related files are staged.
- Do not stage personal files, build products, Xcode user state, DerivedData, `.DS_Store`, local caches, or user music files.

## Versioning And Releases

- Versions follow Semantic Versioning.
- `VERSION`, Xcode `MARKETING_VERSION`, release headings in `CHANGELOG.md`, and Git tags must match for a release.
- `CHANGELOG.md` follows Keep a Changelog and keeps `Unreleased` at the top.
- Do not record version-number-only changes or ordinary documentation maintenance in `CHANGELOG.md`.
- Move user-facing `Unreleased` entries into a dated release section only when preparing a release.

## Security And Data Safety

- Never commit secrets, tokens, `.env` files, personal paths, user music files, or real user library data.
- Do not hardcode absolute user paths in source or docs.
- Folder deletion in the app must only remove the app's library reference and internal index entries. It must not delete user files from disk.
- Keep permission requests minimal and limited to local music management.

## Agent Constraints

- Read the relevant code before changing behavior.
- Prefer existing patterns and helpers over new abstractions.
- Prefer narrow extensions over rewrites.
- Preserve API and database compatibility unless the user explicitly approves a breaking change.
- Do not hide native control issues with timers, forced rebuilds, or close-and-reopen workarounds. Understand the SwiftUI/AppKit boundary first.
- Do not introduce a package manager, dependency, test target, script, or CI configuration unless explicitly requested.
- Do not leave fake or placeholder UI. Implement the backing behavior or ask the user.
- Do not revert user changes. If the worktree is dirty, touch only task-related files.

## Pitfalls And Lessons Learned

### Native Search Field Layout

- **Problem**: Replacing `NSSearchFieldCell` or manually changing the field editor can misalign text. Publishing every text change can also treat input method marked text as a completed query, interrupting Chinese composition and repeatedly filtering large libraries.
- **Cause**: `NSSearchField` has separate native drawing/editing paths, while `controlTextDidChange` also fires during input method composition.
- **Avoid**: Custom search-field cells, manual editor insets, immediate search-string delivery, or writing marked text into SwiftUI search state.
- **Use**: Keep a plain `NSSearchField` in `NSViewRepresentable`; ignore changes while its editor has marked text, debounce completed edits against the binding active when the edit occurred, cancel pending work when dismantled, commit immediately on submit or end editing, and do not overwrite the field from stale binding state while it is being edited. Keep list-level and detail-level search state in separate bindings.

### Shuffle Queue Generation

- **Problem**: Repeatedly invoking Shuffle for the same list can appear deterministic when a valid random permutation happens to match the current queue.
- **Cause**: A random shuffle is allowed to return the previous ordering, especially for small song lists.
- **Avoid**: Assuming every call to `shuffled()` necessarily produces a visibly different order.
- **Use**: Generate a fresh queue with `SystemRandomNumberGenerator` and, when there is more than one song, change the permutation if it exactly matches the current queue.

### Window Restoration

- **Problem**: Applying a saved frame after a SwiftUI window appears causes a visible jump from the default frame to the restored frame.
- **Cause**: Post-creation AppKit frame mutation happens after the system has already shown the window.
- **Avoid**: Delayed frame restoration, close/reopen workarounds, or timers.
- **Use**: SwiftUI scene-level `defaultWindowPlacement` for the initial frame, then a narrow AppKit observer only to save frame changes.

### Lyrics Scrolling Performance

- **Problem**: Driving lyrics scrolling through broad SwiftUI layout changes can create janky highlighting and scrolling.
- **Cause**: High-frequency playback updates can invalidate too much of the view tree.
- **Avoid**: Full view rebuilds, unrelated animation state, or expensive per-frame effects.
- **Use**: Keep lyric content in SwiftUI, use the AppKit scroll bridge only for deterministic offset animation, and limit blur to simple per-line radius changes.

### Artwork And Background Transitions

- **Problem**: Clearing artwork/background state during track changes causes a black or empty intermediate frame.
- **Cause**: The old image is removed before the new image is ready.
- **Avoid**: Resetting image state to `nil` as a visible transition step.
- **Use**: Crossfade directly from old image to new image; songs without artwork should crossfade to the gray placeholder/background.

### Database Compatibility

- **Problem**: Changing models without considering SQLite persistence can lose user metadata.
- **Cause**: Playlists, favorites, blocked songs, play counts, and sources are stored in SQLite and merged during scans.
- **Avoid**: Renaming persisted fields, changing IDs, or replacing merge logic casually.
- **Use**: Preserve persistent fields during rescans and add explicit migrations when schema changes are required.

### Embedded Lyrics Presentation And Toolbar Ownership

- **Problem**: A conditional `.move` transition can make only part of the lyrics page slide, default sidebar controls can remain above the overlay, and hiding the complete toolbar can move the window traffic lights.
- **Cause**: Async artwork/background content and AppKit lyric scrolling do not necessarily enter the render tree together; the sidebar toggle is owned by the sidebar column of `NavigationSplitView`; the native titlebar and toolbar share window chrome.
- **Avoid**: Independent child transitions, conditionally replacing the library view, removing `.toggleSidebar` through AppKit, permanently applying `.toolbar(removing: .sidebarToggle)`, hiding the entire window toolbar, or adding a replacement titlebar accessory button.
- **Use**: Mount the complete lyrics shell offscreen before animating it, keep the library mounted but noninteractive, remove the default sidebar item dynamically on `SidebarView`, hide page-specific toolbar items through `isPlayerOverlayPresented`, preserve the native toolbar, and restore captured `NSWindow` titlebar properties after dismissal.

### macOS Toolbar Trailing Placement

- **Problem**: Toolbar placements that sound trailing on other Apple platforms either fail to compile or appear near the center on macOS.
- **Cause**: `.topBarTrailing` is unavailable on macOS, while semantic placements such as `.secondaryAction` let the system choose a section rather than pinning an edge.
- **Avoid**: Assuming toolbar placement names have identical availability or geometry across Apple platforms.
- **Use**: On the macOS 26 deployment target, place `ToolbarSpacer(.flexible)` before an `.automatic` item when an action must remain at the toolbar tail, then verify both compilation and sidebar-expanded/collapsed layouts.

## Architecture Decisions

### Xcode Project As Build Entry

Mint Player is project-first rather than SwiftPM-first. Keep `MintPlayer.xcodeproj` as the source of truth for schemes, configurations, signing, and build settings.

### SwiftUI With Narrow AppKit Bridges

SwiftUI is used for app structure and most UI. AppKit bridges are intentionally narrow and exist where native macOS behavior is required or SwiftUI behavior is insufficient: `NSTableView`, `NSSearchField`, `NSWindow`, event monitors, and deterministic scroll control.

### SQLite For Library State

SQLite stores library state because the app needs durable records for songs, playlists, library sources, blocked songs, favorites, play counts, and scan metadata. `UserDefaults` is reserved for lightweight preferences and UI state.

### Local-First Library Model

The app indexes user-selected folders and keeps app metadata separately. It must not modify, move, or delete user audio files as part of library management.

### Drill-In Artist Navigation

Artists use a drill-in structure rather than a permanent multi-column layout. This preserves space for responsive grids and detail pages and keeps the main navigation consistent with Albums.

### Shared Lyrics Content With Separate Presentation Containers

Both lyrics modes reuse `LyricsOverlayView` for loading, scrolling, highlighting, artwork/background transitions, seeking, and playback controls. Presentation-specific behavior belongs in the standalone window or embedded shell. Do not fork the lyrics content implementation between modes.

## Agent Memory

#### 2026-05-30

- **Background**: Full-screen lyrics scrolling and highlighting needed smoother timing without excessive resource use.
- **Problem**: SwiftUI-driven scrolling and highlighting could become janky when unrelated view updates happened at playback cadence.
- **Decision**: Keep SwiftUI as the lyric content source, but use a focused AppKit `NSScrollView` bridge for deterministic scroll offsets and keep visual effects per-line.
- **Impact**: Future lyrics changes should avoid broad state invalidation and should verify both scroll smoothness and highlight timing.

#### 2026-05-30

- **Background**: Lyrics and Settings windows needed remembered size/position.
- **Problem**: Restoring frames after a window appears creates visible jumps.
- **Decision**: Use scene-level `defaultWindowPlacement` for initial restoration and AppKit observers only to save new frames.
- **Impact**: Do not reintroduce delayed frame mutation or close/reopen restoration workarounds.

#### 2026-05-30

- **Background**: Album and artist artwork needed continuous transitions between grid/detail states.
- **Problem**: Applying matched geometry to too much UI caused clipping, size mismatch, or unnatural page transitions.
- **Decision**: Apply `matchedGeometryEffect` only to artwork containers and keep text, tables, and page layout outside the shared geometry.
- **Impact**: Future navigation animation work should keep matched geometry scoped to the visual element that should morph.

#### 2026-05-31

- **Background**: Toolbar search fields showed inconsistent vertical text positions after custom cell/editor adjustments.
- **Problem**: Native `NSSearchField` draws placeholder and edited text through different internal paths.
- **Decision**: Keep toolbar search fields plain and native; hide them on album/artist detail pages rather than repurposing them for detail-level search.
- **Impact**: Do not replace `NSSearchFieldCell` or manually tune field-editor insets without a strong platform-specific reason.

#### 2026-07-20

- **Background**: Lyrics needed an Apple Music-style main-window presentation while preserving the standalone lyrics window and native `NavigationSplitView` behavior.
- **Problem**: Ordinary conditional transitions animated complex lyrics children inconsistently, and toolbar ownership caused sidebar controls or unstable window chrome above the overlay.
- **Decision**: Reuse `LyricsOverlayView` in a mounted/visible embedded shell, keep the library mounted but isolated, remove the sidebar default item at its owning sidebar view, preserve the native toolbar, and use a narrow reversible `NSWindow` chrome bridge.
- **Impact**: Future full-window lyrics changes must preserve the two-state presentation lifecycle, library state retention, toolbar ownership boundaries, reduced-motion behavior, and standalone-window compatibility.
