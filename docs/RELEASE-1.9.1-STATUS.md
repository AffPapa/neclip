# NeClip 1.9.1 / build 16: released

Published: **2026-09-06T07:55:03Z**.
Release: https://github.com/AffPapa/neclip/releases/tag/v1.9.1

- Exact artifact source/tag: `ab1f98039f70a33b92b48ff9a1be15ad3f9f8282`.
- DMG: 2,744,259 bytes, arm64, macOS 14+.
- SHA-256: `4b1563a4b808a35e3dc6580f947f3ee598ca99fde899cb56fa322f345c166a95`.
- Developer ID signing, Apple notarization, stapling and Gatekeeper passed
  for the application and DMG, including the exact mounted application.
- The independently downloaded public DMG matches the size, checksum and
  provenance asset. The release tag identifies the artifact source above.
- [Source PR #10](https://github.com/AffPapa/neclip/pull/10) merged as
  `416586f2ad2bd35e07957e830fc3c82582a911e2` after all required checks passed:
  Swift CI, full-history secret scanning and Swift/Actions CodeQL.
  Local tests and scoped UI observations are in `AUDIT-1.9.1-2026-09-06.md`;
  no exhaustive interface-coverage claim is made.

The release remains local-only, menu-bar-only and without an account, cloud
synchronization or telemetry. No database migration or dependency was added.
Historical releases and research remain historical evidence, not extra
installed applications or competing download recommendations.

The public artifact was installed transactionally over 1.9.0 after a fresh
application ZIP, database and preferences backup. All snippet/folder fields
matched the pre-install digest; database integrity and foreign keys passed.
The rollback ZIP was independently restored: its exact 1.9.0 executable,
signature, notarization, Gatekeeper and backup database/preferences passed.

The installed app matches the public artifact. Immediate startup passed; its
command-runner child ended with the installer session. Native macOS launch
then produced a separate durable process owned by launchd. UI attachment to
the accessory-only app timed out despite that successful launch, so this is
not claimed as a second complete post-install visual pass. Isolated UI checks
and their limits are recorded in the audit.

Final allowlisted retirement moved old1.8/1.9 local release directories,
the unpublished candidate, an obsolete rollback archive, a duplicate DMG
and dangling version aliases to native Trash. The current immutable release
and one freshly verified1.9.0 rollback ZIP with database/preferences remain.
Older recovery databases/preferences were not removed. Trash was not emptied.
