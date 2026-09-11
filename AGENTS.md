# Mint Player Agent Guide

## Project And Code Map

Mint Player is a native macOS local music player built with Swift 5, SwiftUI, focused AppKit bridges, AVFoundation, MediaPlayer, SQLite, and `UserDefaults`. It requires macOS 26.0 or later and Xcode with the macOS 26 SDK. `MintPlayer.xcodeproj` is the only build entry point.

This file contains the project's development rules, implementation constraints, and verification guidance.

| Location | Responsibility |
| --- | --- |
| `MintPlayer/App/` | App entry, scenes, app delegate, configuration, and Info.plist template |
| `MintPlayer/Models/` | Songs, albums, artists, playlists, library sources, and themes |
| `MintPlayer/Stores/` | `MusicLibrary` state and indexing; `SettingsManager` preferences and localization |
| `MintPlayer/Services/` | Audio playback, SQLite persistence, lyrics parsing, and Now Playing |
| `MintPlayer/Views/` | `Root`, `Sidebar`, `Library`, `Player`, `Settings`, and reusable `Shared` views and AppKit bridges |
| `Scripts/embed-git-version.sh` | Build-phase version generation from Git tags |
| `docs/images/` | README screenshots and artwork |

`MintPlayerApp` creates shared state with `@StateObject` and injects it through `@EnvironmentObject` into the main, lyrics, and Settings scenes. `MusicLibrary` scans files, builds album and artist summaries, and saves library state through `LibraryPersistenceStore`. `AudioPlayer` owns `AVAudioPlayer`, queues, playback restoration, qualified play counts, and system media updates. SQLite holds library records; namespaced preferences hold settings and UI state; Application Support holds the database and artwork cache.

## Working Rules

- Work on the current branch and preserve uncommitted user changes. Touch only task-related files.
- Read the relevant implementation before changing behavior; extend existing helpers instead of rewriting subsystems.
- Do not run builds or tests unless explicitly requested.
- Preserve public API and SQLite compatibility unless the user explicitly approves a breaking change or migration.
- Do not introduce a package manager, dependency, test target, script, lint tool, or CI configuration unless explicitly requested.
- Prefer native macOS controls and system behavior unless a custom implementation is requested. Do not leave placeholder UI without backing behavior.
- Keep AppKit objects inside representables, coordinators, focused helpers, or services. Do not mask native control problems with timers, forced rebuilds, or close-and-reopen workarounds.
- Follow the existing Swift style: 4-space indentation, view files named after their primary type, view-local state wrappers, and shared state through `@EnvironmentObject`. Keep changes focused and comments limited to non-obvious behavior or platform constraints.
- Update all supported languages in `SettingsManager` for user-facing text, including menus, errors, labels, and accessibility descriptions.

## Data And Playback Constraints

### Library And Persistence

- Library operations must not modify, move, or delete user audio files. Removing a folder removes only the app reference and internal index entries. Limit permissions to local music management.
- Preserve song IDs, favorites, play counts, blocked state, sources, and playlist references during rescans. Merge results against the current main-thread snapshot so edits made during scanning survive.
- Extract metadata on the serial background scan queue and publish progress in batches. An enumeration failure retains the previous source index; a per-file failure retains that file's record. Only a complete traversal may remove absent tracks. Reconcile playlist entries before saving.
- Use per-source scan tokens to discard late results after removal and ignore duplicate active scans. Collect dropped URLs before background import; apply blocked-song and source-ownership filtering on the main thread.
- Keep the additive track-number, disc-number, and album-artist columns on schema version 3: older releases destructively reset unknown versions. Inspect `PRAGMA table_info(songs)` and add missing columns transactionally. Reject unsupported schemas and prevent writes after a failed snapshot load; never drop tables to recover from a version mismatch.
- Preserve album-artist grouping for compilations and disc/track playback ordering, including missing metadata.

### Playback And Queue

- Count plays from actual listened duration, not playback clicks; the current threshold is 60% of the track.
- Queue reordering and removal affect upcoming songs. Synchronize the source queue so shuffle toggling and session restoration retain edits. History replay preserves upcoming songs; Play Next can reposition an existing entry.
- Clearing the queue retains one undo snapshot. Later queue edits or track navigation invalidate it; library refreshes must remove unavailable songs from the snapshot.
- An explicit Shuffle action generates a fresh permutation. For multiple songs, change it if it matches the previous queue; `shuffled()` alone does not guarantee a different order.

### Lyrics Data

- Apply timing as `timestamp - fileOffsetMilliseconds / 1000 + userAdjustmentSeconds`. A positive LRC offset advances lyrics; a negative user adjustment displays them earlier.
- Store per-song custom file paths, encoding choices, and timing adjustments in namespaced preferences. Load and parse off the main thread, and discard results from cancelled view tasks.

## UI And AppKit Boundaries

### Library, Search, And Windows

- Preserve native `NavigationSplitView` sidebar and Liquid Glass behavior. The centered floating player bar must intercept clicks instead of passing them to the library.
- Song lists use `NativeSongTableView`; preserve selection, multi-selection, sorting, double-click playback, context menus, trailing actions, column customization, and dragging.
- Albums and Artists use responsive grids with at least four primary items per row at minimum window width. Artist navigation drills into artist and album details. Apply matched geometry only to artwork, not text, tables, cards, or page containers.
- Keep native search fields in the top-right toolbar and hide them on album and artist details. Separate list and detail search bindings.
- In `FloatingSearchField.swift`, keep a plain `NSSearchField`; do not replace its cell or adjust field-editor insets. Ignore marked-text composition, debounce completed edits against the binding captured at edit time, commit on submit or end editing, and cancel pending work on dismantle. Do not overwrite an active editor from stale SwiftUI state.
- Restore lyrics and Settings window frames through scene-level `defaultWindowPlacement`. Use the AppKit observer only to save subsequent changes; restoring after appearance causes visible jumps.

### Lyrics Presentation

- Both modes reuse `LyricsOverlayView` and keep lyrics dark. SwiftUI owns content and highlighting; the focused AppKit `NSScrollView` bridge handles animated offsets. Scope playback-cadence updates narrowly and keep per-line blur inexpensive.
- Crossfade artwork and backgrounds directly between images. Missing artwork transitions to the gray placeholder and gray background; do not show an empty frame or the previous song's image.
- Embedded lyrics keep the library mounted, disabled, and accessibility-hidden to preserve sidebar, scroll, selection, and navigation state. Use separate mounted and visible states; mount one fixed-size composited shell offscreen, then animate the complete surface, using opacity for reduced motion. Avoid independent child transitions.
- Remove the sidebar toggle conditionally at the owning `SidebarView` in `MainView`, using `.toolbar(removing: isLyricsMounted ? .sidebarToggle : nil)`. Permanent removal breaks normal sidebar behavior. Page toolbar items must honor `isPlayerOverlayPresented`.
- Retain the native toolbar. The focused `NSWindow` bridge temporarily adjusts titlebar properties and hides the toolbar during embedded full-screen lyrics so the surface covers the top edge. Reapply state on AppKit full-screen transition notifications and restore all captured properties on exit, dismissal, or teardown. Full-screen closing uses the lyrics-owned controls.
- Keep the windowed close action at the toolbar tail with `ToolbarSpacer(.flexible)` before an `.automatic` item. `.topBarTrailing` is unavailable on macOS, and semantic placements do not guarantee trailing alignment.

## Build And Verification

No dependency installation is required. The repository has no test target, lint configuration, or CI configuration; do not assume those commands exist. Xcode runs the existing version script as a build phase.

When explicitly requested, inspect or build with:

```sh
xcodebuild -list -project MintPlayer.xcodeproj
xcodebuild -project MintPlayer.xcodeproj -scheme MintPlayer -configuration Debug -destination 'platform=macOS' build
```

For an authorized Release build, replace `Debug` with `Release`; the current commit must have a matching release tag. To run in Xcode, open the project, select `MintPlayer` and `My Mac`, then press `Command + R`.

Debug uses `Mint Player Debug.app`, bundle ID `dev.govo.mintplayer.debug`, Application Support directory `MintPlayer-Debug`, and preferences prefix `mintPlayer.debug`. Release uses `Mint Player.app` and the `MintPlayer` / `mintPlayer` storage namespaces. Preserve this separation.

When manual verification is requested, cover the affected areas:

| Area | Regression coverage |
| --- | --- |
| Library | Add/remove and duplicate folders; background import/progress/retry; rescan identity and metadata preservation; unreadable files, offline folders, removal during scans, blocked songs, and database read failures |
| Playback | Play/pause fade, seek, stop, previous/next, completion, shuffle/repeat, volume, restoration, Now Playing/Dock actions, missing/decode-error retry, queue editing/undo, history replay, and Play Next |
| Tables and browsing | Native selection and actions, columns/sorting, drag to playlists/Finder, responsive grids, empty-state import, search scope and Chinese composition, detail navigation/artwork transitions, compilation grouping, and disc/track order |
| Lyrics | Both modes, repeated open/close and full-screen transitions, Esc, full-surface/reduced-motion animation, toolbar/sidebar restoration, timing/scroll/tap-to-seek, blur, track/artwork changes, and missing artwork |
| Lyrics files | Positive/negative LRC offsets and user adjustments/reset; UTF-8/UTF-16/GB18030/Big5 and encoding overrides; custom files/reload/missing files; rapid track changes during loading |
| Settings and layout | English/Chinese, theme, lyrics options, folder rescan/removal confirmation, blocked songs, window restoration/resizing, narrow layouts, sidebar widths, traffic lights, top scroll-edge coverage, and player-bar hit testing |
| Keyboard and accessibility | Command-F targets visible search; Command-P toggles playback; Command-Left/Right changes tracks; Command-Shift-O imports folders; both progress sliders support keyboard focus, arrows, and VoiceOver adjustment |

For documentation-only work, check accuracy against the repository, local links, and the final diff; no app build is needed.

## Documentation And Releases

- Keep repository documentation in English. `README.zh.md` is the Chinese translation of `README.md`; keep them synchronized when authorized to edit the README. Do not write to `README.md` without explicit permission.
- Keep agent development guidance in this file. READMEs describe the product and usage; `CHANGELOG.md` records user-facing changes.
- Follow Keep a Changelog with `Unreleased` at the top. Do not add ordinary documentation-maintenance or version-only entries, change versions, or edit released sections unless explicitly requested.
- Git tags matching `vMAJOR.MINOR.PATCH` are the only release version source. Do not manually maintain Xcode's `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` placeholders.
- `Scripts/embed-git-version.sh` generates Info.plist in DerivedData. Debug uses the latest reachable matching tag; Release requires a matching tag on HEAD. Builds without a reachable semantic version tag or Git metadata fail. `CFBundleShortVersionString` comes from the tag, `CFBundleVersion` from the commit count, and `MintDisplayVersion` displays the release version or `MAJOR.MINOR.PATCH-COMMIT-debug` with a seven-character hash.
- When a release is requested, move relevant `Unreleased` entries into a dated version section, obtain commit-message confirmation, commit, and tag that release commit before building or archiving. The changelog heading and tag must match; each Git operation still requires authorization below.

## Git And Data Safety

- Do not commit, tag, push, or create pull requests unless explicitly requested. Confirm the commit message before committing; use English Conventional Commits.
- Before committing, run `git status --short` and confirm that only task-related files are staged.
- Never stage secrets, tokens, `.env` files, personal paths, real library data, user music, build products, Xcode user state, DerivedData, `.DS_Store`, or local caches. Do not hardcode absolute user paths in source or documentation.
