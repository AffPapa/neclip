# Changelog

## 2.5.6 / build 35 — released 2026-09-11

- ScreenCaptureKit receives an explicit `sourceRect` and fits the complete
  source into the output canvas, preventing blank margins and offset crops on
  Retina and mixed-resolution displays.
- Capture and post-capture display validation use the same resolved display ID.
- The selected annotation colour is applied to new shapes and text; text commit
  is idempotent on Enter or focus loss.
- The signed Apple Silicon DMG passed Developer ID signing, notarization,
  stapling, Gatekeeper and mounted-DMG validation.

Exact public artifact: [NeClip-2.5.6.dmg](https://github.com/AffPapa/neclip/releases/download/v2.5.6/NeClip-2.5.6.dmg)
(2,048,962 bytes), SHA-256
`340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.
See [release evidence](docs/RELEASE-2.5.6-STATUS.md).
