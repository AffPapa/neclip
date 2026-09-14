# NeClip 2.7.2 / build 44 — release evidence

## Scope and provenance

- Fix history search placement: it is available under «Ещё из истории», not at
  the top level of the menu.
- Fix selected-text layout correction by avoiding redundant AX reselection and
  accepting both exact selected-range and caret-after-replacement states.
- Source commit: `a36132ebb5cfc233885be3dece9be6e9f78f607f`.
- This patch follows merged PR #52 and is intended to supersede 2.7.1.

## Artifact

- GitHub Release: [v2.7.2](https://github.com/AffPapa/neclip/releases/tag/v2.7.2).
- DMG: `NeClip-2.7.2.dmg`, 2,104,770 bytes.
- SHA-256: `f83fe7e5d0782b4d1a797c6c8ff1c34333d915642e11093044435180a6ea4343`.
- Architecture: arm64; minimum macOS: 14.0.

## Verification

- 296 XCTest, 5 expected skips, 0 failures.
- Swift Testing suite passed; strict Swift 6 release build passed.
- History-search benchmark remained bounded at 100, 500 and 2,000 rows.
- Developer ID signing, Apple notarization, stapling, mounted-DMG validation
  and Gatekeeper assessment passed for the app and DMG.
- Secret scan and CodeQL passed for the public source and workflow.
- Public website/update metadata and local links passed coherence checks.
- The installed `/Applications/NeClip.app` is version 2.7.2 build 44 and the
  previous 2.7.0 build 42 remains available as a rollback copy.

Physical testing of every third-party editor, Accessibility configuration,
multiple-monitor layout, Spaces, fullscreen and Screen Recording prompts
remains environment-dependent; the code paths fail closed when those checks
cannot be verified.
