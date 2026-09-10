# NeClip 2.3.0 / build 26 — installed local candidate

10 September 2026. Source commit: `aea3428a05b89beaabbc233e7e85ab4c11c03830`.
Branch: `codex/neclip-screenshots`. No GitHub push or public release in this work.

## Verified distribution chain

- Existing exact-commit release script: clean source tree, full tests, strict release build.
- 259 XCTest, 4 opt-in skips, no failures; 3 Swift Testing checks.
- All 12 screenshot tests also passed separately under ASan and TSan.
- Developer ID signing; app notarization accepted:
  `e76d0100-4a87-4ee7-8cc6-0018886301b9`.
- DMG notarization accepted: `b7c9ad14-b6bc-4d67-8700-e0c79c109f58`.
- App and DMG stapled; Gatekeeper accepted both; mounted DMG app reverified.
- DMG: 2,030,018 bytes, SHA-256
  `8dab7a445ed3dc13f84d77a4d08963f8edfa5752dd103624d372801510cb5518`.
- Signed executable: 4,410,464 bytes. Do not compare this signed size directly
  against an unsigned baseline with different signature padding.

## Local installation explicitly authorized by the user

Installed `/Applications/NeClip.app` is 2.3.0 (26), bundle `org.affpapa.neclip`.
Its executable matches the packaged candidate byte-for-byte:
`4d2425235f5d892bc578c7edfb7bb3e5ac48130cda8326a05e2dea4295749330`.
Signing, stapling and Gatekeeper were rechecked after installation.
The application process launched successfully. Synthetic QA was stopped to avoid
global-shortcut conflicts. No clipboard/snippet database or preferences were removed.

The previous signed app is recoverable at
`~/Library/Application Support/NeClip Rollback/2.2.0-25-before-2.3.0-26/NeClip.app`.
The scoped installer automatically restores it if replacement or verification fails.

## Functional acceptance remains partial

Live synthetic editor: all five tools, Russian text, undo/redo, PNG and JPEG system save,
and CmdReturn copy into a separate QA pasteboard passed. PNG and JPEG file I/O,
pixel geometry, privacy gates and mask independence also pass automated tests.

The installed application has the user's Screen Recording permission visible in
System Settings. A CmdShift2 attempt was made through UI automation, but its
resulting region window could not be obtained (CUA AX timeout). Neither success
nor a functional failure is inferred from that tool timeout. User confirmation /
interactive verification of actual capture is still required.
The subsequent native JPEG save passed: 720x420, 23,656 bytes, decoded and visually
checked. Multi-display/Spaces scenarios remain unverified.

Public metadata and download remain 2.2.0. Notarization is artifact verification,
not a claim that the screenshot feature passed its remaining live acceptance gate.
