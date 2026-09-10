# NeClip 2.5.0 / build 29 — release evidence

Status: released 10 September 2026.

- Source commit: `96800f17f4394218afa51680b2a38f4adcb61874`
- Architecture: arm64, macOS 14+
- DMG size: 2,042,306 bytes
- DMG SHA-256: `7cd94b6d29a892c07e51fe743e463a434d41d4dbb38142d8e276fe586e4de96f`
- App notarization: `17e34bc5-f480-43f2-b0cb-4254198a3d48` (Accepted)
- DMG notarization: `3032024e-979c-4e23-a330-085b47c93a4a` (Accepted)

## Changes

- Area capture no longer rejects an oversized Retina display before selection;
  the source frame is proportionally reduced to the 32 MP working-image budget.
- Full-screen capture is a separate command without a selection overlay.
- Default shortcuts: area `⌘⇧2`, full screen `⌘⌥3`; both are configurable.
- ScreenCaptureKit failures are separated into actionable states; overlay
  exclusion has an application-level safe fallback and never captures the
  pending NeClip shell unfiltered.
- Menu/settings copy now uses one short name for each action.

## Verification

- 264 XCTest, 4 expected skips, 3 Swift Testing; all pass.
- Strict Swift 6 release build with warnings-as-errors passes.
- Developer ID signing, stapling, Gatekeeper and mounted-DMG verification pass.
- gitleaks current tree and full history: no leaks.
- Public DMG checksum matches this evidence and the release JSON exactly.
