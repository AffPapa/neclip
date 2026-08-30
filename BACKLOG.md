# Public backlog

NeClip deliberately stays small: fast local history, snippets and safe keyboard
layout correction. Accounts, cloud sync, subscriptions, telemetry and AI are
not planned.

## Done in 1.3.0

- Native menu-bar history and snippet sections
- Search, keyboard-first paste and quick selection
- Pins, local OCR, FTS5 and bounded storage
- Privacy controls, exclusions, pause and ignore-next-copy
- Manual and conservative automatic EN/RU layout correction
- macOS pasteboard authorization UX and fail-closed denial
- Swift 6 strict concurrency and one pinned dependency
- Hardened signed/notarized DMG pipeline
- Standalone GitHub Pages project landing

## Done in 1.3.1

- Repository-owned GitHub Pages update manifest with strict GitHub Release URL
  validation
- Machine-readable GitHub source-of-truth index for website integrations
- Removal of the obsolete AffPapa landing implementation from this repository

## Next

- Verify first-run pasteboard wording across currently supported macOS releases
- Add an opt-in shortcut recorder if three fixed shortcuts become a real conflict
- Expand local layout pairs only when system-layout tests can keep false fixes low
- Add reusable snippet-folder ordering without making the editor heavier

## Not planned

- Accounts or cloud synchronization
- Cross-device clipboard transport
- Analytics, telemetry or advertising
- AI processing of clipboard contents
- A permanent Dock icon or a large workspace-style main window
