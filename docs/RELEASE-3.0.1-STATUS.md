# NeClip 3.0.1 release evidence

Published 2026-09-27T15:07:26Z. Immutable [v3.0.1](https://github.com/AffPapa/neclip/releases/tag/v3.0.1), build 56.

## Source and verification

- Exact source/tag: `8a76c079d53ead5876f7efff4288ffdf621367e5`, merged through [PR #78](https://github.com/AffPapa/neclip/pull/78) after required Swift CI, CodeQL Actions/Ruby/Swift and full-history Secret Scan. No bypass.
- Strict debug and optimized release, ASan and TSan each passed 286 XCTest (9 expected opt-in skips) plus 4 Swift Testing checks. No failures. Xcode Swift 6.4, arm64 macOS 27.
- Per-attempt sequential ownership fixes overlapping writes, failure retry, duplicate completion and reset/expiry ABA. Regression tests exercise these interleavings.
- Settings show exact history limits, truthful permission/update status and clearer backup labels. Data counts use a consistent off-main SQL read. Unused menu helpers, impossible state and duplicate actions removed. No schema changes or broad preference reset.
- Native isolated preview verified five settings sections, three shortcuts, exact 350-item limit, count display, access/backup copy and history menu without duplicate controls. Synthetic data only; capture stayed paused. No user history was used for UI testing.
- [Architecture/privacy audit and bounded performance measurement](MINIMAL-PRODUCT-AUDIT-3.0.1.md). Retired screenshot/layout APIs, permissions, handlers, dependencies and resources remain absent; fourteen legacy keys are removed selectively on startup.
- Source/history and final archive/binary secret scans passed. Developer ID signatures, app/DMG notarization and stapling, ZIP app and mounted-DMG app Gatekeeper checks passed. Public downloads and sidecars match local bytes.

## Artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [DMG](https://github.com/AffPapa/neclip/releases/download/v3.0.1/NeClip-3.0.1.dmg) | 1,970,627 bytes | `b36326a73ccc82e7b7ed112d2d51d6e7032b6d02940360e4cbef2cc4fcbba3e5` |
| [ZIP](https://github.com/AffPapa/neclip/releases/download/v3.0.1/NeClip-3.0.1.zip) | 1,939,207 bytes | `2847185a4b5c66f5bc83a5e093b69ab44101b6aee35e36730ebc6dec95cd7b7a` |

## Scope and limits

Clipboard images/files, search, snippet templates, native undo, backups and privacy controls remain. No screenshot capture/editor, input monitoring, keyboard-layout switching or Screen Recording requests. Previous immutable releases remain for rollback.

The count-query benchmark measures a synthetic warmed in-memory workload, not total UI latency. Sequential overlap/reset/expiry is verified through deterministic state regressions, not a claim about every cross-app keyboard interaction. Additional macOS versions and VoiceOver audio are not certified. Website/Pages and installed-app checks occur separately after publication.

[Проект Иванова](https://affpapa.org/).
