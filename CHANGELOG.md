# Changelog

## [Unreleased]

## [0.13.0] - 2026-09-11

### Added
- Added album track numbers, disc numbers, and album artist metadata, with album playback ordered by disc and track and compilations grouped by album artist.
- Added import progress, scan and playback error details, and retry actions while keeping folder imports responsive.
- Added upcoming queue reordering, multi-song removal, and undo for clearing the queue.
- Added per-song lyrics timing adjustment, custom lyrics file and text encoding selection, and manual reloading.
- Added playback menu commands, keyboard shortcuts, accessible keyboard-adjustable progress sliders, and folder import buttons in empty library views.

### Fixed
- Preserved song identities, favorites, play counts, and playlist references during rescans, and retained existing songs when folders or audio files cannot be read.
- Kept existing databases intact when encountering unsupported versions or read errors.
- Kept upcoming songs when replaying history, and allowed Play Next to reposition songs already in the queue.
- Applied LRC offset tags and improved Chinese and UTF-16 lyrics decoding.
- Localized Dock playback actions and library, playback, and lyrics errors in English and Chinese.

## [0.12.0] - 2026-09-10

### Changed
- Updated library backgrounds to follow the system's wallpaper tinting, with native song table headers that keep scrolling content separate.
- Switched sidebar row selection to the native list appearance and behavior.
- Changed the player bar progress and volume sliders to grayscale, made the progress thumb solid on hover, and marked favorites with a monochrome filled heart.

### Fixed
- Limited sidebar resizing to 204–300 points so it cannot grow too wide and crowd the library content.
- Kept the volume popover and slider layout stable as the speaker icon changes during volume adjustment.

## [0.11.2] - 2026-07-29

### Changed

- Kept embedded and standalone lyrics dark regardless of the app theme.

## [0.11.1] - 2026-07-29

### Changed

- Added light and dark appearances for the app icon.

## [0.11.0] - 2026-07-29

### Changed

- Included the commit identifier in Debug version displays.

### Fixed

- Fixed an uncovered toolbar strip when embedded lyrics entered full screen.
- Improved click and hover areas for lyrics close and track navigation controls.

## [0.10.0] - 2026-07-20

### Added

- Added an option to show lyrics inside the main window or in a separate window.

### Changed

- Refined Songs and Favorites backgrounds, table headers, and sort indicators.

### Fixed

- Fixed interrupted Chinese text input and searches carrying over to album or artist detail pages.
- Fixed repeated shuffle actions producing the same song order.

## [0.8.0] - 2026-06-18

### Added

- Added smooth artwork transitions between album and artist grids and detail pages.
- Added an optional lyrics blur effect.
- Remembered lyrics and Settings window size and position.
- Added player bar actions to add the current song to a playlist or block it.

### Changed

- Reorganized Settings and made library folder information more compact.
- Renamed the sidebar Folders section to Library and refined sidebar highlighting and add buttons.
- Hid album and artist toolbar searches on detail pages.

### Fixed

- Fixed automatic track advancement, shuffle restoration and cycling, and clearing the upcoming queue.
- Improved selected song contrast in the light theme.
- Fixed Settings window resizing and scrolling.
- Added confirmation before removing a library folder from the app.

## [0.7.0] - 2026-05-30

### Added

- Added Dock menu playback controls.
- Added audio fading when pausing and resuming.

### Changed

- Counted a play only after 60% of a song has been played.
- Smoothed lyrics scrolling and moved the highlighted line closer to the top.
- Animated playback control icons and softened lyrics background edges.

### Fixed

- Fixed artwork and lyrics background flashes during track changes with smooth crossfades.
- Used gray placeholders for songs without artwork instead of the previous song's cover.

## [0.6.0] - 2026-05-29

### Added

- Added Space key playback controls in the main and lyrics windows.
- Remembered sidebar visibility between launches.
- Added compact navigation tabs when the sidebar is hidden and back buttons on album and artist detail pages.

### Changed

- Made low-volume adjustments more precise.
- Standardized toolbar search fields and sorting controls.

### Fixed

- Fixed duplicate sidebar toggle buttons and missing toolbar search icons.

## [0.5.0] - 2026-05-24

### Changed

- Limited song table columns to half the screen width so oversized columns remain easy to shrink.

### Fixed

- Fixed Songs and playlist scrollbars stopping above the bottom of the page.

## [0.4.0] - 2026-05-23

### Added

- Licensed the project under GPLv3.

### Changed

- Separated sort field and direction choices and kept them synchronized with table header sorting.
- Improved hover areas for playback controls and album and artist pages.
- Matched sidebar add button colors to section controls.

### Fixed

- Fixed automatic track advancement in sequential and shuffle playback.
- Fixed player bar hover effects changing its layout or extending beyond the artwork.

## [0.3.0] - 2026-05-23

### Added

- Added Favorites and favorite controls in the player bar and song tables.
- Added optional song columns with saved visibility, order, and widths for Songs, playlists, and folders.
- Added consistent play and shuffle controls across library pages.
- Added song blocking, unblocking in Settings, and removal from playlists.
- Added Chinese, English, and system language options, plus a system theme option.
- Restored the previous song, queue, playback position, shuffle, and repeat settings.
- Kept Debug app libraries and preferences separate from the release app.

### Changed

- Replaced Recently Played with Favorites.
- Moved lyrics to a resizable window with native full-screen support and improved scrolling and highlighting.
- Organized the queue into history, now playing, and up next, including the actual shuffle order.
- Reorganized Settings into one page with theme and language menus and an updated About section.
- Improved song table backgrounds and left scroll space for the floating player bar.
- Indexed artists separately for songs with multiple artists while preserving their displayed names.

### Fixed

- Fixed misplaced folder scrollbars and column widths resetting after sorting.
- Fixed stale row highlights while scrolling and missing playlist drop feedback.
- Fixed album detail backgrounds in dark mode and toolbar controls appearing above lyrics.
- Reduced lyrics window memory usage and stutter during resizing.

## [0.2.0] - 2026-05-16

### Added

- Added macOS Now Playing, media key, and Control Center support.
- Added playlist name and description editing.
- Added collapsible and reorderable sidebar sections.
- Added song table selection, double-click playback, context menus, column resizing, and dragging into playlists.
- Added album and artist browsing with cached artwork for better performance in large libraries.
- Added hover and pressed feedback throughout the app and icons in song context menus.

### Changed

- Refined the floating glass player bar, queue, and volume controls.
- Unified sidebar and control colors and moved searches and sorting to page toolbars.
- Moved Settings to a dedicated window.
- Added artist-to-album navigation with searches scoped to the current page.
- Improved detail page layouts and table resizing, retaining compact folder tables with horizontal scrolling.
- Set the minimum window size to 980 × 600 and refined sidebar, player bar, and grid sizing to fit.

### Removed

- Removed the nonfunctional equalizer placeholder.

### Fixed

- Fixed Settings and queue access and added playlist and folder deletion confirmations.
- Fixed sidebar collapse and artist navigation leaving the sidebar inaccessible or cramped.
- Fixed artwork flicker and table scrollbars obscuring duration and menu controls.
- Fixed clicks passing through the floating player bar.

## [0.1.0] - 2026-04-21

### Added

- Released the initial local music player with playback, seeking, and a floating player bar.
- Added drag-and-drop import, multiple library folders, and music scanning.
- Added sidebar navigation and basic music sorting.
