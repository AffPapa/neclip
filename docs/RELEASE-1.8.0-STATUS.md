# NeClip 1.8.0 / build 14: released

Published: **2026-09-05T16:45:38Z**.
Release: https://github.com/AffPapa/neclip/releases/tag/v1.8.0

- Exact artifact source/tag: `24ebd53d15efa540d944823431c59524b9ae3afa`.
- Source PR: https://github.com/AffPapa/neclip/pull/6, merged after green checks.
- DMG: 2,731,971 bytes, arm64, macOS 14+.
- SHA-256: `f2bb3c00acdc18b28906f671b04880d600c237c4abee417c43623675b2a121c2`.
- Full rebuild, complete concurrency, warnings-as-errors: passed.
- Tests: 206 passed, one opt-in skip, no failures.
- GitHub Swift CI, Swift/Actions CodeQL and full-history secret scanning: passed.
- Developer ID, Apple notarization, stapling and Gatekeeper for app and DMG:
  passed, including the app inside the exact mounted image.
- Fresh unauthenticated public download: checksum, codesign, stapler and
  Gatekeeper passed again. Its executable matches `/Applications/NeClip.app`.

The missing default profile was resolved by explicit user authorization to use
an existing working Keychain notarization profile. Credentials stayed in
Keychain and were never exported or committed. No further credential setup is
needed for this release.

Before local installation, both libraries and the previous app were backed up.
A staged transactional merge preserved original rows and copied missing preview
records without keyword conflicts. Integrity and foreign-key checks passed.
Existing history limits were retained. Old duplicate apps were archived before
retirement; user data directories were not deleted.

Post-install process and database checks passed; the bundle remains
menu-bar-only. The UI tool could not reliably attach to the final accessory-only
app, so this report does not claim a second complete post-install visual pass.
Earlier isolated visual QA is documented in the linked audit reports.

## Historical pre-release snapshot (superseded)

The text below records the earlier blocker, now resolved above. Its setup
instructions are historical, not required actions for this release.

Date: 2026-09-05. This page distinguishes verified source from downloadable apps.

The source candidate includes the settings/editor follow-up, capture cleanup
barrier, clearer keyboard commands, bounded search and snippet rendering.
The final pre-release refinement avoids a full grapheme count for oversized
privacy rules while editing. See `UX-SETTINGS-2026-09-05.md` for coverage and
known limits. No broad late-stage feature work was added to the release.

GitHub authentication and the NeClip Developer ID signing identity are
available. The required `notarytool` Keychain profile `neclip` is missing.
No credentials belonging to another application are used as a fallback.

A fresh, separate release build directory was used for a complete rebuild:
196 XCTest cases (one opt-in skip, zero failures) and 11 Swift Testing cases
passed with complete concurrency and warnings-as-errors: 206 passed, one skip.
The publishable tree and fetched Git history passed the secret scanner.

Until the reviewed source commit passes `build-app.sh` notarization, stapling,
Gatekeeper and exact-DMG verification, the signed public download and updater
manifest remain at **1.4.0**. Do not install or label a source candidate as a
notarized public release. Do not delete the working installation or its rollback
release before the replacement passes these gates.

To unblock distribution, configure the `neclip` profile locally using Apple's
`xcrun notarytool store-credentials neclip` interactive flow. Credentials must
stay in Keychain, never in Git, documentation, command transcripts or chat.
Then run the existing release pipeline against the exact reviewed commit,
verify the resulting app and DMG, publish, verify the downloaded artifact and
only then replace the local installed app and retire duplicate test copies.
