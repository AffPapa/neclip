# Changelog

All known NeClip releases are documented here. A version is downloadable only
after Developer ID signing, Apple notarization, stapling, Gatekeeper and exact
DMG checksum verification have passed.

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

- Source tests, Thread Sanitizer and strict Swift 6 release build: passed for 1.3.0.
- The app and DMG are signed with Developer ID, notarized by Apple, stapled and
  accepted by Gatekeeper outside and inside the mounted image.
- Public download: [NeClip 1.3.0](https://github.com/AffPapa/neclip/releases/download/v1.3.0/NeClip-1.3.0.dmg).
- SHA-256: `46660a1058332bc28b30e2f22cd656ccc8f3700a246cb43160b5d22d4d022a6e`.
