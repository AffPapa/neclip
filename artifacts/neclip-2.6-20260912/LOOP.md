# NeClip 2.6 loop

## Outcome

Ship NeClip 2.6.0 as a local-only, keyboard-first clipboard workflow with:

- saving text history items as snippets with folder choice and exact duplicate handling;
- explicit context actions for paste/copy/open/save-as-snippet;
- local history search with type, app and date filters, without OCR or cloud indexing;
- a compact capture/privacy status center;
- token preview and localized starter snippets;
- safe snippet backup/export/restore UX;
- screenshot save/permission/display QA closure.

## Scope exclusions

No accounts, cloud sync, telemetry, AI, OCR, hidden content processing, Dock icon,
smart collections, macro scripting, or App Store distribution.

## Gates

1. Plan gate: owner files, migration strategy, duplicate policy and test commands known.
2. Delivery gate: targeted tests green after each vertical slice.
3. Full gate: XCTest, strict build, sanitizer evidence, performance and migration checks.
4. Release gate: physical UI, signing/notarization/Gatekeeper, GitHub asset and Pages live verification.

## Stop conditions

Stop on data loss, wrong target paste, token rendering while saving a history item,
search content leaving the machine, unexplained sanitizer failure, migration mismatch,
or any public metadata/checksum mismatch.

## Current state

2.5.8 is the rollback reference. Work began from the clean 2.5.8 release worktree;
branch creation was blocked because the linked Git metadata is outside the writable
workspace. Do not publish until an exact reviewed commit and release branch/tag are available.
