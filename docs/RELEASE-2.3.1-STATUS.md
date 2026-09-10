# NeClip 2.3.1 / build 27 — local installed release

Дата: 2026-09-10. Source commit: `ae3745ae1227db5a539bd0e9d40418ce531579ce`.
Публичная версия остаётся 2.2.0/build 25; GitHub не изменялся.

## Release gate

- 259 XCTest, 4 skipped, 0 failures; 3 Swift Testing checks passed.
- Strict Swift 6 release build: complete concurrency and warnings-as-errors passed.
- Developer ID signature, stapling and Gatekeeper passed for the app and DMG.
- App notarization: `3cabdfc9-6672-47e4-bba0-ad9513a5335e`.
- DMG notarization: `d246ae87-d509-4eaf-89d1-72970b2e29fe`.
- DMG: 2,034,114 bytes; SHA-256: `18d00e9c52a287fdcd2ca22c1a83761cd6d4f74f0dd48ba20d90a9072236c3f3`.
- Release directory: `dist/releases/2.3.1-27-ae3745ae1227db5a539bd0e9d40418ce531579ce/`.

## Installation

`/Applications/NeClip.app` is **2.3.1 (27)**, bundle `org.affpapa.neclip`.
The installed executable matches the notarized candidate. Gatekeeper reports
`source=Notarized Developer ID`, and LaunchServices confirms the UIElement is
running. User data and preferences were not replaced.

Rollback copy:
`/Users/dumay/Library/Application Support/NeClip Rollback/2.3.0-26-before-2.3.1-27/NeClip.app`.

The candidate includes the responsive capture overlay, explicit area-selection
instruction, image-first editor and compact bottom toolbar. Full end-to-end
Screen Recording acceptance remains a separate interactive check.
