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

## Done in 1.3.2

- Pin/unpin, save-as-snippet, individual delete and exact undo in the native
  menu, with search-first keyboard commands
- Visible explanation when a global shortcut is already occupied
- Single storage-driven menu refresh path and removal of the unused large window
- Weekly dependency updates plus immutable releases, CodeQL, vulnerability
  alerts, action SHA enforcement and protected `main`
- Private vulnerability reporting and a public bug form that forbids real
  clipboard contents

## Done in 1.4.0

- One system appearance for status-item and global-hotkey menus
- User-defined 16–96 character menu labels with grapheme-safe ellipsis
- Conflict-aware shortcut recording for manual layout correction and the new
  off-only automatic-correction safety action
- Visible snippet folders, empty and unfiled sections, folder CRUD and moving
  snippets between folders
- Draft-safe autosave that flushes before navigation and window close and keeps
  failed edits available for retry

## Done in current unreleased source

- Direct recent-history sequential paste without a collection mode
- Configurable, conflict-safe history, snippet and sequential-paste shortcuts
- Five concise Settings sections instead of one long form
- Immediately discoverable snippet editing with automatic initial selection,
  full-row edit actions and explicit autosave status
- Bounded browsing for 100 recent and 100 pinned values, with full search for
  older local history
- Simpler search/action labels and removal of obsolete paste compatibility code

## Next

- Verify first-run pasteboard wording across currently supported macOS releases
- Expand local layout pairs only when system-layout tests can keep false fixes low
- Measure menu-open latency with real 1,000-item and 250 MB databases before
  changing the current 100-item browse window
- Consider manual drag ordering only if folder counts grow beyond the current
  compact section model

## Not planned

- Accounts or cloud synchronization
- Cross-device clipboard transport
- Analytics, telemetry or advertising
- AI processing of clipboard contents
- A permanent Dock icon or a large workspace-style main window
