# NeClip 2.7.3 / build 45 — release evidence

## Scope and provenance

- Manual EN/RU correction now falls back to the active keyboard layout when
  script inference cannot classify the selection.
- The fallback translates mapped punctuation and symbols, including selections
  containing digits or no letters.
- Source commit: `65c9779c7034e7357e31819673c64a38c7526e95`.
- This patch supersedes 2.7.2.

## Artifact

- GitHub Release: [v2.7.3](https://github.com/AffPapa/neclip/releases/tag/v2.7.3).
- DMG: `NeClip-2.7.3.dmg`, 2,104,771 bytes.
- SHA-256: `cf77a7ea28b237d7307b05488ff41ad1c533a74cbd8db7dab99a54c31968a54e`.
- Architecture: arm64; minimum macOS: 14.0.

## Verification

- 297 XCTest, 5 expected skips, 0 failures.
- Swift Testing suite passed; strict Swift 6 release build passed.
- Developer ID signing, Apple notarization, stapling, mounted-DMG validation
  and Gatekeeper assessment passed for the app and DMG.
- Secret scan and CodeQL passed for the public source and workflow.
- Public website/update metadata and local links passed coherence checks.
- The installed `/Applications/NeClip.app` is version 2.7.3 build 45 and the
  previous 2.7.2 build 44 remains available as a rollback copy.

Physical behavior still depends on the target editor exposing a writable
Accessibility text element and on the active source being an enabled EN/RU
keyboard layout. When those preconditions are absent, NeClip fails closed.
