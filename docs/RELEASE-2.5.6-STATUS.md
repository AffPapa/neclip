# NeClip 2.5.6 / build 35 — release evidence

The final release fixes selected-area capture on Retina, scaled and mixed
displays. ScreenCaptureKit receives an explicit `sourceRect`, and capture plus
post-capture validation use one resolved display ID. The selected annotation
colour is retained by every new shape and text entry.

## Exact artifact

- Source commit: `61618d03ed266cc764c08fb23bc00de25c3003fb`.
- GitHub Release: `v2.5.6`, published 11 September 2026.
- DMG: `NeClip-2.5.6.dmg`, 2,048,962 bytes.
- SHA-256: `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.

## Verification

- 276 XCTest with four expected opt-in skips, plus three Swift Testing checks.
- Strict Swift 6, AddressSanitizer and ThreadSanitizer runs passed.
- Developer ID signing, notarization, stapling, Gatekeeper and mounted-DMG
  validation passed.
- Required GitHub Actions checks and a separate anonymous public download passed;
  the downloaded asset matched the published size and SHA-256.

Only this release is published and supported.
