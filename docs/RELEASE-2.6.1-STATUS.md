# NeClip 2.6.1 / build 39 — release evidence

## Scope and provenance

This release separates the amount of history retained from the amount shown
directly in the first menu list. The first-list count is configurable from 10
to 1,000 and accepts custom values such as 20 or 37. Every remaining stored
buffer appears under one flat «Ещё из истории» submenu, without folders or
hidden page groups.

- Artifact source commit: `4ff57a1ddac0d526009f8c3e5b6b061f47c9ceeb`.
- GitHub Release: [v2.6.1](https://github.com/AffPapa/neclip/releases/tag/v2.6.1).
- DMG: `NeClip-2.6.1.dmg`, 2,088,898 bytes.
- SHA-256: `f7dabbc368306ddebe14776866915b69e3931f7208f2fbfbee59db03d29267a3`.
- Distribution: Developer ID signed, Apple-notarized and stapled app and DMG,
  published only through GitHub Releases.

## Verification

- 287 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed. Coverage includes the separate menu-limit setting, custom-value
  clamping, complete history-summary loading and flat older-history behavior,
  alongside the existing clipboard, snippet, search, screenshot and recovery
  regressions.
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
  `/Applications/NeClip.app`; it launched successfully. The prior
  `/Applications/NeClip.app.backup-2.5.8-37` remains available for rollback.

## Safety boundary

The setting changes menu presentation only; it never changes retention or
deletes history. History remains local, and no clipboard payloads were printed
or transferred during verification. No Telegram or external AI was used.
