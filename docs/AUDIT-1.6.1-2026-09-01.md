# NeClip 1.6.1 source audit — 1 September 2026

Scope: all retained product research and backlog, every current Swift owner,
tests, tracked files, all fetched Git history, update policy, dependency lock and
release automation. The installed application, GitHub Releases and public 1.4.0
update manifest were not changed.

## Reconciliation

Three independent read-only tracks were completed before source mutation:

1. **Promises and research:** changelog, backlog, project map, previous audit
   artifacts and all retained clipboard/layout studies were matched to current
   implementation. Earlier research preferred manual-only layout correction;
   later research allowed a conservative automatic mode. The existing boundary
   is coherent: manual correction is primary; automatic correction is isolated,
   explicit, off by default, memory-bounded and protected by context checks.
2. **Code and hot paths:** all Swift declarations and callers were indexed;
   capture, menu, paste, database, snippets, layout, lifecycle and updater flows
   were traced. No unused private declaration remained. Five members with no
   caller or persisted compatibility role were removed. Historical SQLite
   migrations and their compatibility tests were deliberately retained.
3. **Repository and release safety:** tracked paths, ignored local artifacts,
   refs, large objects, dependency resolution, workflows, update URL policy,
   release script and complete fetched history were inspected. Public/source
   version separation remains explicit.

## Implemented slice

- Password-manager bundle IDs are now an immutable, case-insensitive capture
  deny policy, not removable defaults. The policy applies both to the immediate
  source decision and to the delayed pasteboard-generation guard when focus
  leaves an excluded application.
- Privacy Settings show mandatory applications with readable product names and
  a lock instead of a remove button. Ordinary exclusions remain editable.
- The native menu now exposes one target-aware action: **Do Not Save from This
  App**, or **Save from This App Again** when an ordinary rule already exists.
  Protected applications show a disabled **always** state.
- Snippet import rejects empty and over-16 MB files before JSON decoding. The
  file picker checks metadata before loading and uses safe memory mapping for an
  accepted file. Existing 5,000-record, field-length and per-content limits
  remain in force; insertion is still one merge-only transaction.
- Removed an unused capture-pause alias, storage clearing wrapper, layout tail
  helper and two write-only snapshot/undo fields. No migration, public contract
  or recovery evidence was deleted.

## Optimization and standards check

- The source uses Swift tools 6.2 and Swift 6 language mode. A strict release
  compile with complete concurrency checking and warnings as errors passed.
- GRDB remains exactly pinned to 7.11.1 in `Package.resolved`; upstream's current
  package metadata also reports 7.11.1. No new dependency was added.
- Large clipboard payloads remain bounded before decode/persistence, menu rows
  use summary projections instead of image/RTF BLOBs, database work stays off
  the main thread, and quota trimming remains set-based SQL.
- The automatic layout event path was reviewed but not speculatively rewritten:
  its short critical section protects sequence identity. Any future change must
  start with measured latency and race tests, not line-count reduction.

## Verification evidence

- Debug application build: passed.
- Strict Swift 6 release build with `-strict-concurrency=complete` and
  `-warnings-as-errors`: passed. The sandbox blocked only dSYM creation; the
  same command completed after explicit escalation.
- AddressSanitizer- and ThreadSanitizer-instrumented application builds: passed.
  Sanitizer test suites are not claimed because the test runtime is blocked as
  described below.
- The current test target and the added security cases compile under a temporary
  Swift-Testing-only package projection. Executing the normal test suite is
  blocked on this machine by an internally incomplete Apple Command Line Tools
  installation: the active compiler is `6.4.0.30.4`, the SDK interfaces are
  `6.4.0.31.4`, `XCTest.framework` is absent, and the shipped Testing framework
  has no matching `TestingMacros` plugin. The last complete source gate, before
  that toolchain replacement, remains 130 passing checks for 1.6.0. This report
  does not claim a current full-suite or sanitizer pass.
- Plist/JSON validation, `git diff --check` and `git fsck --full`: passed.
- Gitleaks 8.30.1: no detected secret in the publishable tree or all 29 fetched
  commits. Findings were redacted by policy even though the result was empty.
- An ad-hoc-signed QA bundle used `org.affpapa.neclip.qa.161`, separate defaults
  and `/private/tmp/neclip-1.6.1-qa-data`; it did not replace the installed app.
  Accessibility and visual inspection covered General and Privacy Settings.
  QA exposed technical fallback labels such as `Desktop`; they were replaced
  with readable password-manager names and the corrected screen was rechecked.
  The target-aware menu action remains source/contract checked, not manually
  exercised, because activating the regular QA window removes the prior target.

## Deferred by design

Session-only history, reverse sequential paste, separate image quota, screen-
sharing concealment, multi-copy groups, drag-out, QR, color preview and per-app
plain-paste rules remain candidates, not commitments. Adding them together
would weaken the product's small, understandable menu and cannot be justified
without measured use.

## Release boundary

Source version is 1.6.1/build 11. Public `docs/version.json`, GitHub Releases and
`/Applications/NeClip.app` remain on signed/notarized 1.4.0. Publishing still
requires a complete test/sanitizer gate in a consistent Xcode toolchain,
manual menu QA, Developer ID signing, notarization, stapling, mounted-DMG
Gatekeeper verification and independent SHA-256 validation.

Verdict: the source cleanup and privacy slice are implemented and compile under
strict Swift 6. Public release readiness remains blocked by the local Apple
test-toolchain installation and the unrun release-only gates above.
