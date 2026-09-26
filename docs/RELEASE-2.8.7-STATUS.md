# NeClip 2.8.7 release evidence

Published 2026-09-26T15:55:01Z. Immutable release: [v2.8.7](https://github.com/AffPapa/neclip/releases/tag/v2.8.7).

## Source and review

- Exact release source, tag and PR #71 merge commit: `2cad4383bcc6d1a7c8c28c6e60bbfe67a3b11be6`.
- [PR #71](https://github.com/AffPapa/neclip/pull/71): three focused runtime fixes; no unrelated changes.
- Required Swift CI, CodeQL Actions/Ruby/Swift and full-history Secret Scan passed before merge. No branch protection bypass.
- Previous immutable v2.8.6 and its files remain unchanged.

## Reproductions and validation

- Before: keyboard regression failed 18 modifier assertions; queued image test stored one screenshot after opt-out. After: focus-aware search shortcuts, marked-text pass-through and insertion-time image opt-out pass.
- Debug, strict release, ASan and TSan: 371 XCTest, 8 expected opt-in skips, 0 failures; 4 Swift Testing checks. Release-toolchain strict tests also passed.
- Site: 14 tests / 45 assertions; SEO: 13 tests / 37 assertions; all eight canonical pages and project attribution verified locally.
- Secret scans: detector self-tests, publishable tree and fetched Git history passed; ignored third-party build fixtures are excluded from the publishable tree scan.
- Synthetic in-memory SQLite, 64 text rows × 512 KiB ASCII bodies, matching titles, 30 warmed release iterations on macOS 27.0 (26A5416b), arm64, Swift 6.4.0.27.1: p50 164.964791 → 3.7405 ms; p95 229.571209 → 4.187333 ms. Same fixture/configuration before and after. No end-to-end UI speed claim.
- Signed release compiler: stable Xcode, Swift 6.4.0.34.1; separately passed strict release tests.
- Physical isolated debug UI: synthetic screenshot editor tools exposed by AX; menu shows paused capture and two fixture rows; search fixture B returns only B; Down selects next result; Ctrl+Option+Up does not change selection; Return with filter focus does not paste/close. Default-size search screenshot inspected. Synthetic screenshot keyboard region, Undo/Redo and native Save exported a visually checked 720×420 PNG with opaque markup. Initial automation timeouts recovered by relaunch.

## Signed public artifacts

Developer ID signing, app/DMG notarization and stapling passed. App extracted from ZIP and mounted DMG pass signature, stapler and Gatekeeper checks. Both artifacts and SHA-256 sidecars were attached before immutable publication. Fresh independent public downloads match local files and sidecars.

| Artifact | Size | SHA-256 | Download |
| --- | ---: | --- | --- |
| DMG | 2,142,658 bytes | `3111009d22c8ad9e56a3951f215c63cfe669786ff0f8596ca8d80ed007e8984a` | [NeClip-2.8.7.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.7/NeClip-2.8.7.dmg) |
| ZIP | 2,109,242 bytes | `a7ff40101da09d16c69ac2c5f8535bd1b547a3af84308b823012c3bd8e8f169d` | [NeClip-2.8.7.zip](https://github.com/AffPapa/neclip/releases/download/v2.8.7/NeClip-2.8.7.zip) |

## Limits and deferred P2

VoiceOver audio, multiple monitors/Spaces, real ScreenCaptureKit permission flows and all supported macOS versions were not certified. No user history or installed app was modified. Deferred: token insertion caret behavior, screenshot-title dimensions after padded export, unnecessary clipboard read for literal snippets. Screenshot clipboard failure rollback remains an unconfirmed concern.

Pages/README publication is verified separately after the metadata PR deploy. [Проект Иванова](https://affpapa.org/).
