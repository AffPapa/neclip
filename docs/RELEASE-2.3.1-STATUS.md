# NeClip 2.3.1 / build 27 — release status

Дата: 2026-09-10. Финальный source commit: `b1b3aaee85a23f64eff1549ece103107b9761b39`.
Публичный manifest и GitHub Release указывают на exact-artifact этого коммита.

## Release gate

- 259 XCTest, 4 skipped, 0 failures; 3 Swift Testing checks passed.
- Strict Swift 6 release build: complete concurrency and warnings-as-errors passed.
- Developer ID signature, stapling and Gatekeeper passed for the app and DMG.
- App notarization: `8ce31073-a16b-4208-a80e-1b14b177456c`.
- DMG notarization: `8c886159-794f-4edc-b9a5-ccb584fa0f8a`.
- DMG: 2,034,114 bytes; SHA-256: `31f598fa2b6a674576708e93949d350ac3b2bc46ec1865606b99aa77fdf13269`.
- Release directory: `dist/releases/2.3.1-27-b1b3aaee85a23f64eff1549ece103107b9761b39/`.

## Installation

`/Applications/NeClip.app` is **2.3.1 (27)**, bundle `org.affpapa.neclip`.
The installed executable matches the notarized candidate. Gatekeeper reports
`source=Notarized Developer ID`, and LaunchServices confirms the UIElement is
running. User data and preferences were not replaced.

Rollback copy:
`/Users/dumay/Library/Application Support/NeClip Rollback/2.3.0-26-before-2.3.1-27/NeClip.app`.

The release includes the responsive capture overlay, explicit area-selection
instruction, image-first editor and compact bottom toolbar. Full end-to-end
Screen Recording acceptance was exercised on the authorized QA copy before
packaging; the finished PNG remains subject to the existing privacy barrier.
