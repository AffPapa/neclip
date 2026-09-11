# Plan

## P0

- Reconcile current branch, ahead commits, PR/release/site state and installed version.
- Reproduce screenshot/editor regressions addressed by the two unpushed commits.
- Audit security, privacy barriers, storage correctness, ScreenCaptureKit geometry and release provenance.
- Add or strengthen tests for every accepted fix.

## P1

- Remove only proven dead/duplicate work on hot paths.
- Tighten native labels, disabled/error states and accessibility where evidence shows a defect.
- Measure launch/menu/capture/render hot paths before accepting optimizations.

## P2

- Broad visual redesign, optional capture modes, market expansion and nonessential feature work.
- Record evidence-backed candidates in backlog; do not hold a safe P0 release for them.

## Verification

- `swift test --disable-sandbox`
- strict Swift 6 release build with warnings as errors
- ASan and TSan where supported
- `scripts/secret-scan.sh`, `git fsck`, `git diff --check`, plist/JSON validation
- release script signing/notarization/stapling/Gatekeeper/DMG checks
- installed native smoke and public GitHub/Pages/download checksum checks

