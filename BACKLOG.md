# NeClip public roadmap

NeClip remains a small local macOS utility: clipboard history, snippet folders
and safe EN/RU layout correction. Accounts, cloud sync, subscriptions,
telemetry, advertising and AI processing are not planned.

## Current public release — 2.5.8 / build 37

Released 12 September 2026 after the normal Developer ID, notarization,
stapling, Gatekeeper, mounted-DMG, independent public-download and required-CI
gates. [Download NeClip 2.5.8](https://github.com/AffPapa/neclip/releases/download/v2.5.8/NeClip-2.5.8.dmg)
and read the [release evidence](docs/RELEASE-2.5.8-STATUS.md).

- Store clipboard images without automatic recognition or derived-text writes.
- Preserve existing images and legacy metadata without a destructive migration.
- Retain the verified screenshot text-entry and export fixes.

## Current verification priorities

- Verify permissions and screen capture across supported macOS versions and
  physical display configurations.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

- Accounts, cloud sync, subscriptions, telemetry or advertising.
- AI processing of clipboard contents.
- A permanent Dock window, search, keyword fields, tags or smart collections.
