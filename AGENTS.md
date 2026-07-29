# Mint Player Agent Guide

## Scope

Mint Player is a native macOS local music player built with Swift 5, SwiftUI, focused AppKit bridges, AVFoundation, MediaPlayer, SQLite, and `UserDefaults`. The only build entry point is `MintPlayer.xcodeproj`, and the minimum supported system is macOS 26.0.

Use the focused project documents instead of expanding this file:

- [Architecture](docs/architecture.md): system boundaries, module responsibilities, data flow, and durable design decisions.
- [Development Guide](docs/development.md): repository layout, coding standards, commands, Git/release workflow, and manual regression coverage.
- [UI and Interaction Guidelines](docs/ui-guidelines.md): native macOS behavior and feature-specific UI constraints.
- [Implementation Notes](docs/implementation-notes.md): recurring failure modes, causes, and proven implementation patterns.

## Required Working Rules

- Work on the current branch by default.
- Unless explicitly requested, do not run builds or tests.
- Unless explicitly requested, prefer native macOS controls and system behavior over custom implementations.
- Read the relevant implementation and the focused documents above before changing behavior. Prefer existing helpers and narrow extensions over rewrites.
- Do not revert user changes. If the worktree is dirty, touch only task-related files.
- Preserve public API and SQLite compatibility unless the user explicitly approves a breaking change or migration.
- Do not introduce a package manager, dependency, test target, script, lint tool, or CI configuration unless explicitly requested.
- Do not leave fake or placeholder UI. Implement the backing behavior or ask the user.
- Do not hide native control issues with timers, forced rebuilds, or close-and-reopen workarounds. Understand the SwiftUI/AppKit boundary first.
- When changing user-facing text, buttons, labels, or descriptions, update every supported language in `SettingsManager`.

## Documentation And Releases

- Do not write to `README.md` without explicit permission. When it changes, keep `README_zh.md` synchronized.
- Do not change the version or write changes into an existing released section of `CHANGELOG.md` unless explicitly requested.
- Record user-facing unreleased changes under `Unreleased`; do not add version-only or ordinary documentation-maintenance entries.
- Git tags matching `vMAJOR.MINOR.PATCH` are the only release version source. Do not manually update Xcode version placeholders.
- Keep release headings in `CHANGELOG.md` aligned with Git tags when preparing a release.

## Git Safety

- Do not commit, tag, push, or create pull requests unless explicitly requested.
- Confirm the commit message with the user before committing.
- Use English Conventional Commits, for example `feat: improve playback controls`.
- Before committing, run `git status --short` and confirm that only task-related files are staged.
- Never stage secrets, personal files, build products, Xcode user state, DerivedData, `.DS_Store`, local caches, or user music files.

## Data Safety

- Never commit secrets, tokens, `.env` files, personal paths, user music files, or real user library data.
- Do not hardcode absolute user paths in source or documentation.
- Library folder removal must only remove the app's reference and internal index entries; it must never delete the user's audio files.
- Keep permission requests minimal and limited to local music management.

## Validation

The repository has no third-party dependency manifest, test target, lint configuration, CI configuration, or custom build script. Do not assume those facilities exist or create them without approval.

When the user requests verification, use the commands and targeted manual regression checklist in [Development Guide](docs/development.md). If a `Reference Proj.` directory exists, treat it as reference material only; it is not part of the Mint Player build.
