# NeClip 2.7.1 / build 43 — release evidence

## Scope and provenance

This patch release hardens the highest-risk runtime paths found in the maximum
regression audit: clipboard materialization and rollback, local search races
and limits, file-path serialization, input-source cache invalidation, Option
event-tap lifecycle, screenshot display placement and explicit UI error states.

- Artifact source commit: `21c4a2812a6bd6eb72c5c3f87f4e7f69807ba44f`.
- Pull request: [#50](https://github.com/AffPapa/neclip/pull/50), merged into
  `main` as `21c4a2812a6bd6eb72c5c3f87f4e7f69807ba44f`.
- GitHub Release: [v2.7.1](https://github.com/AffPapa/neclip/releases/tag/v2.7.1).
- DMG: `NeClip-2.7.1.dmg`, 2,104,771 bytes.
- SHA-256: `655445405a9ee970b557cc71f9ebde01cd0b881335c1131cf3f92e19646ee23d`.
- Distribution: arm64, Developer ID signed, Apple-notarized and stapled app and
  DMG, published only through GitHub Releases.

## Verification

- 295 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed.
- Strict Swift 6 release build passed with warnings treated as errors; the
  binary contains arm64 only.
- Search benchmark passed at all requested sizes: median 0.61 ms / 100 rows,
  2.94 ms / 500 rows and 11.86 ms / 2,000 rows.
- PR #50 checks passed: Swift 6 CI including strict release tests, both
  full-history secret scans, CodeQL Swift/Actions/Ruby analysis.
- Gitleaks detector self-tests, publishable tree and fetched Git history passed
  locally with no leaks.
- `build-app.sh` completed Developer ID signing, Apple notarization, stapling,
  Gatekeeper assessment and mounted-DMG verification for this exact SHA.
- The public DMG checksum and release manifest were generated from this exact
  artifact before publication.

## Safety boundary

No Telegram, external AI, OCR, cloud sync or telemetry was used or added.
Verification did not export or print private clipboard contents. Existing
2.7.0 artifacts were not overwritten. The local installed app is replaced only
  after public-artifact identity and signature checks, with the previous app
  retained as a rollback copy.
