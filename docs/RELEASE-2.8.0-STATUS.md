# NeClip 2.8.0 / build 46 — release evidence

## Scope

- Automatic EN/RU layout correction now analyzes the live token after each
  eligible key and may correct a high-confidence token before a space.
- Standalone Option correction keeps selected-text and last-word correction,
  including active-layout handling for mixed text and layout-specific symbols.
- Settings now expose separate `Раскладка`, `Приватность`, `Данные` and `Доступы`
  sections; layout behavior is no longer mixed into a security surface.

## Exact artifact

- Source implementation commit: `0f288c7c9c4fcc96decd36886e25f13113c81e6d`.
- GitHub Release: [v2.8.0](https://github.com/AffPapa/neclip/releases/tag/v2.8.0).
- DMG: `NeClip-2.8.0.dmg`, 2,096,066 bytes.
- SHA-256: `d7f869cb90a49d175f681c5d037d2f69ab499a0d44793ee11e54b1060a1d2e51`.

## Verification

- Full Swift/XCTest suite: 299 executed, 5 expected skips, 0 failures.
- Swift Testing suite: passed.
- Strict production build: passed.
- App and DMG: Developer ID signed, Apple notarized, stapled and Gatekeeper
  accepted.
- GitHub Actions: Secret Scan, Swift 6 CI and CodeQL passed before merge.
- `git diff --check`, public JSON/site contract and site tests passed.
- Installed `/Applications/NeClip.app`: version 2.8.0 build 46, running and
  accepted by Gatekeeper.
- Previous 2.7.2 build 44 remains at
  `/Applications/NeClip.app.backup-2.7.2-44-20260914` for rollback.

## Safety boundary

Automatic correction remains opt-in, dictionary-gated and fail-closed for
secure fields, protected applications, stale Accessibility state, unavailable
input sources and concurrent edits. No clipboard contents were exported for
testing. A real third-party editor smoke test remains dependent on the local
Accessibility/UI harness; deterministic AX replacement and race contracts are
covered by the test suite.
