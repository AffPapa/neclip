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

The notarized artifact is `NeClip-2.5.1.dmg` (2,042,306 bytes), SHA-256
`fff531d1f1055f61da2b5b5fcc945f556fce516b3d6c51ecb45ad4acfdbec2b1`, built
from source commit `20ba44d347dac993e7c192d2782ac8b3ac9f13fd`. The matching
GitHub Release and `docs/version.json` are the public source of truth.
