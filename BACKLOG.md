# NeClip public roadmap

NeClip remains a small local macOS utility for clipboard history and snippet folders.

## Current public release — 3.0.0 / build 55

Released 27 September 2026 after required Swift CI, CodeQL and secret scan; Developer ID signing, Apple notarization, stapling, Gatekeeper, mounted-DMG and independent public-download checks passed. Download the [NeClip 3.0.0 DMG](https://github.com/AffPapa/neclip/releases/download/v3.0.0/NeClip-3.0.0.dmg) or [ZIP archive](https://github.com/AffPapa/neclip/releases/download/v3.0.0/NeClip-3.0.0.zip). See [release evidence](docs/RELEASE-3.0.0-STATUS.md).


## Current scope

- Local text, image and file history with search and explicit paste modes.
- Snippet folders, native editing, undo and local template tokens.
- Three configurable shortcuts, privacy exclusions and pause controls.
- Private local database backup and validated restore.
- No screenshot capture/editor or keyboard-layout correction/switching.

## Current verification priorities

- Investigate rapid repeated sequential paste: overlapping requests can repeat an item after a failed earlier operation. State-level ordering is reproducible; physical keyboard reproduction remains pending.
- Verify clipboard permissions and cross-app paste on additional supported macOS versions.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

Accounts, cloud synchronization, subscriptions, telemetry, advertising, AI processing of clipboard contents, screenshot tools, keyboard-layout tools, a permanent Dock window, cloud search, tags or smart collections.
