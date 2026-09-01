# NeClip 1.6.0 source audit — 1 September 2026

Scope: complete current Swift source, tests, local release controls, current
privacy boundary, a new from-zero 20-product clipboard matrix, a new 20-tool
layout matrix, five layout architectures and an exact 100-candidate catalogue.
The installed application, GitHub Releases and public 1.4.0 update manifest
were not changed.

## Three independent read-only tracks

1. **Clipboard:** 20 products were rechecked from platform, vendor and upstream
   sources. Durable low-complexity patterns were preview, immediate search,
   bounded storage, deliberate one-shot actions, app capture rules and queues.
2. **Layout:** 20 tools were separated into manual conversion, automatic word
   correction, last-used per-app memory, fixed per-app rules and per-physical-
   keyboard rules. Their permissions and UX were not conflated.
3. **Current code:** capture, database, menu, paste, snippets, hotkeys, layout,
   preferences, lifecycle, update policy, build scripts and baseline tests were
   traced before any mutation. Baseline was 111 XCTest plus eight Swift Testing
   checks, zero failures and one opt-in external-database skip.

The matrices, exact sources, 100 sequential candidates, scored top 20 and
add/defer/reject decisions are in `RESEARCH-1.6.0-ZERO-2026-09-01.md`.

## Implemented 1.6.0 slice

- Space invokes the existing local preview for the first visible result only
  when search is empty and the event is unmodified/non-repeating. Multiword
  search keeps ordinary spaces.
- **Append Next Text** is explicit and one-shot. It is mutually exclusive with
  ignore-next, is consumed only after a text passes empty/sensitive/size gates,
  and merges transactionally with the newest unpinned text using one newline.
  Files and images do not consume it. An over-limit combined value is stored as
  a separate valid copy, and incompatible RTF is discarded deliberately.
- A current input source can be fixed to the application that was active before
  the NeClip menu opened. Fixed rules have priority over optional last-used
  memory on activation, do not block a temporary manual change, observe no text
  or key events, and need no Input Monitoring. Menu, count and two unambiguous
  reset actions make the state visible.
- Total-byte trimming now deletes the minimal oldest unpinned prefix with one
  SQLite window query instead of fetching every row and deleting in a loop.
- Clipboard and layout application exclusions are trimmed, empty-filtered,
  deduplicated and sorted through one normalization path.

## Preserved boundary

No account, cloud sync, telemetry, advertising, AI, scripts, background network
request, Dock icon, large main window or new permission was added. Automatic
keyboard monitoring remains separate, explicit and off by default. Public
updates remain user-initiated and GitHub-bound.

## Verification evidence

- Final normal suite: 122 XCTest plus eight Swift Testing checks, 130 total,
  zero failures. One XCTest is intentionally skipped unless a disposable
  external database fixture is supplied.
- Strict Swift 6 complete-concurrency release build with warnings as errors:
  passed after the sandbox-blocked dSYM step was rerun with explicit approval.
- Complete AddressSanitizer and ThreadSanitizer suites: passed.
- The existing 10,000-row migration/1,000-item latency test and new set-based
  quota-boundary test passed.
- Official local Gitleaks 8.30.1 scan: publishable tree and all 28 fetched
  commits contained no detected secret.
- JSON/plist parsing, public/source version separation, exact 1–100 catalogue
  sequence and `git diff --check`: passed.
- Isolated QA bundle `org.affpapa.neclip.qa` used a temporary database and did
  not replace `/Applications/NeClip.app`. General, Privacy and Layout screens
  were visually and accessibility inspected. The inspection exposed two
  ambiguous **Reset** buttons, renamed to **Clear Memory** and **Remove All**.
  The new controls fit the existing compact window and have accessible labels.
- AppKit's modal menu tracking loop cannot be retained by the automated AX
  snapshot after it closes; menu contents and both presentation paths remain
  contract-tested, while a real menu-bar click stays in the signed-release
  manual QA gate.

## Release boundary

Source version is 1.6.0/build 10. Public `docs/version.json`, GitHub Releases
and `/Applications/NeClip.app` remain on signed/notarized 1.4.0. A local commit
is not a public release. Publishing still requires Developer ID signing,
notarization, stapling, mounted-DMG Gatekeeper verification and independent
SHA-256 validation through `build-app.sh`.

Verdict: the 1.6.0 source slice is locally verified for a separate release run;
it is not represented as publicly released.
