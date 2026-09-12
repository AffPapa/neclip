# NeClip 2.6.0 / build 38 — release evidence

## Scope and provenance

This release makes the existing local clipboard workflow explicit and reversible:
history items can be saved as raw-text snippets with a first-line title, folder
choice and duplicate detection; history has bounded local search; paste actions
distinguish original format, plain text and copy-only; and the menu exposes capture
and permission state. Snippet token preview, removable bilingual starter snippets,
screenshot-format persistence and isolated SQLite backup/restore complete the 2.6
scope. Search does not persist an index, inspect images with OCR or use the network.

- Artifact source commit: `1c79c28da68456c69b658ea523027ef33e298c2b`.
- GitHub Release target: [v2.6.0](https://github.com/AffPapa/neclip/releases/tag/v2.6.0).
- DMG: `NeClip-2.6.0.dmg`, 2,087,874 bytes.
- SHA-256: `8329ff378f6c9a4d5bc5da0efbceebc6ecf48e9f0bac5790439e6d0d77ca0636`.
- Distribution: Developer ID signed, Apple-notarized and stapled app and DMG,
  published only through GitHub Releases.

## Verification

- 285 XCTest passed with 5 expected skips and 0 failures; three Swift Testing
  tests passed. Coverage includes history-to-snippet conversion, raw-text and
  sensitive-draft handling, duplicate/folder behavior, search filters, explicit
  paste actions, status/pause state, token preview, starter snippets, screenshot
  export safety and online-backup restore validation.
- Strict Swift 6 release build passed with complete concurrency checking and
  warnings treated as errors.
- Search benchmark passed at 100, 500 and 2,000 synthetic rows. Median latency
  was 1.48 ms, 7.27 ms and 27.85 ms respectively; the implementation remains a
  bounded read-time query and does not pre-index on launch.
- `scripts/verify-site.rb`, `scripts/test-site.rb` and `git diff --check` passed
  for the release metadata and static site.
- The exact artifact passed Developer ID signing, Apple notarization, stapling,
  strict codesign, Gatekeeper assessment and validation after mounting the DMG.
- The screenshot release gate was physically exercised in an isolated NeClip
  instance: Data preferences opened, the backup Save panel showed the expected
  filename, the screenshot editor opened a synthetic image, PNG/JPEG save controls
  appeared, and cancellation produced no user-file write. The isolated instance
  used temporary data and was terminated after the check; the installed user's
  data and clipboard were not modified.
- The public artifact, checksum, version manifest and Pages copy must be checked
  independently after GitHub publication.

## Verification boundary

The host exposed one physical display. This evidence therefore does not claim the
full multi-monitor, mixed-scale, Spaces, fullscreen or denied Screen Recording
matrix across every supported macOS version. ASan and TSan could not start under
the installed Xcode-beta runtime because its sanitizer interceptors failed to load;
this is an environment gate, not a claim that those runs passed. No Telegram or
other external application was used for this release work.

NeClip remains local-only: no account, cloud synchronization, telemetry, advertising
or AI processing of clipboard content is introduced by 2.6.0.
