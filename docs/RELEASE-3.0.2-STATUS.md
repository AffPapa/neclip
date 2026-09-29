# NeClip 3.0.2 release evidence

Published 2026-09-29T14:21:04Z. Immutable [v3.0.2](https://github.com/AffPapa/neclip/releases/tag/v3.0.2), build 57.

- Exact source/tag: `5d0e482f2159fab9cd165aef9f6ec3d7bd51361a`, merged through [PR #81](https://github.com/AffPapa/neclip/pull/81) after required Swift CI, Actions/Ruby/Swift CodeQL and full-history Secret Scan. No bypass.
- Strict debug/release, ASan and TSan each passed 291 XCTest, 10 expected opt-in skips, 0 failures, plus 4 Swift Testing. The release toolchain is Apple Swift 6.4.0.34.1 / Xcode 27.0 (27A266a), arm64 macOS 27. The earlier benchmark-enabled release run used Swift 6.4.0.27.1 and passed 291 XCTest with 1 unrelated opt-in skip; isolated trim measurements use that same earlier toolchain as documented.
- [Audit, before/after measurements and native UI coverage](MINIMAL-PRODUCT-AUDIT-3.0.2.md). Three settings destinations; custom values preserved; clear backup cancellation; readable file paths in plain-text paste; redundant trim aggregation and menu rebuilding removed. No schema or dependency changes.
- Source/history and final artifact secret scans passed. Developer ID, app/DMG notarization, stapling and Gatekeeper passed. Public archives and sidecars were downloaded independently and match the local bytes; ZIP and mounted-DMG applications match.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [DMG](https://github.com/AffPapa/neclip/releases/download/v3.0.2/NeClip-3.0.2.dmg) | 1,968,067 bytes | `9449b1815c2fa4436f312c8520dbd4fe4692431c54ca1ac5e20dcba261c83963` |
| [ZIP](https://github.com/AffPapa/neclip/releases/download/v3.0.2/NeClip-3.0.2.zip) | 1,937,695 bytes | `d9e4f6e90bd8fbce1614e26e80fe8aeacb496eb6efcb015011d22e0c244d4e50` |

Compared with signed 3.0.1 archives, DMG is 2,560 bytes smaller and ZIP is 1,512 bytes smaller. This is a small packaging reduction, not a claim of a large download or runtime improvement.

## Boundaries

Clipboard history, images/files, search, snippets, templates, undo and local backups remain. No screenshot capture/editor, input monitoring or layout-switching requests. Selective retirement migration is unchanged. Previous immutable releases remain for rollback.

The trim benchmark is a synthetic storage-operation measurement, not whole-app latency. Physical automatic paste across every application, additional macOS versions and VoiceOver speech remain uncertified. Website/Pages and installed-app checks are performed separately after publication.

[Проект Иванова](https://affpapa.org/).
