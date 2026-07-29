# Implementation Notes

These notes capture recurring Mint Player failure modes and the established implementation patterns that avoid them. They are organized by subsystem rather than by task date.

## Native Search Field Editing

**Symptoms:** Placeholder and edited text can become vertically misaligned, Chinese input composition can be interrupted, and large libraries can be filtered repeatedly while text is still marked.

**Cause:** `NSSearchField` uses separate native drawing and editing paths, while `controlTextDidChange` also fires during input method composition.

**Avoid:** Replacing `NSSearchFieldCell`, manually changing field-editor insets, immediately publishing every search-string change, or writing marked text into SwiftUI search state.

**Use:** Keep a plain `NSSearchField` in `NSViewRepresentable`. Ignore changes while its editor has marked text, debounce completed edits against the binding active when the edit occurred, cancel pending work when dismantled, commit immediately on submit or end editing, and do not overwrite the field from stale binding state while it is being edited. Keep list-level and detail-level search state in separate bindings.

## Shuffle Queue Generation

**Symptoms:** Repeatedly invoking Shuffle for the same list can appear deterministic.

**Cause:** A valid random permutation may exactly match the current queue, especially for small song lists.

**Avoid:** Assuming every call to `shuffled()` necessarily produces a visibly different order.

**Use:** Generate a fresh queue with `SystemRandomNumberGenerator`. When there is more than one song, change the permutation if it exactly matches the current queue.

## Window Restoration

**Symptoms:** A SwiftUI window visibly jumps from its default frame to a restored frame after appearing.

**Cause:** Post-creation AppKit frame mutation runs after the system has already shown the window.

**Avoid:** Delayed frame restoration, close-and-reopen workarounds, or timers.

**Use:** Apply the initial frame with SwiftUI scene-level `defaultWindowPlacement`, then use a narrow AppKit observer only to save frame changes.

## Lyrics Scrolling Performance

**Symptoms:** Lyrics highlighting and scrolling become janky during playback.

**Cause:** Playback-cadence updates invalidate too much of the SwiftUI view tree.

**Avoid:** Full view rebuilds, unrelated animation state, or expensive per-frame effects.

**Use:** Keep lyric content in SwiftUI, use the focused AppKit scroll bridge only for deterministic offset animation, and limit blur to simple per-line radius changes. Verify both scroll smoothness and highlight timing after relevant changes.

## Artwork And Background Transitions

**Symptoms:** Track changes show a black or empty intermediate frame, or a song without artwork temporarily displays the previous song's image.

**Cause:** The old artwork or background is cleared before the new state is ready.

**Avoid:** Resetting image state to `nil` as a visible transition step.

**Use:** Crossfade directly from the old image to the new image. For songs without artwork, crossfade to the gray placeholder and gray lyrics background.

## Database Compatibility

**Symptoms:** Rescans or model changes lose playlists, favorites, blocked state, play counts, sources, or other user metadata.

**Cause:** Persisted fields or IDs are renamed, removed, or replaced without accounting for SQLite merge behavior.

**Avoid:** Casually changing persisted IDs, fields, schema, or rescan merge logic.

**Use:** Preserve persistent fields during rescans and add an explicit migration when a schema change is required.

## Embedded Lyrics Presentation And Toolbar Ownership

**Symptoms:** Only part of the lyrics page animates, default sidebar controls remain above the overlay, toolbar items leak through, window traffic lights move, or full screen leaves an uncovered toolbar strip above the lyrics surface.

**Cause:** Asynchronous artwork/background content and AppKit lyric scrolling do not necessarily enter the render tree together. The sidebar toggle belongs to the sidebar column of `NavigationSplitView`, and the native titlebar and toolbar share window chrome. During a system full-screen transition, AppKit can recompute the native toolbar's content-layout reservation after SwiftUI has laid out the embedded lyrics surface.

**Avoid:** Independent child transitions, conditionally replacing the library view, removing `.toggleSidebar` through AppKit, permanently applying `.toolbar(removing: .sidebarToggle)`, removing or replacing the native toolbar, or depending on its close item while full-screen lyrics are active.

**Use:** Mount the complete fixed-size lyrics shell offscreen before animating it. Keep the library mounted but noninteractive, remove the default sidebar item dynamically at `SidebarView`, and hide page-specific toolbar items through `isPlayerOverlayPresented`. Preserve the native toolbar for normal and windowed presentation. While embedded lyrics are full screen, temporarily hide the retained toolbar through the focused `NSWindow` bridge, fill the complete content area, and use a lyrics-owned immersive close control. Reapply the full-screen state on AppKit transition notifications and restore all captured titlebar and toolbar properties on exit or dismissal.

## macOS Toolbar Trailing Placement

**Symptoms:** A toolbar action fails to compile for macOS or appears near the center instead of at the trailing edge.

**Cause:** `.topBarTrailing` is unavailable on macOS, while semantic placements such as `.secondaryAction` allow the system to choose a section.

**Avoid:** Assuming toolbar placement names have identical availability or geometry across Apple platforms.

**Use:** On the macOS 26 deployment target, place `ToolbarSpacer(.flexible)` before an `.automatic` item when an action must remain at the toolbar tail. Verify both sidebar-expanded and sidebar-collapsed layouts.
