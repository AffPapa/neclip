# NeClip 2.3.1 / build 27 — release status

Дата: 2026-09-10. Финальный source commit и checksum записываются в
`dist/releases/<version>-<build>-<commit>/*.release.json` после последнего
изменения исходников; публичный manifest обновлён для этого exact-artifact.

## Release gate

- 259 XCTest, 4 skipped, 0 failures; 3 Swift Testing checks passed.
- Strict Swift 6 release build: complete concurrency and warnings-as-errors passed.
- Developer ID signature, stapling and Gatekeeper passed for the app and DMG.
- Previous local notarization evidence was accepted for the installed candidate;
  the final public artifact is rebuilt after this source/metadata commit so its
  provenance is exact and independently verifiable.

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
