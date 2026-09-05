# NeClip 1.8.0 / build 14: source refinement audit

Date: 2026-09-05. Local base: `5f51385`; fetched public main: `53f3a51`.

## Scope and outcome

Three independent read-only audits preceded implementation. Research covers
19 clipboard products, 11 layout tools and three adjacent tools. The matrix in
[RESEARCH-2026-09-05.md](RESEARCH-2026-09-05.md) has exactly 100 numbered rows,
27 selected refinements and explicit existing/deferred/rejected states.

The implementation completes the folder/search/edit workflow without a new
large window, accounts, cloud, telemetry, scripting or additional permissions.
It includes prior unfinished folder-hotkey changes; they were preserved, not
overwritten. This report does not claim every third-party application was
installed or inspected line by line.

## Evidence → cause → change → verification

| Evidence / cause | Change | Verification owner |
|---|---|---|
| Snippet search reset omitted footer | Shared Settings/Quit footer across initial/loading/results/error/reset | MenuSearchRequestTests + production-path review |
| History syntax consumed literal snippet text | MenuSearchRequest separates scopes | Literal `app:`/`type:` regression tests |
| Debounce retained prior keyboard entries | Clear entries/actions immediately; reject nested tracking | Main-actor generation/activation review |
| Deferred paste read a later menu target | Capture destination before closing; pass explicitly; completion cannot clear newer target | Paste-path review; target-app runtime matrix still pending |
| Folder menu recency order differed from editor | Shared sortIndex/ID ordering, folder counts and breadcrumb metadata | MenuSearchRequestTests and storage projections |
| Exact key was ranked only after a 20-row query | Canonical key ranking before LIMIT | 25 newer competing rows test |
| Editor retained externally changed pin/folder | Refresh clean state, preserve dirty draft | SnippetsEditorTests |
| Destructive folder message used filtered rows | Full database count | Hidden-by-search folder test |
| Editing variations required manual recreation | Duplicate, Command-F/N/D and direct-ID opening | Draft flush, pin/folder/keyword/usage tests |
| Editor deletion had no recovery | One-item undo with retained failed recovery | Restore, deleted-folder fallback and conflict tests |
| Full erasure could leave reusable memory state | Discard undo/drafts/cache/queued editor work/sequence | Editor full-erasure behavioral test; menu-path review |
| Mandatory layout IDs had mixed case matching | Normalize mandatory/system/self exclusions | LayoutCorrectionTests |
| Open Settings could show stale menu actions | Subscribe to existing change notifications | Notification/onChange review; no preference schema changes |
| Reset all keys was excessive for one mistake | Per-row transactional reset | Failure/success keeps unrelated registrations |
| Date renderer did unnecessary work and could amplify clipboard | Lazy linear token scan, literal escaping, bounded output | UTF-8, timezone, malformed token and small-budget amplification tests |
| Line splitting introduced CRLF empty lines | Character-level newline splitting, explicit line cleanups | CRLF/Unicode line tests |
| Query delimiters remained raw when encoding | RFC3986 unreserved component encoding and clear title | Reserved characters and Unicode roundtrip |
| Preview checked full-body Character count | Compare bounded slice endIndex instead | Large synthetic Unicode body test |

Removed two production-unused menu-length compatibility aliases; tests now
exercise the actual normalization API. No migration, user database or unrelated
workspace code was deleted. Full-body storage APIs used by migration/transfer
tests were not blindly removed.

## Checks

The runtime follow-up below supersedes the initial paused QA launch and test
counts. See [runtime repair](BUGFIX-RUNTIME-2026-09-05.md).

- Xcode selected at `/Applications/Xcode-beta.app/Contents/Developer`; Swift 6.4.
- Full ordinary suite: **167 XCTest checks, 0 failures, 1 opt-in external-DB
  skip**, plus **11 Swift Testing checks passed**. Total: 177 passed, 1 skipped.
- Strict release build: complete concurrency and warnings-as-errors passed.
- AddressSanitizer: full suite passed with the same single external-DB skip;
  process exit 0, no sanitizer errors reported.
- ThreadSanitizer: full suite passed with the same skip, exit 0; no data-race
  reports. This does not substitute for cross-application paste testing.
- Gitleaks detector canaries passed; publishable tree, 32 HEAD commits and 2
  side-ref-only commits clean. Remote refs refreshed with `git fetch origin
  --prune`. This is detector evidence, not a guarantee about external forks,
  GitHub caches, release assets or every possible secret format.
- `git fsck --full --no-reflogs`: no integrity errors; dangling historical
  objects retained for recovery, not blindly deleted.
- Info.plist, project/backlog/changelog/version JSON and `git diff --check`
  passed. Matrix numbering validated as 1–100 with exactly 27 selected rows.
- QA app uses its own bundle ID and temporary database, capture paused via
  command-line defaults, auto correction/layout memory disabled. Installed
  NeClip and real clipboard contents were not used as test fixtures.
- Native accessibility inspection confirmed starter folders, selected editor,
  creation/duplicate actions, search, pin and save status. Full visual/global
  shortcut/target-app coverage is not inferred from that accessibility tree.
- Sampled native visual QA: dark editor and Keys settings layout readable with
  no overlap. In the isolated QA database, duplicate kept text/folder, cleared
  the keyword and changed folder count 6→7; search and its visible clear button
  restored folders without losing editor selection. Later changes affected
  destination capture and pure preview logic, not those layouts. Arbitrary
  destination apps/global hotkeys and all settings tabs were not UI-certified.

Reproducible log locations and visual sampling limits are recorded in
`artifacts/neclip/looper-goals/20260905-discovery/delivery-1.md`.

## Delivery boundary

This is a **local source candidate**, not a new public binary. Download manifest
`docs/version.json`, public 1.4.0 artifact and `/Applications/NeClip.app` were not
changed. Local `docs/project.json` describes the source as local, not released.
GitHub Pages URLs in that source index become current only after a separately
verified source publication. No commit, push or release is implied by this audit.

Before binary publication: exact Developer ID signature, notarization, stapling,
Gatekeeper/mounted-DMG checks, checksums and UI/target-app release gates remain
required. The obsolete Command Line Tools blocker is not current: ordinary
tests now actually run with Xcode. Historical reports saying GitHub source
publication was blocked are superseded by the fetched main merge above, not
rewritten as if the old event never happened.
