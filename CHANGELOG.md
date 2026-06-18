# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- None.

### Changed
- None.

### Deprecated
- None.

### Removed
- None.

### Fixed
- None.

### Security
- None.

## [0.8.0] - 2026-06-18

### Added
- Added continuous artwork transitions between album and artist grids and their detail pages.
- Added an optional full-screen lyrics blur effect with a Settings toggle.
- Added remembered window size and placement for the lyrics and Settings windows.
- Added a player bar context menu for adding the current song to playlists or blocking it.

### Changed
- Improved album and artist artwork transitions so artwork size and position animate together.
- Reorganized Settings into Appearance, Playback Page, Library, and About sections.
- Renamed the sidebar Folders section to Library and refined its add-button color and hover area.
- Updated Library settings rows to show the library name, path, last scan time, and blocked songs more compactly.
- Hid album and artist toolbar search fields while detail pages are open.
- Updated sidebar highlighting so icons use the theme color only while the window is active, with a neutral selected-row background.

### Deprecated
- None.

### Removed
- None.

### Fixed
- Fixed automatic track advancement, shuffle order restoration, repeated shuffle cycles, and clearing the upcoming queue.
- Fixed artist artwork transitions clipping the moving avatar to only the start and end circles.
- Fixed selected song rows using low-contrast white text in the light theme.
- Fixed Settings window resizing, scroll coverage, and top scroll edge behavior.
- Fixed library folder removal in Settings to ask for confirmation before deleting the app reference.

### Security
- None.

## [0.7.0] - 2026-05-30

### Added
- Added Dock menu playback controls for previous track, play/pause, next track, and shuffle.
- Added audio fade out on pause and fade in on resume.
- Added direct crossfade transitions for full-screen lyrics artwork and blurred background changes.
- Added gray artwork and lyrics background placeholders for songs without cover art.

### Changed
- Changed play count tracking to count only qualified plays after 60% of the song duration has actually played.
- Improved full-screen lyrics scrolling with deterministic AppKit scroll offset animation and Logistic-based timing.
- Moved the highlighted lyric focus position toward the top of the lyrics window to align with the artwork area.
- Added system symbol animations to player bar and lyrics playback controls.
- Reduced full-screen lyrics background edge darkening.

### Deprecated
- None.

### Removed
- None.

### Fixed
- Fixed full-screen lyrics artwork and blurred backgrounds flashing through an intermediate empty or dark frame during track changes.
- Fixed songs without artwork reusing the previous song's artwork or blurred background.

### Security
- None.

## [0.6.0] - 2026-05-29

### Added
- Added Space key play/pause handling while the main window or lyrics playback window is active.
- Added remembered sidebar visibility so the app restores the sidebar hidden or shown state on launch.
- Added a native toolbar tab bar for Favorites, Songs, Albums, and Artists when the sidebar is hidden.
- Added toolbar back buttons for Album and Artist detail pages.

### Changed
- Changed the player bar volume popover slider to use a perceptual curve so low-volume adjustments are more precise.
- Changed Songs, Favorites, Albums, and Artists search to use native toolbar search fields with consistent width.
- Changed the Songs and Favorites toolbar sorting control to use a standard toolbar menu button.
- Refined the hidden-sidebar tab bar sizing and shape to use a compact native segmented control.

### Deprecated
- None.

### Removed
- Removed duplicate custom toolbar search and glass control code in favor of native toolbar controls.

### Fixed
- Fixed duplicate sidebar toggle buttons appearing around the toolbar and collapsed sidebar tab bar.
- Fixed Albums and Artists toolbar search fields using a different width from Songs and Favorites.
- Fixed missing search icon display in the Songs and Favorites toolbar search field before typing.

### Security
- None.

## [0.5.0] - 2026-05-24

### Added
- None.

### Changed
- Limited song table header columns to at most half of the current screen width, including saved column widths, so oversized columns remain easy to shrink.

### Deprecated
- None.

### Removed
- None.

### Fixed
- Fixed Songs and playlist vertical scrollbars ending above the bottom of the page when the floating player bar bottom inset is applied.

### Security
- None.

## [0.4.0] - 2026-05-23

### Added
- Added the GPLv3 license to the repository.

### Changed
- Reworked the main Songs sorting menu into separate sort-field and ascending/descending choices, synchronized with table header sorting.
- Expanded hover feedback areas for the player bar, full-screen lyrics controls, album pages, and artist pages.
- Updated the sidebar playlist and folder section add buttons to use the same color as the collapse buttons.

### Deprecated
- None.

### Removed
- None.

### Fixed
- Fixed natural track completion not advancing to the next song in sequential and shuffle playback.
- Fixed the main player bar artwork hover area being expanded unintentionally.
- Fixed expanded player bar button hover backgrounds changing button spacing and player bar length.

### Security
- None.

## [0.3.0] - 2026-05-23

### Added
- Added the Favorites library entry, player bar favorite button, and favorite column in song tables.
- Added table header controls for optional columns such as play count, date added, and favorite, with persisted column visibility, order, and width per Songs, playlist, and Folder context.
- Added unified play and shuffle controls for Songs, playlists, Folder pages, albums, and artist song sections.
- Added a Block Song action to song context menus, plus settings UI for viewing and unblocking songs by library folder.
- Added a Remove from Playlist action to playlist song context menus while keeping Block Song available.
- Added Chinese, English, and system language options, plus a system theme option.
- Added restoration for the previous song, queue, playback position, shuffle state, and repeat state.
- Added isolated Debug configuration with a separate app name, bundle ID, Application Support directory, and `UserDefaults` prefix.

### Changed
- Migrated library state to a SQLite database in Application Support, including date added, play count, favorite status, blocked records, library folders, and playlist order.
- Replaced Recently Played with Favorites, and simplified the Library section in the sidebar.
- Moved the lyrics view from a main-window overlay to a resizable standalone window that supports native full screen.
- Updated the lyrics window to use cached artwork ambience and improved synced lyrics scrolling, highlighting, and resizing behavior.
- Reorganized the queue popover into history, now playing, and up next sections, with shuffle showing the actual shuffled queue.
- Changed Settings from tabs to a single sectioned page.
- Unified song list headers and backgrounds with an opaque table color, and added bottom scroll spacing for the floating player bar.
- Changed player bar and full-screen lyrics progress refresh to 500 ms.
- Split multi-artist songs by `; ` for artist indexing while preserving the original artist display string.
- Changed theme and language controls in Settings to menu pickers, and changed the About section to use the app icon.
- Changed the About version display to read from the bundle version and append `-Debug` or `-Release` based on build type.

### Deprecated
- None.

### Removed
- Removed the Recently Played page and old playback history model.

### Fixed
- Fixed the Folder table horizontal scrollbar appearing in the middle of the content.
- Fixed stale hover highlights while scrolling song, album detail, and Folder compact lists.
- Fixed missing hover feedback when dragging songs over sidebar playlists.
- Fixed the album detail song list background not matching the surrounding dark-mode background.
- Fixed main window toolbar elements appearing above the lyrics page.
- Fixed column widths resetting after clicking song table headers to sort.
- Fixed high memory usage and resize stutter caused by dynamic blur in the full-screen lyrics window.

### Security
- None.

## [0.2.0] - 2026-05-16

### Added
- Added macOS Now Playing, media keys, and Control Center integration through `MediaPlayer`.
- Added playlist descriptions and editing for playlist name and description.
- Added collapsible and reorderable Library, Playlists, and Folders sidebar sections with add actions.
- Added native table selection, double-click playback, context menus, column resizing, and dragging for Songs, playlist, Folder, album detail, and artist detail song lists.
- Added album and artist browsing based on music metadata artwork.
- Added lightweight album and artist summary indexes with cached thumbnails to reduce memory and main-thread cost in large libraries.
- Added song dragging into sidebar playlists using native drop destinations.
- Added hover and pressed feedback for primary buttons, sidebar rows, list rows, album/artist cards, and AppKit table rows.
- Added SF Symbols to song table context menu actions.

### Changed
- Standardized the project entry point on the native `MintPlayer.xcodeproj`; target, scheme, product, and module now use `MintPlayer`.
- Reorganized source directories into `App`, `Models`, `Stores`, `Services`, and `Views`.
- Changed the bottom player bar to a floating glass surface and refined queue, more-menu, and volume popover interactions.
- Unified sidebar selection, buttons, and primary interactions around the project accent color.
- Changed Settings to a dedicated Settings scene using native `TabView`, `Form`, and `Section` layout.
- Preserved native `NavigationSplitView` Liquid Glass sidebar appearance, constrained sidebar width, and removed the sidebar toggle button.
- Changed Artists to a drill-in flow across artist browsing, artist detail, and album detail, with search semantics following the current level.
- Reused the same album detail view across Albums and Artists.
- Moved search fields and sorting controls to the top-right page toolbar area.
- Made Artists detail and Albums detail headers responsive.
- Made non-Folder song tables shrink columns with the window width, while Folder pages keep compact multi-column tables and horizontal scrolling.
- Set the main window minimum size to `980 x 600`, reduced the sidebar minimum width, and centered the fixed-width player bar.
- Reduced the bottom player bar height to 50 pt and adjusted the bottom spacing to 20 pt.
- Reduced Albums and Artists grid card sizes so at least four items fit on one row at the minimum window width.

### Deprecated
- None.

### Removed
- Removed duplicate Swift Package and XcodeGen project entries and old source copies.
- Removed unused legacy pages and components: `ContentView`, `GenresView`, `PlaylistsView`, `PlaylistItemView`, and `SongItemView`.
- Removed the old equalizer placeholder UI and unused global sorting method.

### Fixed
- Fixed the Settings button not opening Settings.
- Fixed queue access from the old right sidebar by moving it into a player bar popover.
- Fixed missing deletion confirmations for playlists and folders.
- Fixed the main sidebar being draggable closed with no recovery path.
- Fixed artist detail navigation squeezing the main sidebar.
- Fixed artwork flicker on selection and progress refresh.
- Fixed the duration and trailing menu area being obscured by the song table scrollbar.
- Fixed click-through from the floating Liquid Glass player bar to content underneath.

### Security
- None.

## [0.1.0] - 2026-04-21

### Added
- Added the initial local music player functionality.
- Added drag-and-drop music import.
- Added real audio playback through AVFoundation.
- Added live progress updates and seeking.
- Added sidebar navigation.
- Added multi-library management and music file scanning.
- Added a floating player bar.
- Added basic music sorting.

### Changed
- None.

### Deprecated
- None.

### Removed
- None.

### Fixed
- Fixed macOS compatibility issues.
- Fixed unsupported `hoverEffect` usage on macOS.

### Security
- None.
