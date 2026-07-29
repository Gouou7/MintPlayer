# Mint Player Architecture

## System Overview

Mint Player is a native macOS local music player. It manages user-selected music folders, indexes metadata and artwork, plays local audio files, displays local synchronized lyrics, and exposes native macOS table, window, sidebar, toolbar, and media-control behavior.

The application uses:

- Swift 5 and SwiftUI for the application structure and most UI.
- Focused AppKit bridges where native macOS behavior or deterministic control is required.
- AVFoundation and `AVAudioPlayer` for local audio playback.
- MediaPlayer for Now Playing, Remote Command Center, and related system media integration.
- SQLite for durable library state.
- `UserDefaults` for lightweight preferences and window or table state.
- Application Support files for cached artwork.

## Runtime Structure

`MintPlayerApp` creates three scene families: the main app window, the lyrics window, and the Settings scene. Shared state is created once with `@StateObject` and injected through `@EnvironmentObject`.

`MusicLibrary` owns library sources, songs, playlists, blocked songs, album summaries, and artist summaries. It scans folders on background queues, extracts metadata with AVFoundation, caches artwork, rebuilds album and artist indexes, and persists app state through `LibraryPersistenceStore`.

`AudioPlayer` wraps `AVAudioPlayer`, queue state, shuffle and repeat behavior, playback restoration, play-count qualification, volume, fade in and out, and Now Playing updates. Playback count is based on actual listened duration rather than clicks.

SwiftUI owns high-level view state and layout. AppKit is limited to focused boundaries such as `NSTableView`, `NSSearchField`, `NSWindow`, file import, event monitoring, drag-and-drop boundaries, and deterministic lyrics scrolling.

## Data Flow

1. The user adds a library folder in Settings or imports files.
2. `MusicLibrary` scans supported audio files and extracts metadata.
3. `LibraryPersistenceStore` saves songs, playlists, blocked records, sources, favorites, and play counts into SQLite.
4. Album and artist indexes are rebuilt from the current song snapshot.
5. Library views read summaries and song lists from `MusicLibrary`.
6. Playback actions call `AudioPlayer`, which updates queue state, `AVAudioPlayer`, Now Playing, session restoration, and qualified play counts.
7. Lyrics views read current playback state and parsed lyrics, then drive highlighting, scrolling, blur, and tap-to-seek behavior.

## Durable Design Decisions

### Xcode Project As Build Entry

Mint Player is project-first rather than SwiftPM-first. Keep `MintPlayer.xcodeproj` as the source of truth for schemes, configurations, signing, and build settings.

### SwiftUI With Narrow AppKit Bridges

SwiftUI owns application structure and most UI. Keep AppKit objects inside representables, coordinators, focused helpers, or services rather than passing them broadly through SwiftUI view trees.

Lyrics content remains in SwiftUI, while a focused AppKit `NSScrollView` bridge provides deterministic animated offsets. This boundary avoids broad SwiftUI invalidation at playback cadence while preserving SwiftUI as the source of truth.

### SQLite For Library State

SQLite stores songs, playlists, library sources, blocked songs, favorites, play counts, and scan metadata. `UserDefaults` is reserved for lightweight preferences and UI state.

Preserve persisted IDs and fields during rescans. Changes to persisted models require an explicit compatibility plan and migration when necessary.

### Local-First Library Model

The app indexes user-selected folders and stores its metadata separately. Library management must not modify, move, or delete user audio files.

### Drill-In Artist Navigation

Artists use a drill-in flow across artist browsing, artist detail, and album detail rather than a permanent multi-column layout. This preserves space for responsive grids and keeps navigation consistent with Albums.

### Artwork-Only Matched Geometry

Use `matchedGeometryEffect` only for artwork continuity between grids and detail pages. Text, tables, page containers, and whole cards remain outside the shared geometry to avoid clipping, size mismatches, and unnatural page transitions.

### Scene-Level Window Restoration

Use SwiftUI scene-level `defaultWindowPlacement` to apply an initial saved window frame before presentation. Use a narrow AppKit observer only to save subsequent frame changes; post-appearance frame mutation causes visible window jumps.

### Shared Lyrics Content With Separate Presentation Containers

Both lyrics modes reuse `LyricsOverlayView` for loading, scrolling, highlighting, artwork and background transitions, seeking, and playback controls. Presentation-specific behavior belongs in the standalone window or embedded shell; do not fork the lyrics content implementation.

The embedded presentation keeps the library `NavigationSplitView` mounted underneath and makes it noninteractive and accessibility-hidden while lyrics are mounted. The embedded shell owns only presentation animation and temporary main-window chrome changes, preserving sidebar, scroll, table-selection, and detail-navigation state across dismissal.

Use separate mounted and visible states for the embedded presentation. Mount one fixed-size composited shell offscreen before animating the complete surface, and preserve the native toolbar while applying temporary, reversible titlebar changes through a focused `NSWindow` bridge.
