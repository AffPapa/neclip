# NeClip 2.8.8 release evidence

Published 2026-09-27T11:11:38Z. Immutable [v2.8.8](https://github.com/AffPapa/neclip/releases/tag/v2.8.8), build 54.

## Source and gates

- Exact source/tag and [PR #73](https://github.com/AffPapa/neclip/pull/73) merge: `76a3884810539a5e8bdb226624e5c46e05dcc376`.
- Required Swift CI, CodeQL Actions/Ruby/Swift and full-history Secret Scan passed before protected merge. No bypass. Previous immutable releases retained.
- Strict debug and optimized release, ASan and TSan each passed 380 XCTest (8 expected opt-in skips) plus 4 Swift Testing checks, no failures. Stable Xcode Swift 6.4.0.34.1, arm64, macOS 27.0 (26A5416b).
- Site 14 tests / 45 assertions; SEO 13 / 37. All eight canonical pages and project attribution verified locally. Source/history and release-artifact secret scans passed.

## Fixes and evidence

- Tokens previously appended irrespective of the caret. Native selection replacement now covers Unicode, insertion positions, autosave and document-scoped undo. Physical preview caught menu Undo and document-refresh issues; final code fixes both. Hosted SwiftUI/AppKit regression verifies observed document updates. Late native callbacks cannot overwrite another snippet.
- Original 400x300 capture exported with padding is 448x348; history now derives the latter from final bytes. Original/malformed input regressions pass.
- Failed screenshot-write injection preserves old representations; intervening external copy survives. Snapshot-limit regression preserves existing data without clearing. Native OS write failure was not observed; restoration is best-effort if the OS rejects the rollback too.
- Direct rendering clipboard reads: literal/date/escaped templates 1 on main -> 0; active token 1 on main -> 1 on data queue. Generation changes abort. The separate PasteService rollback snapshot remains on main. These are deterministic operation counts, not end-to-end latency measurements.
- [Reproducible narrow optimized benchmark](CLIPBOARD-BENCHMARK-2.8.8.md): private named pasteboard with 8 MiB synthetic ASCII, 5 warmups and 40 paired samples, same stable Swift compiler/machine. Eager preparatory read p50 0.352375 ms / p95 0.420542 ms; lazy literal-template preparation p50 0.000125 ms / p95 0.000375 ms. Excludes final copy and rollback snapshot; no general UI speedup claim.
- Physical isolated preview: token selection including emoji, multiline paste, title-focus-to-content insertion, Cmd+Z/Shift+Cmd+Z, autosave/relaunch, document switching and undo isolation passed. Explicit preview and all three history-filter AX labels observed; filtered search returned the single fixture B row, and Return on a filter did not paste/close. No claim of VoiceOver speech verification.

## Public artifacts

Developer ID, app/DMG notarization and stapling passed. Public ZIP app and mounted public DMG app pass signature, stapler and Gatekeeper. Both archives and their sidecars were uploaded before immutable publication; fresh downloads match local bytes, sizes and SHA-256.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [DMG](https://github.com/AffPapa/neclip/releases/download/v2.8.8/NeClip-2.8.8.dmg) | 2,146,754 bytes | `6bf16a132261d66926e7b327e835dd0ee526e477d19d8907b207a7f2ea164d74` |
| [ZIP](https://github.com/AffPapa/neclip/releases/download/v2.8.8/NeClip-2.8.8.zip) | 2,111,918 bytes | `e33fe900103f5999928054f4de8535ab74d8f1ceab53df6fbaf130327c12ae38` |

## Limits

Snapshot bounds are 16 MiB, 32 items and 32 representations per item; screenshot copy refuses before clearing if preservation is impossible and offers file export. VoiceOver audio, live IME composition, real cross-app auto-paste, ScreenCaptureKit permissions, multiple monitors/Spaces and every supported macOS are not certified. User history and installed app were untouched. Pages/README are verified separately after metadata deploy. [Проект Иванова](https://affpapa.org/).
