# NeClip 2.5.1 / build 30

## Scope

Patch release for a real capture bug on large Retina displays. The screenshot
pipeline already bounded native pixel dimensions to 32 MP, but it did not tell
ScreenCaptureKit to fit the complete source into that bounded target. On an
oversized display this could produce a frame cropped from the top-left, which
looked like the screenshot only captured the upper part of the screen.

## Change

`ScreenshotCoordinator` now enables `SCStreamConfiguration.scalesToFit` and
`preservesAspectRatio` after calculating the bounded pixel size. The source
display is therefore scaled proportionally into the safe target instead of
being cropped. No new permission, dependency, storage format or user setting
was added. Area (`⌘⇧2`) and full-screen (`⌘⌥3`) capture remain separate and
continue through the same privacy-safe renderer.

## Verification

- Targeted screenshot and menu contract tests: 20 passed.
- Full XCTest suite: 264 passed, 4 expected skips; Swift Testing: 3 passed.
- Strict Swift 6 release build with complete concurrency and warnings as
  errors: passed.
- `git diff --check`, JSON validation and public-site coherence checks: run
  before publication.
- Release publication additionally requires Developer ID signing, Apple
  notarization, stapling, Gatekeeper and mounted-DMG verification.

The exact notarized artifact, SHA-256 and source commit are recorded in
`docs/version.json` after the release gate.
