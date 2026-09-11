# Run log

## 2026-09-11 baseline

- Clean worktree at `270096bd86055628339bb38fc12ae7f443f6d885`.
- Branch is two commits ahead of its remote tracking branch.
- Source and installed app both report 2.5.6/build 35.
- Production data directory is about 118 MB and was inventoried by path/size only; contents were not copied into the repository.
- Existing release evidence records signed/notarized 2.5.6 from older source commit `71c6716a...`; current HEAD therefore requires fresh provenance and release checks before publication.

## Delivery 1

- Synced current branch with `origin/main` using a normal merge; no history rewrite.
- Passed debug, strict release, AddressSanitizer and ThreadSanitizer suites.
- Passed opt-in hot-path measurements and migration on a disposable copy of the production SQLite database; the copy was removed immediately.
- Inspected Aqua/Dark Aqua synthetic editor renders.
- Found and fixed fallback display-ID inconsistency; added four regression cases.
- Installed exact-commit candidate and used the isolated screenshot QA bundle; live AX and screenshot inspection exposed a yellow/red initial palette mismatch.
- Synchronized the popup from the canvas color after AppKit layout and added a native selected-title assertion. The first DMG is superseded and will not be published.
- Live blue rectangle remained red, exposing missing UI-to-model color wiring. Shape drafts now receive `annotationColor`; text captures it at entry start. Added event-level drag and focus-loss tests.
- Repeat isolated QA showed a genuinely blue rectangle with the popup on `Синий`; Undo became enabled.
- Final serial debug/strict release/ASan/TSan gates each passed 276 XCTest (4 opt-in skips) and 3 Swift Testing checks. The initial parallel attempt had AppKit/pasteboard cross-process failures and is not used as release evidence.
- Public GitHub Release and Pages still report 2.5.5; 2.5.6 remains a candidate.
