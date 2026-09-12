# NeClip public roadmap

NeClip remains a small local macOS utility: clipboard history, snippet folders
and safe EN/RU layout correction. Accounts, cloud sync, subscriptions,
telemetry, advertising and AI processing are not planned.

## Current public release — 2.6.0 / build 38

Released 12 September 2026 after the normal Developer ID, notarization,
stapling, Gatekeeper, mounted-DMG, independent public-download and required-CI
gates. [Download NeClip 2.6.0](https://github.com/AffPapa/neclip/releases/download/v2.6.0/NeClip-2.6.0.dmg)
and read the [release evidence](docs/RELEASE-2.6.0-STATUS.md).

- Save any text history item as a raw-text snippet with folder selection and duplicate checks.
- Search local history with bounded text, type, application and date filters.
- Use explicit original/plain/copy-only paste actions and inspect capture status.
- Keep screenshot export format and safely back up or restore the local database.
- Preview snippet tokens and install/remove bilingual starter snippets.

## Current verification priorities

- Verify permissions and screen capture across additional supported macOS versions
  and physical display configurations.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

- Accounts, cloud sync, subscriptions, telemetry or advertising.
- AI processing of clipboard contents.
- A permanent Dock window, cloud search, tags or smart collections.
