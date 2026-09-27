# NeClip public roadmap

NeClip remains a small local macOS utility for clipboard history and snippet folders.

## Current public release — 3.0.1 / build 56

Released 27 September 2026 after required Swift CI, CodeQL and secret scan; Developer ID signing, Apple notarization, stapling, Gatekeeper, mounted-DMG and independent public-download checks passed. Download the [NeClip 3.0.1 DMG](https://github.com/AffPapa/neclip/releases/download/v3.0.1/NeClip-3.0.1.dmg) or [ZIP archive](https://github.com/AffPapa/neclip/releases/download/v3.0.1/NeClip-3.0.1.zip). See [release evidence](docs/RELEASE-3.0.1-STATUS.md).


## Current scope

- Local text, image and file history with search and explicit paste modes.
- Snippet folders, native editing, undo and local template tokens.
- Three configurable shortcuts, privacy exclusions and pause controls.
- Private local database backup and validated restore.
- No screenshot capture/editor or keyboard-layout correction/switching.

## Current verification priorities

- Verify clipboard permissions and cross-app paste on additional supported macOS versions.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

Accounts, cloud synchronization, subscriptions, telemetry, advertising, AI processing of clipboard contents, screenshot tools, keyboard-layout tools, a permanent Dock window, cloud search, tags or smart collections.
