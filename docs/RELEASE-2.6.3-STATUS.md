# NeClip 2.6.3 / build 41 — release evidence

## Scope and provenance

This is the supported binary release of the Option-only layout correction and
direct menu-bar layout toggles. Standalone Option (Alt) release corrects selected
text, or the last entered word when nothing is selected, using the existing manual
correction path. Option plus typing, clicking or another modifier is untouched.

- Artifact source commit: `f14c900b8971956b8845e042d92ebb8c6512aba0`.
- GitHub Release: [v2.6.3](https://github.com/AffPapa/neclip/releases/tag/v2.6.3).
- DMG: `NeClip-2.6.3.dmg`, 2,093,507 bytes.
- SHA-256: `c74e620488e109d3679a536c66b830b70b115347b58d4c984116c15ad44e0525`.
- Distribution: Developer ID signed, Apple-notarized and stapled app and DMG,
  published only through GitHub Releases.

## Verification

- 291 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed. Coverage includes standalone Option release/cancellation policy,
  direct menu toggles and permission boundaries, alongside existing clipboard,
  snippet, search, screenshot, history and recovery regressions.
- Strict Swift 6 production build passed with complete concurrency checking and
  warnings treated as errors.
- `scripts/secret-scan.sh` passed detector self-tests, publishable-tree scan,
  full `HEAD` history scan and side-ref scan with no leaks. `git diff --check`
  passed.
- `build-app.sh` completed Developer ID signing, Apple notarization, stapling,
  strict codesign, Gatekeeper assessment and mounted-DMG verification.
- The release uses the draft-first immutable-release workflow: assets were
  attached before publication, then the public DMG and checksum were downloaded
  independently and matched the release manifest.
- The installed application was updated from the verified public DMG to
  `/Applications/NeClip.app`; the previous 2.6.1 app remains available for
  rollback.

## Safety boundary

Standalone Option correction is off by default and requires Accessibility and
Input Monitoring when enabled. It observes only Option flags and cancellation
input, never suppresses or mutates events, and invokes the existing conservative
Accessibility replacement path. Automatic correction remains independently
controlled.

History, snippets and layout decisions remain local. No clipboard payloads were
printed or transferred during verification. No Telegram or external AI was used.
