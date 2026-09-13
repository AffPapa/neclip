# NeClip 2.7.0 / build 42 — release evidence

## Scope and provenance

This release hardens EN/RU layout correction after research into Punto Switcher,
Caramba Switcher, UASwitcher, Traple and MySwitcher. Standalone Option (Alt)
uses a passive Quartz event tap; manual correction prefers direct Accessibility
replacement and has a safe clipboard fallback; input-source changes are retried
and verified; automatic correction preserves safe word-ending punctuation.

- Artifact source commit: `4af09ed19633fd135b6b35da2b06598b46e8e6ee`.
- Pull request: [#48](https://github.com/AffPapa/neclip/pull/48), merged into
  `main` as `e6943eb79b72736188c338f9c63e71c6d33c9d10`.
- GitHub Release: [v2.7.0](https://github.com/AffPapa/neclip/releases/tag/v2.7.0).
- DMG: `NeClip-2.7.0.dmg`, 2,096,579 bytes.
- SHA-256: `4485ff2ee56f59f9665fdae81e8a1abff4cb29fcac12d706151260b6b77d23fa`.
- Distribution: arm64, Developer ID signed, Apple-notarized and stapled app and
  DMG, published only through GitHub Releases.

## Verification

- 292 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed. Coverage includes Option gesture cancellation/rearm, layout
  conversion, input-source policy, punctuation boundaries and existing history,
  snippets, search, screenshot, backup and update safety regressions.
- Strict Swift 6 production build passed with complete concurrency checking and
  warnings treated as errors; the binary contains arm64 only.
- PR checks passed: website coherence, strict Swift build/tests, release-size
  optimization, secret scan, full-history scan and CodeQL analysis for Actions,
  Ruby and Swift.
- `build-app.sh` completed Developer ID signing, Apple notarization, stapling,
  strict codesign, Gatekeeper assessment and mounted-DMG verification.
- Release assets were attached before publication; the public DMG and checksum
  were independently downloaded and matched the release manifest.

## Safety boundary

Standalone Option correction remains off by default and requires Accessibility
and Input Monitoring when enabled. The event tap is listen-only: it never
suppresses or mutates user input. Secure/protected contexts fail closed, no text
payloads are written to logs, and the user's clipboard is not exported during
verification. No Telegram or external AI was used.

The local installed application was replaced only after public-artifact identity,
checksum, signature, notarization and Gatekeeper checks. The previous installed
2.6.3 app is retained at `/Applications/NeClip.app.backup-2.6.3-41` for rollback.
