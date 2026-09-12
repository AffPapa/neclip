# NeClip 2.5.8 / build 37 — release evidence

## Fixes and provenance

Copied images previously started Apple Vision OCR automatically. This did not
use a cloud service, but still violated the boundary against automatic processing
of clipboard contents. Capture now uses the common image insert path without
recognition. The queue and unused OCR-only APIs were removed. Existing image bytes,
legacy metadata and retention accounting remain compatible; no destructive
database migration was added.

The screenshot field-editor fixes from [PR #38](https://github.com/AffPapa/neclip/pull/38)
remain included: native focus no longer removes the input, Enter/focus loss commit
once, Escape discards the draft and export includes active text.

- Recognition-removal PR: [#40](https://github.com/AffPapa/neclip/pull/40).
- Source and runtime merge commit: `b66c7e55d267e7a159bb951798ddc34ead97abed`.
- GitHub Release: [v2.5.8](https://github.com/AffPapa/neclip/releases/tag/v2.5.8), published 12 September 2026.
- DMG: `NeClip-2.5.8.dmg`, 2,044,866 bytes.
- SHA-256: `05aec85af50286de2b4051041775e48b14d8d33b74a484cb7706531b6ebaec21`.

## Verification

- Recognition and screenshot regressions failed before their corresponding fixes.
- Debug, strict Swift 6 release, ASan and TSan each passed 276 XCTest and three
  Swift Testing tests. Four expected skips cover three opt-in benchmarks and an
  optional external-database fixture; no user database was opened for testing.
- All three opt-in synthetic benchmarks passed separately; menu reads use the
  current snapshot query. Obsolete tests for removed OCR APIs were retired; legacy-image preservation and byte accounting
  are still covered. All 26 screenshot tests remain.
- The release executable does not link Vision, CoreML or NaturalLanguage.
- Required Swift CI, Secret Scan and CodeQL checks passed before normal merge.
- The exact merged commit passed Developer ID signing, notarization, app/DMG
  stapling, strict codesign, Gatekeeper and mounted-DMG validation. Independent
  anonymous asset downloads matched their published sizes and SHA-256 digests.
- The installed app matched the mounted public app byte for byte. User data was
  preserved and the temporary bundle backup was removed after verification.
- Native synthetic-image QA verified text entry, Enter, focus loss, Escape,
  redaction and undo/redo. Isolated product QA verified snippet folders, editing,
  deletion/restore, settings draft cancellation/application, hotkey conflicts and
  the copy-only explanation without Accessibility.
- Full-history/side-ref secret scanning and the public JSON/metadata/link gate
  passed. Seven site regression tests include a future candidate retaining the
  verified public download.

## Verification boundary

The macOS control service timed out on the screenshot Save dialog; completing
that system dialog interactively is not claimed. Flattened PNG/JPEG output,
write failure handling and clipboard generation protection passed automated tests.
This audit does not claim a complete hardware matrix of supported macOS versions,
physical mixed-scale displays, Space switching, permission prompts or live
cross-application paste scenarios.

Only the current release is supported. Replaced release evidence and download
links are retired; Git history retains the development record.
