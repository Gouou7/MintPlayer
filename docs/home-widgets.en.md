# Home Widget Design Specification

The top of Home uses widgets with fixed grid dimensions. This document defines grid sizes, gaps, the current arrangement, and card content styles for future cards. All dimensions are macOS logical points (pt), rather than screen pixels.

## Grid Basics

| Property | Specification |
| --- | --- |
| Base cell | 75 × 75 pt |
| Horizontal gap | 16 pt |
| Vertical gap | 16 pt |
| Grid pitch | 91 pt (75 + 16) |
| Size notation | Columns × rows, corresponding to width × height |
| Coordinate notation | Column, row, starting at 0; the origin is the widget area's top left |

A widget spanning multiple cells includes the gaps between those cells, but excludes gaps outside the widget:

```text
Length for span n = 75 × n + 16 × (n − 1) = 91 × n − 16
Widget width = 91 × column span − 16
Widget height = 91 × row span − 16
Widget origin x = 91 × column coordinate
Widget origin y = 91 × row coordinate
```

## Size Reference

These sizes follow the same grid formula. The current cards use 2×1, 4×2, and 2×2; the other sizes are available for future cards.

| Grid size (columns × rows) | Actual size (width × height, pt) |
| --- | --- |
| 1×1 | 75 × 75 |
| 1×2 | 75 × 166 |
| 2×1 | 166 × 75 |
| 2×2 | 166 × 166 |
| 3×1 | 257 × 75 |
| 3×2 | 257 × 166 |
| 4×1 | 348 × 75 |
| 4×2 | 348 × 166 |
| 2×4 | 166 × 348 |
| 4×4 | 348 × 348 |
| 6×2 | 530 × 166 |
| 8×2 | 712 × 166 |

For example, 2×4 is two columns wide and four rows tall, so its orientation differs from 4×2.

## Current Arrangement

| Widget | Grid size | Actual size (pt) | Column, row |
| --- | --- | --- | --- |
| Favorites | 2×1 | 166 × 75 | 0, 0 |
| Shuffle | 2×1 | 166 × 75 | 0, 1 |
| Resume Playback | 4×2 | 348 × 166 | 2, 0 |
| Lyrics | 2×2 | 166 × 166 | 6, 0 |

Favorites and Shuffle are stacked on the left, Resume Playback sits in the middle, and Lyrics appears on the right. The complete arrangement occupies 712 × 166 pt. When available content width is less than 712 pt, Lyrics moves to column 0, row 2, while the first three cards keep their positions. Cards keep fixed dimensions, align to the left, and do not support custom drag rearrangement.

## Card Content and Appearance

Cards share system fonts, the system accent color, and native `.regularMaterial`.
Card border: 1 pt, in the primary foreground color at 5% opacity.
Card corner radius: 20 pt.

### Recommended Parameters

- Primary text: system `.headline`.
- Secondary text: system `.caption`.
- Padding on all sides: 16 pt.

### Current Card Parameters

- Favorites and Shuffle: a 43 × 43 pt circular icon background, 23 pt symbol, and 10 pt spacing between icon and text. Titles use a 14 pt semibold system font; descriptions use `.caption`. Descriptions are “Revisit favorites” and “All library songs.” When no songs are available, an empty state replaces the description and playback is disabled.
- Resume Playback: 134 × 134 pt artwork with a 9 pt corner radius and 16 pt spacing to the text. The title uses 20 pt semibold text with at most two lines; artist and album use 16 pt semibold text with at most one line. The bottom playback control is a 114 × 43 pt capsule, retaining play, pause, and resume behavior.
- Lyrics: the current song's artwork fills the background, scaled to 1.2 times its size, blurred by 18 pt, and covered by a black overlay. Text uses a 12 pt semibold system font, with the primary foreground color for the current line and the secondary color for other lines, matching full-screen lyrics. Rows have a minimum height of 25 pt, 16 pt horizontal padding on each side, and fading top and bottom edges. Synced lyrics scroll with playback to position the current line's center at 30% of the card height measured from the top; plain lyrics can be scrolled manually. Clicking the card opens embedded full-screen lyrics, where individual lines can be clicked to seek. Idle, loading, missing lyrics, and loading failures display appropriate messages. Missing artwork uses a gray placeholder background. Opening lyrics is disabled until a song is selected.

Lyrics reuses the existing custom lyrics file, encoding, and timing adjustment settings. Reduce Motion disables animated automatic scrolling and artwork crossfades. All four widget types can be added or removed using the context menu, each type can appear once, and visibility is restored after restarting.

The top of Home follows the system's native toolbar scroll edge effect, without clipping scrolling content at the outer page boundary. The [automatic style on macOS 27](https://developer.apple.com/videos/play/wwdc2026/289/) determines the transition from the window title and toolbar content.

## Implementation References

- [HomeWidgetArea.swift](../MintPlayer/Views/Library/Home/HomeWidgetArea.swift): grid constants, type spans, fixed coordinates, card content, and management menus.
- [HomeLyricsWidget.swift](../MintPlayer/Views/Library/Home/HomeLyricsWidget.swift): widget lyrics loading, background, and empty states.
- [LyricsOverlayView.swift](../MintPlayer/Views/Player/LyricsOverlayView.swift): shared synced lyrics highlighting and native scrolling.
- [HomeView.swift](../MintPlayer/Views/Library/Home/HomeView.swift): Home content width, page padding, and section spacing.
- [MintTheme.swift](../MintPlayer/Views/Shared/MintTheme.swift): shared hover and press effects.
- [ListPlaybackControls.swift](../MintPlayer/Views/Shared/ListPlaybackControls.swift): shared playback button label dimensions elsewhere in the app.
