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

## Delivery 2

- Built final exact-source candidate from
  `61618d03ed266cc764c08fb23bc00de25c3003fb`.
- Final DMG is 2,048,962 bytes with SHA-256
  `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.
- App notarization ID: `0c918ef8-2b6d-4609-9a08-ec13df50e5cf`; DMG
  notarization ID: `0b13e563-6e6d-4277-adb3-9917985d4308`.
- App and DMG passed signing, stapling, Gatekeeper and mounted read-only DMG
  verification. The final app replaced only the intermediate candidate and was
  launched from `/Applications/NeClip.app`.
- Production SQLite integrity and foreign-key checks are clean. The rollback
  app/database/preferences backup remains preserved outside the repository.
- Production global-hotkey injection through UI automation did not prove the
  physical shortcut event; registration and handling remain covered by tests.
- Required CI for metadata commit `b8356c6` is green, including CodeQL Swift
  (19m39s), Swift 6 CI, full-history secret scans and CodeQL actions/ruby.
- Published immutable GitHub Release `v2.5.6` from exact artifact source commit
  `61618d03ed266cc764c08fb23bc00de25c3003fb` with DMG, checksum and provenance
  JSON. It is neither draft nor prerelease.
- Anonymous re-download matched 2,048,962 bytes and the expected SHA-256;
  Gatekeeper accepted the downloaded DMG as Notarized Developer ID.

## Delivery 3

- PR #32 merged normally after explicit user authorization and all required
  checks, producing main commit `738789498f150284722f2c0225c1d6dfa72e2723`.
- GitHub Pages built that exact commit successfully. Cache-busted live
  `version.json`, `changelog.json` and rendered HTML report 2.5.6/build 35 and
  point to the immutable v2.5.6 assets.
- A second anonymous post-deploy DMG download matched 2,048,962 bytes and
  SHA-256 `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`;
  the checksum file and Gatekeeper result agree.
- Repeat live audit caught stale rendered copy claiming 271 rather than 276
  XCTest and omitting final fallback/color fixes. A minimal docs-only follow-up
  corrects the public page, changelog feed and release evidence.
- A direct production status-menu smoke on the installed app (PID 31680)
  recorded `hotkey -> content-ready -> capture-ready -> selection-ready ->
  editor-visible` and exposed a 916 × 455 editor with the expected controls and
  initial red palette. The editor was closed without copying or saving private
  screen content.

## Delivery 4 — final integrity re-audit

- Fresh GitHub/main audit found stale root README release facts (date, evidence
  link, DMG size and SHA-256) and a stale current-release reference in
  `SECURITY.md`; both now match the immutable 2.5.6/build 35 release.
- `scripts/verify-site.rb` now rejects a README whose version, date, evidence
  link, download URL, size or checksum differs from `docs/version.json`.
- GitHub main protection now requires a PR, resolved conversations, strict
  up-to-date checks and CodeQL Ruby in addition to the existing test,
  full-history, CodeQL Actions and CodeQL Swift gates. Admin enforcement and
  force-push/deletion blocks remain enabled.
- Fresh publishable-tree/full-history/side-ref Gitleaks scans, ignored QA and
  artifact scans, and unreachable-blob scan found no leaks. GitHub has no
  repository Actions secrets, Dependabot alerts or open Code Scanning alerts.
- Fresh serial debug, strict Swift 6 release, ASan and TSan suites each passed
  276 XCTest (four intentional opt-in skips) and three Swift Testing checks;
  all three opt-in synthetic latency benchmarks then passed separately.
- Re-downloaded the public DMG with HTTPS redirect following: SHA-256 matched
  `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb` and
  Gatekeeper accepted it as Notarized Developer ID. Mounted-DMG content,
  signature and stapling checks passed.

## Delivery 5 — final documentation and local-artifact closure

- Re-audit found `BACKLOG.md` and `docs/backlog.json` still leading with 2.1.0
  despite the public 2.5.6/build 35 release. Both now expose the exact current
  version, download and release-evidence URL; older release notes are explicitly
  historical rather than active status.
- `scripts/verify-site.rb` now fails if the newest changelog entry or structured
  backlog release diverges from `docs/version.json`.
- Added `scripts/clean-local-artifacts.sh`, an allowlist-only cleanup for
  reproducible `.build*`, `.qa` and `.DS_Store` output. It deliberately leaves
  `dist/releases/current`, local release archives and user Application Support
  data untouched.
- Removed the confirmed local build/sanitizer/QA caches (about 4 GB before
  cleanup). The retained `dist/releases/current` still resolves to exact source
  `61618d03ed266cc764c08fb23bc00de25c3003fb`; its DMG retains the published
  SHA-256 `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.
- Fresh `swift test --disable-sandbox` passed 276 XCTest with four intentional
  opt-in skips and three Swift Testing checks; the complete secret scan remained
  clean across the publishable tree and 162 ref commits.
