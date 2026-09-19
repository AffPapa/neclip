# NeClip 2.8.3 / build 49

## Supported artifact

- Source commit: `d210af5f6624a274909eb00de25f28ce1f9ca7b6` on `main`.
- GitHub Release: [v2.8.3](https://github.com/AffPapa/neclip/releases/tag/v2.8.3), published 2026-09-19T18:53:56Z. Release and tag are immutable.
- DMG: `NeClip-2.8.3.dmg`, 2,134,466 bytes.
- SHA-256: `89fd4661aebe93f75a3ed353a371192a53462633abaf98dbc289b94af7b9a523`.
- Enclosed executable SHA-256: `4d34e5571c6e0e93af839942f1694022886d817f74bdbff4e5f063ed43290dd8`.

## Release gates

- Protected [PR #59](https://github.com/AffPapa/neclip/pull/59) merged only after required Swift CI, full-history secret scanning and CodeQL Actions/Swift/Ruby succeeded. The reviewed and merged source trees were identical.
- Strict Swift 6 debug and optimized release: 347 XCTest, five explicit opt-in/environment skips, zero failures; three Swift Testing checks passed. A separate benchmark-enabled release run left only the external-database fixture skipped.
- Address Sanitizer: 54 changed-path tests passed. Thread Sanitizer: 60 changed-path/undo tests passed.
- Independent review found two backup regressions before release: temporary-file permissions and aggregate import accounting. Both were fixed, regression-tested and re-reviewed.
- App and DMG were Developer ID signed, Apple-notarized, stapled and accepted by Gatekeeper. The app inside the mounted DMG was verified separately.
- A fresh anonymous public download matched the pinned SHA-256. Its DMG and enclosed app passed signing, stapling and Gatekeeper checks; the enclosed executable matched the local exact-commit release binary byte-for-byte.

## Security audit coverage

- Publishable tree, reachable Git history and fetched side refs passed redacted Gitleaks scanning with detector self-tests. Final pre-publication scan covered 226 HEAD commits and 25 side-ref-only commits.
- Public issue/PR text and associated comments/reviews, 887 available Actions log archives, 23 prior release assets and five available CI artifacts had no detector findings.
- Eleven prior release DMGs were mounted read-only and detached; their hashes matched published sidecars. Forty-four text/plist resources and eleven executable-string extracts had no findings. Twenty-two other binary resources were outside that text scan.
- New release resources and executable-string extraction also passed the redacted scanner.
- No open GitHub secret-scanning, CodeQL or Dependabot alerts were observed during the audit. Push protection and Dependabot security updates were enabled; required branch checks were retained.
- Twenty-eight CI artifacts had expired. Five Actions runs that failed at startup had no downloadable logs. Unknown, encrypted, steganographic or otherwise non-extractable secrets cannot be ruled out by these scans. No confirmed secret was found that warranted deletion or credential revocation.
- Real user clipboard/history databases and credential values were not inspected. Backup files themselves contain plaintext user content and must remain private.

## Changed behavior

- Deferred paste rechecks clipboard generation. Unacknowledged layout-correction paste does not restore unrelated old data or move the selection under a pending event; a separate status explains the uncertainty.
- Restore streams validated records into an app-created schema. Source triggers/tables are not copied; columns, migrations, IDs, relationships and independent history/total budgets are checked. Clipboard accounting is recalculated and old undo tokens invalidated.
- Backup staging starts with owner-only permissions and exclusive creation. Same-directory atomic publication preserves the old file on failed replacement and does not change existing folder permissions.
- Screenshot cropping inverts the actual overlay transform. Remembered PNG/JPEG agrees with filename and encoder; committed text uses its visible anchor.
- Optional light/dark backgrounds share preview/export composition, add bounded padding/shadow and preserve source pixels. Opaque redaction stays flattened. Small images are centered, actual dimensions shown and reduced large-display captures disclosed.

## Measured local data-path latency

Synthetic optimized fixtures; these exclude setup, native rendering and application startup. They are not a guarantee for every Mac or database.

| Operation | Median | p95 |
|---|---:|---:|
| History query, 100 rows | 0.58 ms | 0.77 ms |
| History query, 500 rows | 2.61 ms | 2.81 ms |
| History query, 2,000 rows | 10.03 ms | 10.42 ms |
| Full menu data read | 1.15 ms | 1.39 ms |

## UI and compatibility boundaries

Native AppKit tests verified save-panel format initialization/actions, actual PNG/JPEG bytes, text anchors and non-overlapping controls at 660/800/1000 points. Pixel tests covered composition dimensions, unchanged inner pixels, negative display origins and redaction invariance. Light/dark offscreen renders were inspected.

The computer-use service repeatedly timed out when inspecting an isolated synthetic Preview app. A process sample showed its ordinary idle AppKit event loop, not an established application deadlock. Physical Save-dialog click-through, additional monitors/scales, Spaces/full-screen combinations and physical-keyboard correction remain unverified. These limits are not described as passed or universal third-party-editor compatibility.
