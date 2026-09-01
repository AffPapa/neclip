# NeClip 1.7.0 source audit — 1 September 2026

## Verdict

NeClip 1.7.0/build 13 is a locally verified source candidate. It is not yet a
public binary release. The repository-owned update manifest, GitHub Release and
installed application correctly remain on signed and notarized 1.4.0 until an
exact clean commit can be notarized and published.

The product boundary remains unchanged: menu-bar-only, Apple Silicon, macOS
14+, local SQLite data, no account, cloud sync, telemetry, advertising or AI.
The only network action is the user's explicit update check.

## Method

Three independent read-only tracks reviewed the same starting tree before any
mutation:

1. Product and accessibility: menu hierarchy, snippets, Settings, permission
   states, keyboard focus and recovery copy.
2. Code and performance: main-thread work, database queries, event queues,
   image/OCR memory, concurrency and update semantics.
3. Security and release: repository refs and objects, CI permissions,
   dependency provenance, signing/notarization, Pages and rollback truth.

Their findings were synthesized into the 100-point release plan under
`artifacts/neclip/looper-goals/20260901-v1.7.0-global-release/`. A separate
isolated QA application used a temporary bundle identifier and database; it did
not read or replace the installed NeClip.

## Product and UX changes

- The snippet sidebar now uses native List selection with non-optional row
  identifiers. Whole-row click and native Up/Down navigation select the same
  draft; mutations are deferred one main-loop turn to avoid reentrant
  `NSTableView` delegate work.
- Snippet grouping is computed once per reload, search is debounced by 120 ms,
  clip-only storage notifications no longer reload the editor, and an empty
  query result explains how to clear the search.
- The history root stays compact. Sequential paste, layout, capture, cleanup
  and manual update controls live under **Management**; editing, Settings and
  Quit remain directly visible.
- Recent application filters show local display names but insert exact bundle
  identifiers, so applications with spaces are not parsed as free text.
- The snippets-only menu now includes Settings and Quit. A native application
  menu also owns Command-Q, so Quit remains available while an editor window is
  active.
- Pasteboard permission `.needsChoice` is orange and actionable rather than
  appearing as granted. Layout memory labels distinguish automatic memory from
  manually fixed applications.
- Paste-and-delete was removed. Successful event dispatch cannot prove that a
  target application accepted a paste; deletion is now an explicit action with
  local undo.

## Correctness, privacy and performance changes

- Clear-on-quit stops observation and drains every queued immutable clipboard
  snapshot before deletion. If deletion fails, monitoring restarts and quit is
  cancelled.
- Starting monitoring re-baselines the pasteboard generation, frontmost app and
  exclusion guard, so values copied while monitoring was intentionally stopped
  are not misattributed later.
- FTS update triggers run only when searchable content changes; pin, usage and
  timestamp writes no longer delete and reinsert large text bodies.
- Semantic type filters page through lightweight summaries instead of becoming
  blind after the newest 200 unrelated rows. Original image and RTF BLOBs stay
  outside menu/search queries.
- Image inspection creates a maximum-1600-pixel PNG preview off the main actor
  and does not retain the original image BLOB in presentation state. OCR keeps
  the running job and newest pending image rather than an unbounded pending
  queue.
- Layout context invalidations are coalesced, valid layout key sets are cached,
  and disabling automatic correction cancels pending refresh work.
- Clear, erase, starter restore and snippet import/export operations run away
  from the main actor with visible progress and disabled duplicate controls.
- Existing Application Support directories are normalized to mode 0700 and the
  SQLite file to 0600.
- Update comparison now checks both semantic version and build number.

## Release and repository hardening

- CI checkout no longer persists a Git credential. The secret-scan workflow
  explicitly fetches public pull-request heads in addition to branches and tags.
- Local secret scanning first proves GitHub, AWS and Slack detectors with
  generated canaries, then scans the publishable tree, HEAD history and side
  refs with complete redaction.
- `.p8` signing keys are ignored regardless of filename. No signing key,
  environment file, credential, database, release archive or private clipboard
  sample is tracked.
- The release script requires a clean tree and an exact full
  `NECLIP_RELEASE_COMMIT`, verifies a pre-existing version tag if present,
  accepts only an exact arm64 binary, records commit/build/hash evidence and
  atomically switches a local `dist/releases/current` pointer only after all
  signing, notarization, stapling, Gatekeeper and checksum gates pass.
- Security documentation no longer asserts current branch protection without
  an authenticated GitHub rules check.

## Verification evidence

- Normal full Xcode run: 132 XCTest checks and 11 Swift Testing checks; 142
  passed and one opt-in external-database test was intentionally skipped.
- A transactionally copied disposable live database passed `quick_check` and
  the opt-in migration/count-preservation test separately.
- AddressSanitizer run: same available test surface passed with no ASan report.
  Leak detection is unsupported by the macOS ASan runtime and was explicitly
  disabled; address checks remained enabled.
- ThreadSanitizer run: same available test surface passed with no TSan report.
- Strict Swift 6.4 production build with complete concurrency checking and
  warnings-as-errors passed under Xcode 27 beta.
- Shell syntax, ShellCheck, plist, JSON and `git diff --check` passed.
- Gitleaks 8.30.1 found no leak in the publishable tree, 32 HEAD commits, the
  side-ref-only commit, six unreachable commits or nine standalone unreachable
  blobs. No history rewrite or credential revocation was justified.
- Isolated UI QA proved full-row snippet selection, native Down-arrow movement
  from **Спасибо** to **Получено**, synchronized editor fields and Command-Q
  termination without the previous reentrant table warning.

## Publication truth and blockers

The public 1.4.0 DMG remains valid: Developer ID signature, notarization,
stapling, Gatekeeper and the published SHA-256 were independently verified.
`docs/version.json` therefore remains on 1.4.0.

Two external credentials are unavailable in the current environment:

- the expected `notarytool` Keychain profile is absent and no direct App Store
  Connect API-key variables are configured;
- both locally known GitHub CLI sessions report invalid tokens.

The pipeline fails closed before modifying a known-good distribution. No
unsigned or unnotarized 1.7.0 app is installed or published, no public manifest
is advanced, and no claim of a live 1.7.0 release is made. Source and Pages may
be pushed only after authenticated GitHub access is restored; binary release
still additionally requires notarization credentials.

## Rollback and next gate

The rollback point is the existing public v1.4.0 release, its immutable DMG and
current Pages manifest. The next operator must restore authenticated GitHub and
notarytool access, create one reviewed clean commit, run `build-app.sh` with its
exact full SHA, publish without force, then re-download and re-verify the public
DMG before changing `docs/version.json` or the installed application.
