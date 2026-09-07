# NeClip 1.10.0 / build 17 — released

Published: **7 September 2026, 08:15:45 UTC**.
[GitHub release](https://github.com/AffPapa/neclip/releases/tag/v1.10.0).
The public DMG has been independently downloaded and verified. The flat-menu
and legacy-pin retirement pass is documented in
[menu simplification](MENU-SIMPLIFICATION-2026-09-07.md).
Website and updater delivery, including the post-deployment verification receipt,
is tracked in [PR #14](https://github.com/AffPapa/neclip/pull/14).
The installed app and production database have not been changed.

## Exact public artifact

- Artifact source and actual `v1.10.0` tag:
  `60b26ad6182550e3e9b2646a0ee3bf319ea6e8ac`.
- [Source PR #13](https://github.com/AffPapa/neclip/pull/13) merged as
  `682ce5370d6c8ee5a95291fa63e114c9e50d2546` after all required checks passed.
  The merge commit is not substituted for the exact artifact source above.
- [DMG](https://github.com/AffPapa/neclip/releases/download/v1.10.0/NeClip-1.10.0.dmg):
  **2,006,978 bytes**, arm64, macOS 14+.
- SHA-256:
  `d1f52a358b716a14d1fe60d28870af9a486a7defe6094f6396000c742cee9d1c`.
- Developer ID signing, Apple notarization, stapling and Gatekeeper passed for
  the application and DMG, including the mounted public application.

## Scope and completion gates

This pass reviews the local changes after 1.9.1, removes unused work, rebuilds,
checks secrets, publishes reviewed source through required GitHub checks and
updates the existing GitHub Pages site. No new hosting service, account,
dependency, search feature or telemetry is introduced. The installed app and
its database are not replaced by this source-publication workflow.

Three pre-change checks: runtime/snapshot and OCR paths; release/signing and
GitHub configuration; public HTML/JSON consistency. The public branch is
protected with Swift CI, full-history secret scanning and Swift/Actions CodeQL.
Those checks must pass; branch protection is not bypassed.

## Included changes

- Immediate-use history and folder snippets. Search fields, keys, filtering
  and derived FTS indexing are retired. Folders appear directly in both menus.
  First-item actions and new pin controls are removed; existing protected clips
  remain available with explicit unpinning and a retention warning.
- Selective menu refresh and bounded application metadata caching; separate
  UUID-matched dSYM outside the shipped app. Measurements and eight-product
  comparison: [optimization report](OPTIMIZATION-2026-09-06.md).
- Explicitly opening the menu retries a failed/dirty read, rather than waiting
  for another clipboard change to recover an empty or stale menu.
- Removed unused OCR success/failure notification routes. Storage remains the
  single update signal. Failure diagnostics log only constant generic messages,
  never copied text, IDs, paths or raw error strings.
- Compact retention controls; the entire Additional header is clickable and
  active automatic cleanup stays visible while collapsed.
- Transactional full-erasure invalidation, atomic clip-to-snippet conversion,
  OCR-only reads and lazy append fallback from the earlier local safety pass.
- HTML/JSON source and download statuses are separated. Current feature lists
  no longer advertise removed search; historical changelogs remain historical.
- A read-only website coherence gate runs in CI, validating the current public
  download, candidate version, checksum format, JSON, metadata and local links.

## Upgrade boundary

Migration v7 removes derived FTS tables/triggers, not user clips/snippets.
Back up the database and export snippets before installing this release.
Downgrading to 1.9.1 requires its matching pre-upgrade database backup; replacing
only the binary is not a supported rollback. No production migration occurred
during this pass. Migration/content preservation is covered by synthetic tests.

## Notarization access restored

The earlier missing-credentials blocker is resolved. The user configured the
local `neclip` Keychain profile; its read-only notarization history check passed.
The existing Developer ID identity was reused, without requiring a new signing
certificate. No private-key or account-secret contents are included in this report.
Application submission `439a664d-7d4a-4b59-8953-6ff10873161d` and DMG submission
`86c64a01-05f5-47c5-b1e7-3dea275bb2a3` were both accepted by Apple.

## Verification status

Local debug, strict-release (complete concurrency, warnings-as-errors), ASan
and TSan passed for the final code: each has 244 XCTest cases with three opt-in
skips and zero failures, plus four Swift Testing checks: **245 successful checks**.
`ruby scripts/verify-site.rb`, `bash -n build-app.sh` and `git diff --check`
passed. Required GitHub Swift CI, full-history secret scanning and Swift/Actions
CodeQL passed before the protected source merge; branch protection was not bypassed.

`build-app.sh` completed from the exact source above, preserving a UUID-matched
dSYM outside the shipped app. Build/notarization evidence is in the private local
log `/tmp/neclip-110-release.log`.

The independent public verifier checked the actual Git tag target, public release
metadata, provenance, checksum, size, arm64 architecture, signatures, stapling,
Gatekeeper and full mounted-app comparison against the verified local artifact.
It completed successfully and ejected the mounted image. Local evidence:
`/tmp/neclip-110-public.log` and `.qa/110/public.Tme2dT/`.

Isolated native UI checks and their limits are recorded in the menu report.
No complete third-party-app paste/automatic-correction coverage or production
installation is claimed.

## Website and updater delivery evidence

The binary is public and verified. [PR #14](https://github.com/AffPapa/neclip/pull/14)
updates the visible site and all four JSON feeds together through the protected
branch. Its deployment receipt records the exact Pages commit, live HTML/JSON
byte comparison, MIME types and rendered-page check after deployment. Consult
the PR state and receipt for delivery evidence: a local edit or source commit
alone does not prove that the website or updater feed has deployed.

No existing public release or recovery data is deleted to make this version appear complete.
