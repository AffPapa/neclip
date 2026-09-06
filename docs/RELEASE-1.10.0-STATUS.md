# NeClip 1.10.0 / build 17 — source candidate

Updated: 6 September 2026. **Not a published binary release.**
The verified public download remains 1.9.1/build 16. `version.json` is unchanged.

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
  and derived FTS indexing are retired. Existing content, folders and pins remain.
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
Back up the database and export snippets before installing this candidate.
Downgrading to 1.9.1 requires its matching pre-upgrade database backup; replacing
only the binary is not a supported rollback. No production migration occurred
during this pass. Migration/content preservation is covered by synthetic tests.

## Distribution blocker

Developer ID identity is available. The `neclip` notarytool Keychain profile
is absent, and the API key file previously used for notarization is no longer
at its recorded location. No private-key contents were read or printed.
The user has been asked to restore the existing key locally or recreate the
`neclip` profile; credentials must not be sent in chat.

Until restored: no notarization claim, no new public DMG, no v1.10.0 release
tag and no advance of the application's download manifest. Source and website
publication may proceed with an explicit candidate label and the working 1.9.1 link.

## Verification status

Local debug, strict-release (complete concurrency, warnings-as-errors), ASan
and TSan passed for this candidate: each has 242 XCTest cases with three opt-in
skips and zero failures, plus four Swift Testing checks: 243 successful checks.
`ruby scripts/verify-site.rb`, `bash -n build-app.sh` and `git diff --check`
passed. Logs: `/tmp/neclip-110-*`.
GitHub CI, source merge, Pages deployment and live checks are recorded below
after their actual outcomes. Earlier successful checks are not substituted
for a signed/notarized 1.10.0 artifact or a complete live interface test.

## Resume binary release

1. Restore notarization credentials locally; check `notarytool history`.
2. Recheck clean reviewed commit and all required checks.
3. Run `build-app.sh` with `NECLIP_RELEASE_COMMIT` identifying that exact commit.
4. Verify app/DMG signatures, notarization, staple, Gatekeeper, UUID and checksums.
5. Publish the exact source tag and verified artifacts; independently download
   and compare the public DMG, provenance, checksum and mounted app.
6. Update release status, visible site and all four JSON feeds together;
   verify deployed HTML/JSON and public download again.

No existing public release or recovery data is deleted to make this version appear complete.
