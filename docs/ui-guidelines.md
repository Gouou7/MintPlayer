# UI And Interaction Guidelines

## Native macOS Foundations

- Keep the main sidebar aligned with native `NavigationSplitView` and system Liquid Glass behavior. Do not replace it with custom-painted chrome.
- The bottom player bar is a centered floating Liquid Glass control and must intercept clicks so events do not pass through to content underneath.
- Search fields live in the top-right toolbar by default and use native macOS search controls.
- Keep toolbar search fields plain and native. Hide them on album and artist detail pages rather than repurposing them for detail-level search.

## Tables, Albums, And Artists

- Songs, playlists, folder views, and detail-page song lists depend on `NativeSongTableView`.
- Preserve native selection, multi-selection, double-click playback, sorting, context menus, trailing actions, column resizing, and dragging.
- Albums and Artists browsing pages remain responsive grids with at least four primary items visible per row at the minimum window width.
- Artists use a drill-in flow across artist browsing, artist detail, and album detail. Do not reintroduce a permanent three-column artist layout.
- Use `matchedGeometryEffect` only for artwork continuity. Do not apply it to page containers, text, tables, or whole cards.

## Lyrics Rendering

- Full-screen lyrics scrolling uses the focused AppKit `NSScrollView` bridge for deterministic animated offsets. SwiftUI remains the source of truth for lyric content and highlighting.
- Keep playback-cadence updates narrowly scoped. Avoid broad view invalidation, unrelated animation state, and expensive per-frame effects; limit blur to simple per-line radius changes.
- Full-screen lyrics artwork and blurred backgrounds crossfade directly between old and new images. Do not clear to black or an empty frame during normal track changes.
- Songs without artwork use the gray placeholder artwork and gray lyrics background, never a previous song's artwork.

## Embedded Lyrics Presentation

- Reuse `LyricsOverlayView`; do not fork lyrics content between embedded and standalone presentation modes.
- Keep the underlying library mounted so sidebar state, scrolling, table selection, and album or artist navigation survive dismissal.
- While the overlay is mounted, disable and accessibility-hide the library instead of replacing it.
- Use separate mounted and visible states. Apply movement, or reduced-motion opacity, to one fixed-size composited shell containing the complete lyrics surface.
- Do not give the background, artwork, scrolling content, or controls independent page transitions.
- Remove the default sidebar toggle dynamically from the `SidebarView` that owns it with `.toolbar(removing: isLyricsMounted ? .sidebarToggle : nil)`. Permanent removal breaks normal sidebar control, while disabling the split view only grays the button.
- Keep the native window toolbar mounted for the normal main interface and windowed lyrics presentation. Do not remove or replace it.
- Temporarily make the titlebar transparent through the focused `NSWindow` bridge, and restore every captured window property on dismissal or teardown.
- When embedded lyrics enter full screen, let the focused `NSWindow` bridge temporarily hide the retained toolbar so the lyrics surface fills the complete window. Use the lyrics-owned immersive control layer for closing, then restore toolbar visibility as full screen or lyrics presentation ends.
- On macOS 26, keep the windowed embedded-lyrics close action at the toolbar tail with `ToolbarSpacer(.flexible)` followed by an `.automatic` toolbar item. `.topBarTrailing` is unavailable on macOS, and `.secondaryAction` may be placed near the center.
- Library search and detail-navigation toolbar items must honor `isPlayerOverlayPresented` so they do not appear above embedded lyrics.

See [Architecture](architecture.md) for the presentation boundary and [Implementation Notes](implementation-notes.md) for the failure modes behind these constraints.
