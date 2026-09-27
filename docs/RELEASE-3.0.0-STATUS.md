# NeClip 3.0.0 release evidence

Published 2026-09-27T13:45:20Z. Immutable [v3.0.0](https://github.com/AffPapa/neclip/releases/tag/v3.0.0), build 55.

## Source and verification

- Exact source/tag: `c539ae0ad6aad80b84aa89d6a1d6ca7ce0d0173f`, merged through [PR #76](https://github.com/AffPapa/neclip/pull/76) after required Swift CI, CodeQL Actions/Ruby/Swift and full-history Secret Scan. No bypass.
- Strict debug and optimized release, ASan and TSan each passed 283 XCTest (8 expected opt-in skips) plus 4 Swift Testing checks. No failures. Stable Xcode Swift 6.4.0.34.1, arm64 macOS 27.
- Additional opt-in test opens a disposable synthetic 2.8.8 database without history/snippet count loss. User database schema and storage code are unchanged.
- Removed 15 production files for screenshot capture/editing and keyboard-layout correction/switching/memory. Startup deletes only 14 named obsolete preferences; retained preferences and idempotence are tested.
- Native isolated preview: five settings sections, three shortcuts, clipboard/accessibility permission copy, retained two synthetic history entries and ten snippets, menus without removed commands. After an initial focus-protected menu transition, a direct isolated editor launch passed token replacement at selection, Cmd-Z/Shift-Cmd-Z, document switching, undo isolation and persistence after relaunch.
- Source/history and final archive/binary secret scans passed. Developer ID signatures, app/DMG notarization and stapling, ZIP app and mounted-DMG app Gatekeeper checks passed. Public downloads and sidecars match local bytes.

## Artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [DMG](https://github.com/AffPapa/neclip/releases/download/v3.0.0/NeClip-3.0.0.dmg) | 1,960,899 bytes | `297539ca29c759868fb33906af9537f5598fd4bb96a306c0fe6ac18ac6c11027` |
| [ZIP](https://github.com/AffPapa/neclip/releases/download/v3.0.0/NeClip-3.0.0.zip) | 1,929,891 bytes | `4977dca0b7b025352b3e447a3b9f45ccaf2aee890417c4ad6d8de7ba48cc6b70` |

## Scope and limits

Clipboard images/files, search, snippet templates, native undo, backups and privacy controls remain. No screenshot capture/editor, input monitoring, keyboard-layout switching or Screen Recording request paths remain. Previously captured images remain ordinary history items.

The existing overlapping sequential-paste edge case remains in [BACKLOG](../BACKLOG.md): repeated operations can repeat an item after an earlier failure. No claim of a general UI speedup, universal cross-app paste, VoiceOver speech or every supported macOS. Old immutable releases remain available for rollback. Website/Pages and installed-app checks are recorded separately after publication.

[Проект Иванова](https://affpapa.org/).
