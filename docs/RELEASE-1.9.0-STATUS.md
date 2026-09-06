# NeClip 1.9.0 / build 15: released

Published: **2026-09-06T05:09:41Z**.
Release: https://github.com/AffPapa/neclip/releases/tag/v1.9.0

- Exact artifact source/tag: `d168d1015c3933221c718633e9a4dfbdc4362729`.
- Source PR: https://github.com/AffPapa/neclip/pull/8, merged after all required
  Swift CI, full-history secret-scan and Swift/Actions CodeQL checks passed.
- DMG: 2,728,899 bytes, arm64, macOS 14+; immutable GitHub release.
- SHA-256: `a30180fd66c1742a641bb26c651db353eb70ff0703fa56eeb58ca5a867a2588e`.
- Complete rebuild, strict Swift 6 concurrency and warnings-as-errors: passed.
- Strict release tests: 222 passed, one optional external-database skip.
- Full ASan and TSan executions: each 221 passed, two optional skips, no errors.
- Developer ID, notarization, stapling and Gatekeeper for application and DMG:
  passed, including the exact app inside the mounted image.
- Fresh unauthenticated download: public checksum, provenance JSON, exact size,
  codesign, stapler and Gatekeeper passed. Mounted app contents matched the
  locally built release. The tag resolves to the exact artifact source above.
- Release binary does not contain DEBUG QA environment switches. Its designated
  requirement matches the previous installation; minimum deployment is 14.0.

Before installation, the stopped 1.8.0 app, database and preferences were backed
up in a new private recovery directory. The staged installer had rollback for
app, database and preferences, including signal/PID safeguards independently
reviewed before execution. It preserved all fields of the 11 snippets and their
folders, verified by a deterministic digest without publishing their contents.
Database integrity and foreign-key checks passed before and after installation.
The installed executable matches the independently verified public artifact.

The previous installed app was archived to a verified ZIP before retirement;
earlier recovery archives and user data were retained. Three disposable DEBUG
QA app bundles were likewise archived, leaving their synthetic fixtures intact.

The installer checked immediate startup. Its command-runner child ended with
that session; the app was then started through the native application launcher
and checked separately. The UI tool cannot reliably attach to the accessory-only
release app, so this report does not claim a second complete post-install
visual pass. The actual minimum-size Settings/editor scenarios and dark-mode
limitation are documented in `AUDIT-1.9.0-2026-09-06.md`.

The website and machine-readable metadata are updated in a separate protected
PR after public artifact verification. The application remains local-only,
menu-bar-only and without account, cloud synchronization or telemetry.
