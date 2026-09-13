# NeClip 2.6.2 / build 40 — release evidence

## Scope and provenance

This release adds an explicit opt-in standalone Option (Alt) gesture for EN/RU
correction. On release, it corrects selected text, or the last entered word when
nothing is selected, using the existing manual correction path. The menu bar now
also exposes direct toggles for standalone Option correction and automatic layout
correction.

- Artifact source commit: `6414a364dc8f7dc3a0fc153b7365e2cdb45a2ddd`.
- GitHub Release: [v2.6.2](https://github.com/AffPapa/neclip/releases/tag/v2.6.2).
- DMG: `NeClip-2.6.2.dmg`, 2,093,507 bytes.
- SHA-256: `9dad1224530519df4bf0646e221db656fa828ffad7887a49635b9e9328e1dd48`.
- Distribution: Developer ID signed, Apple-notarized and stapled app and DMG,
  published only through GitHub Releases.

## Verification

- 291 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed. Coverage includes standalone Option release/cancellation policy,
  direct menu toggles and permission boundaries, alongside the existing clipboard,
  snippet, search, screenshot, history and recovery regressions.
- Strict Swift 6 production build passed with complete concurrency checking and
  warnings treated as errors.
- `scripts/secret-scan.sh` passed detector self-tests, publishable-tree scan,
  full `HEAD` history scan and side-ref scan with no leaks. `git diff --check`
  passed.
- `build-app.sh` completed Developer ID signing, Apple notarization, stapling,
  strict codesign, Gatekeeper assessment and mounted-DMG verification.
- The public DMG was independently downloaded and its size and SHA-256 matched
  the release manifest. GitHub API and GitHub Pages report the same artifact.
- The installed application was updated from the verified DMG to
  `/Applications/NeClip.app`; it launched successfully. The prior rollback copy
  remains available.

## Safety boundary

The standalone Option gesture is off by default and requires Accessibility and
Input Monitoring when enabled. It triggers only when Option is released without
typing, clicking or another modifier; Option plus a letter, click or other
modifier is cancelled. The monitor never suppresses or mutates input events.
Automatic correction remains independently controlled and conservative.

History, snippets and layout decisions remain local. No clipboard payloads were
printed or transferred during verification. No Telegram or external AI was used.
