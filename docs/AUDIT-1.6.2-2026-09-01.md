# NeClip 1.6.2 source audit — 1 September 2026

Scope: the complete retained NeClip research and backlog, every current Swift
owner and test contract, local Git objects and fetched refs, dependency lock,
secret scanning, update policy and release automation. The installed
application, GitHub Releases and public 1.4.0 update manifest were not changed.

## Three read-only tracks

1. **Promises and research.** All retained clipboard-manager and keyboard-
   layout studies, previous audits, loop artifacts, changelog and backlog were
   reconciled with the current product. The durable boundary is unchanged:
   native menu-bar utility, local-only data, manual layout correction primary,
   automatic correction optional/default-off, no accounts, cloud, telemetry or
   remote AI.
2. **Code and hot paths.** Every source/test file was indexed; capture, storage,
   menu/search, snippets, pasteboard replacement, layout correction, settings,
   lifecycle and updates were traced. No additional declaration was removed
   merely for age or line count. Migrations and research remain because they
   provide compatibility and evidence.
3. **Repository and release safety.** Tracked/ignored/untracked paths, all refs,
   large blobs, local unreachable commits, dependency resolution, workflows,
   signing/notarization gates and public/source version separation were checked.

## Repaired gaps

- The 1.6.1 plist was still tested as 1.6.0/build 10. The contract now asserts
  the actual 1.6.2/build 12 source version, so a stale prior test result can no
  longer be presented as proof for a newer source tree.
- Native menus, snippet search and the editor sidebar now use
  `SnippetSummary`: identifiers and metadata plus at most 280 content
  characters. SQLite still searches complete FTS content, but one full body is
  fetched only when the user selects or pastes that snippet. Editor-created and
  updated snippets now share the portable import's 200-character title/folder,
  100-character normalized keyword and 2 MB content bounds.
- Deduplicating the latest copy now replaces RTF exactly. Copying the same value
  as plain text can no longer retain styling from an older rich-text copy.
- Manual selection replacement captures every advertised pasteboard
  representation. A lazy/promised representation that cannot be read aborts
  before `clearContents`; an intact snapshot is still restored only when the
  pasteboard generation has not changed.
- Automatic correction performs fewer redundant focused-context reads inside
  the event-sequence critical section. The sequence match, source match,
  whole-value/range compare-and-swap, result verification and guarded rollback
  remain intact.
- `scripts/secret-scan.sh` now proves its embedded GitHub PAT, AWS and Slack
  rules with generated valid canaries before trusting a clean exit. It scans
  the publishable tree, HEAD history and side-ref-only commits separately.
  Public audit-document scanning now discovers every `docs/AUDIT*.md` file
  instead of maintaining a stale three-file list.

## Security evidence

- Gitleaks 8.30.1 detected every generated canary without printing its value.
  It then found no leak in the publishable working tree, 30 HEAD-reachable
  commits or two side-ref-only commits. Two of the 32 reachable commits are
  content-empty merges, leaving 30 content-bearing commit diffs.
- Local dangling-commit histories observed during the audit were also scanned
  and clean. They
  were retained as recoverable local history. The only `git fsck` garbage was
  an empty worktree-metadata `refs` directory; it was removed with `rmdir`.
- No ignored credential file, database, archive, key, profile or environment
  file is tracked. Large tracked objects remain expected application icons and
  retained research rather than private runtime data.
- GRDB remains the sole exact source dependency at 7.11.1. No new package or
  network service was introduced. The checkout action remains pinned to the
  full verified v7.0.1 commit rather than a mutable major tag.
- No confirmed secret exists, so destructive history rewriting would add risk
  without removing evidence and was not performed.

## Verification

- Debug application build through the consistent temporary macOS 26.5 SDK
  projection: passed.
- Strict Swift 6 release build with complete concurrency checking and warnings
  as errors: passed. `dsymutil` required the already-approved out-of-sandbox
  execution; source compilation itself was clean.
- AddressSanitizer- and ThreadSanitizer-instrumented application builds: passed.
- Changed test files parse successfully; the new tests cover bounded snippet
  summaries, local snippet limits, stale RTF removal, complete/empty pasteboard
  snapshots and rejection of unreadable promised data.
- The ordinary test command reaches the test target but cannot resolve XCTest.
  The active Apple Command Line Tools are internally inconsistent: compiler
  `6.4.0.30.4`, SDK interfaces `6.4.0.31.4`, no `XCTest.framework`, and no
  matching `TestingMacros` plugin. Therefore no current full-suite or sanitizer
  test-suite pass is claimed. The repair is to install full Xcode and select
  `/Applications/Xcode.app/Contents/Developer`, then rerun the release gate.
- Plist/JSON syntax, source parsing, `git diff --check`, Gitleaks and Git object
  integrity were rerun after the final changes.

## Release boundary

Source version is 1.6.2/build 12. Public `docs/version.json`, GitHub Releases
and `/Applications/NeClip.app` remain on signed/notarized 1.4.0. Publishing still
requires full Xcode, the complete test/sanitizer test gate, target-aware manual
menu QA, Developer ID signing, notarization, stapling, mounted-DMG Gatekeeper
verification and independent SHA-256 validation.

Verdict: the second zero-based pass repaired concrete performance, correctness
and security-proof gaps without expanding NeClip's product surface. The local
source candidate is compile-clean under strict Swift 6; public release readiness
remains blocked only by the incomplete Apple test toolchain and unrun external
release gates.
