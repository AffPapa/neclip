# NeClip 2.8.2 / build 48

## Supported artifact

- Source commit: `1524627efb4de62274d433915651945a1c8e2b3e` on `main`.
- GitHub Release: [v2.8.2](https://github.com/AffPapa/neclip/releases/tag/v2.8.2), published 2026-09-19T16:32:09Z.
- DMG: `NeClip-2.8.2.dmg`, 2,124,738 bytes.
- SHA-256: `84b16e5396ca5dbc3093fe1dbdd2b3e9173e9f77e2600e7e23f63dfd694e916a`.

## Release gates

- The protected PR was merged only after required `test`, `full-history` and advanced CodeQL Actions, Swift and Ruby checks passed; no open CodeQL alerts were reported.
- Local strict Swift 6 testing passed: 333 XCTest with five explicit environment skips and zero failures, plus three Swift Testing checks.
- The release app and DMG were Developer ID signed, notarized, stapled and accepted by Gatekeeper. The DMG was mounted and its enclosed app was checked before publication.
- The repository tree, reachable history and side refs passed the release secret scan.

## Scope and boundaries

- Search cancellation prevents stale rows or delayed actions from being used after a changed query, close or full history erase.
- Manual Option correction accepts the preceding text token after whitespace and preserves surrounding whitespace and punctuation.
- Restore cleanup accepts only app-managed snapshot names and serializes restore with full data erasure.
- Screenshot selection and annotation paths provide arrow, Shift, Option, Return, Escape and VoiceOver controls.
- Clipboard data, search and language processing remain local. Secure Input, protected or excluded apps, and unsupported Accessibility fields fail closed; universal compatibility with every third-party editor is not claimed.
