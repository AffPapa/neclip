# NeClip 1.5.0 source audit — 1 September 2026

Scope: the complete current Swift source tree, test and release automation,
privacy boundaries, the 18-product clipboard matrix, the 19-product layout
matrix and the 100-candidate decision catalogue. The installed application,
public update manifest and signed 1.4.0 artifacts were not changed.

## Three independent read-only tracks

1. **Clipboard products:** reviewed 18 current products using vendor, platform
   or upstream-project documentation. The durable patterns were fast native
   recall, bounded history, deliberate one-time actions, clear retention and
   lightweight snippet organization.
2. **Layout products:** reviewed 19 tools and separated three architectures:
   manual conversion, global automatic word correction and input-source memory
   per application. Combining their permissions or switches was rejected.
3. **NeClip source:** traced capture, persistence, menu projection, paste,
   snippets, layout correction, settings, lifecycle, release scripts and all
   tests before choosing changes.

The matrices, exact 100-item catalogue, scored top 20 and add/defer/reject
decisions are in `RESEARCH-1.5.0-2026-09-01.md`.

## Implemented 1.5.0 slice

- A user-bounded 64–2048 KB limit for one complete text/RTF record before the
  database write. Oversized RTF is discarded first; oversized text is skipped.
- Confirmed cleanup choices for the last hour, today or all unpinned history,
  with pins and snippets protected; optional fail-closed cleanup on quit.
- **Paste and Delete** for the first unpinned result. Deletion occurs only after
  successful direct-paste event dispatch; copy-only and every failed/fallback
  path preserve the record. Exact undo remains available.
- Independent, default-off memory of the last selected input source for up to
  200 applications. It observes app activation and TIS source notifications,
  not text or key events, and needs no Input Monitoring permission.
- Visible remembered-application count/reset in Settings and a compact menu
  toggle. Automatic correction remains a separate switch and permission path.
- A bounded, RAM-only ignore list after the user undoes an automatic
  correction, preventing the same false correction for the rest of the session.

## Rejected for this version

Accounts, cloud sync, AI, telemetry, user scripts, boards, typed abbreviation
expansion, per-window/per-site layout observation and aggressive multi-language
automatic correction remain outside the product boundary. The remaining
high-scoring candidates stay documented rather than becoming hidden scope.

## Verification evidence

- Final normal suite: 111 XCTest cases plus eight Swift Testing cases, 119 total,
  zero failures. One XCTest is intentionally skipped unless a disposable
  external database fixture is supplied.
- Strict release compilation passed with Swift 6 complete concurrency and
  warnings as errors.
- AddressSanitizer and ThreadSanitizer each passed the complete suite.
- The 10,000-row migration and 1,000-item retained-history latency case passed.
- Official Gitleaks 8.30.1 checksum was verified; the publishable tree and all
  26 repository commits reported no detected secret.
- Public JSON parsing, source/public version separation, sequential numbering
  of all 100 catalogue entries and `git diff --check` passed.
- Isolated visual QA, without replacing `/Applications/NeClip.app`, confirmed:
  one system dark appearance across onboarding, the five-tab Settings window
  and the two-column snippet editor; aligned numeric controls; clear layout
  permission boundaries; visible snippet edit fields and autosave status.
- The native menu appearance is recursively pinned to the application's
  effective appearance in both status-item and hotkey paths and is covered by
  contract tests. Automated accessibility inspection cannot retain an AppKit
  menu after its modal tracking loop closes, so a real status-item click remains
  part of the signed-release manual QA gate.

## Release boundary

Source version is 1.5.0/build 9. Public `docs/version.json`, GitHub Releases and
the installed `/Applications/NeClip.app` remain on signed/notarized 1.4.0.
Publishing still requires the release-only Developer ID, notarization, stapling,
Gatekeeper, mounted-DMG and independent SHA-256 gates in `build-app.sh`.

Verdict: the 1.5.0 source slice is locally verified and ready for a separate
signed release run; it is not represented as publicly released.
