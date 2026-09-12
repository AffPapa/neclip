# NeClip 2.5.6 / build 35 — release evidence

The final release fixes selected-area capture on Retina, scaled and mixed
displays. ScreenCaptureKit uses the complete display without overriding
`sourceRect`; capture and post-capture validation use one resolved display ID.
The selected annotation colour is retained by every new shape and text entry.

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

## Repeat verification — 12 September 2026

The runtime, resources and dependency lockfile still match the artifact source
commit above. No new application version was produced for documentation changes.

- Fresh debug, strict release, ASan and TSan runs each passed 276 XCTest
  (four expected opt-in skips) and three Swift Testing checks.
- All three opt-in synthetic hot-path benchmarks passed separately. Menu data
  reads measured 0.53 ms median and 0.60 ms p95; native rendering is not included.
- A new anonymous DMG download matched the size and checksum above. Signature,
  stapling and Gatekeeper passed for the DMG and its mounted application.
  The mounted application matched the installed application byte for byte.
- Full-history and side-ref secret scanning passed. Old GitHub releases and tags
  were removed together; only the supported release remains.
- The public metadata gate now checks build, source commit, checksum URL,
  artifact size, evidence and local documentation links, with seven regression
  tests including an unreleased-candidate transition.

Native UI automation was unavailable during this repeat audit (the macOS control
service timed out). Screenshot editing, cancellation, privacy, storage and layout
policies passed automated regression tests; a new interactive end-to-end check
and physical multi-display/Space switching are not claimed by this audit.
