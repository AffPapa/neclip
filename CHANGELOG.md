# Changelog

All known NeClip releases are documented here. A version is downloadable only
after Developer ID signing, Apple notarization, stapling, Gatekeeper and exact
DMG checksum verification have passed.

## Unreleased

- Added structured history search by base type, smart text category, source
  application, date window and pin state, plus a bounded fuzzy fallback.
- Added a focused full-item inspector with transactional text editing,
  renaming, safe HTTP(S)/file opening and direct OCR-text paste.
- Added memory-only sequential paste, then simplified it after product review:
  `⌃⌘V` now walks a stable snapshot of recent history without start/stop
  collection, resets after 30 seconds or a new copy, and stores identifiers only.
- Made the history, snippets and sequential-paste shortcuts locally
  configurable. All five NeClip shortcuts share conflict validation;
  registration failure preserves the previous working shortcut.
- Reorganized Settings into General, Keys, Privacy, Layout and Data sections.
- Expanded bounded menu browsing from 40 to 100 ordinary and pinned entries,
  while keeping older values searchable without constructing 1,000 menu rows.
- Simplified search wording and renamed first-result actions to explicitly say
  they operate on the top visible item.
- Removed obsolete paste compatibility wrappers left behind by the deleted
  legacy history panel.
- Added age retention for ordinary history, independent image capture,
  local sensitive-phrase exclusions and a default plain-text paste preference.
- Added a nested, offline transform menu for whitespace, case, lines, URL and
  JSON operations; transforms paste a temporary result without mutating history.
- Added deterministic, versioned snippet JSON export and atomic merge-only
  import. History and usage metadata are never exported.
- Documented the 100-function competitor catalogue and the scored top-20
  selection in `docs/FEATURE-RESEARCH-2026-08-31.md`.
- Expanded the local suite to 108 checks (one optional external-database case is
  skipped unless its disposable fixture is supplied); strict Swift 6 release
  compilation and full-history secret scanning pass.

## 1.4.0 — 31 August 2026

- Unified the complete native menu tree under the application's current system
  appearance, so status-item and global-hotkey entry points no longer inherit
  different light/dark presentation contexts.
- Added a Settings field for menu-label length (16–96, default 64). Multiline
  and Unicode whitespace collapse to one line; truncation counts complete Swift
  graphemes and appends an ellipsis without splitting emoji or combined text.
- Made manual layout correction configurable and added a configurable,
  deliberately off-only shortcut for immediately disabling automatic
  correction. Conflicting candidates fail transactionally and preserve the old
  working registration and persisted preference.
- Rebuilt the snippet editor as a compact two-column interface with visible
  folders, empty sections, an explicit unfiled section, folder-aware search,
  fixed labels, folder create/rename/delete and snippet moves.
- Fixed a draft-loss race in the previous editor. Pending edits now flush before
  selection, folder operations, window close, view disappearance and app exit;
  failed saves remain visible and block navigation until retry succeeds.
- Preserved snippets when their folder is removed and prevented stale editor
  state from overwriting newer usage counters and timestamps.
- Expanded the suite from 45 to 76 tests. The full suite, strict Swift 6
  complete-concurrency build, sanitizers, GitHub CI and CodeQL passed.
- Signed and notarized the exact app and DMG, stapled both tickets, passed
  Gatekeeper outside and inside the read-only mounted public image, and
  independently matched the GitHub download to its SHA-256 file.

## 1.3.2 — 31 August 2026

- Restored individual item management inside the compact native menu without
  bringing back a large main window: pin/unpin, save text as a snippet, delete
  and undo now act on the first visible result.
- Added `Command-P`, `Command-S`, `Command-Delete` and `Command-Z` search-first
  keyboard actions with an explicit, discoverable submenu.
- Made snippet deletion exactly reversible, preserving its identifier, keyword,
  pin, usage counters and timestamps; undo safely moves it out of a folder that
  was deleted in the meantime.
- Added visible recovery guidance when a fixed global shortcut is already owned
  by macOS or another application.
- Removed the unreachable 846-line legacy clipboard window and the duplicate
  menu refresh after every accepted copy.
- Updated the sole source dependency from GRDB.swift 7.10.0 to 7.11.1 after the
  newly enabled Dependabot check identified the current upstream release.
- Added weekly SwiftPM and GitHub Actions Dependabot checks. Enabled immutable
  releases, private vulnerability reporting, vulnerability alerts, security
  updates, GitHub-owned-only Actions with full-SHA enforcement, CodeQL default
  setup and deletion/force-push protection for `main`.

## 1.3.1 — 30 August 2026

- Moved the manual update manifest from AffPapa hosting to the repository-owned
  GitHub Pages endpoint.
- Restricted update metadata to the exact GitHub Pages manifest path and exact
  `AffPapa/neclip` GitHub Release download path.
- Added fail-closed validation for semantic version, build number, SHA-256,
  response size, MIME type, URL credentials, ports, query and fragment.
- Added a machine-readable GitHub source-of-truth index for website and release
  integrations.
- Removed the obsolete AffPapa landing implementation from the NeClip repository.

## 1.3.0 — 30 August 2026

- Rebuilt the primary interface as a compact native menu inspired by ClipMenu
  and Clipy: history inline, older items grouped by tens, snippets in folders.
- Kept NeClip exclusively in the macOS menu bar and out of the Dock.
- Added immediate search, keyboard navigation, quick keys 1–9, plain-text paste,
  copy-only mode, pinned history and reversible history deletion.
- Added starter snippets, snippet folders, keywords, local placeholders and a
  focused editor.
- Added manual EN/RU layout correction with Option-Shift-L and Control-Return
  correction directly from clipboard history.
- Added conservative, default-off automatic layout correction after Space with
  dictionary validation, protected contexts, bounded RAM and five-second undo.
- Added pause, ignore-next-copy, excluded applications, concealed/transient
  pasteboard filtering, source attribution guards and a 250 MB hard quota.
- Added bounded image decoding, thumbnails, serialized local OCR and FTS5 search.
- Added macOS 15.4+ pasteboard privacy onboarding, visible authorization state
  and fail-closed behavior for Always Deny.
- Migrated to real Swift 6 language mode and strict concurrency.
- Upgraded and exactly pinned GRDB.swift 7.10.0; removed the HotKey dependency
  in favor of the native Carbon global-hot-key API.
- Hardened release automation so existing artifacts survive any failed gate.

## 1.1.1

- Last known signed, notarized and publicly downloadable baseline before 1.3.0.
- Local clipboard history, search, snippets and menu-bar operation.

## Verification status

- Source tests, Thread Sanitizer, Address Sanitizer, strict Swift 6 release
  build, GitHub CI and CodeQL: passed for 1.4.0.
- The app and DMG are signed with Developer ID, notarized by Apple, stapled and
  accepted by Gatekeeper outside and inside the mounted image.
- Public download: [NeClip 1.4.0](https://github.com/AffPapa/neclip/releases/download/v1.4.0/NeClip-1.4.0.dmg).
- SHA-256: `0dc548a6625a74c6fac22bb4bf128ae174ab192631025cf7095a4d7fcceaf612`.
