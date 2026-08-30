# Changelog

All known NeClip releases are documented here. A version is downloadable only
after Developer ID signing, Apple notarization, stapling, Gatekeeper and exact
DMG checksum verification have passed.

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
  releases, vulnerability alerts, security updates, action SHA enforcement,
  CodeQL default setup and deletion/force-push protection for `main`.

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

- Source tests, Thread Sanitizer and strict Swift 6 release build: passed for 1.3.1.
- The app and DMG are signed with Developer ID, notarized by Apple, stapled and
  accepted by Gatekeeper outside and inside the mounted image.
- Public download: [NeClip 1.3.1](https://github.com/AffPapa/neclip/releases/download/v1.3.1/NeClip-1.3.1.dmg).
- SHA-256: `da63b10ed6a538f5608e0dc7af898a3b5604493a76157fc8ed4dbcaf00fffdf6`.
