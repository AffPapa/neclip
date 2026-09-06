# NeClip 1.9.1 — native settings and safer editing

Status: local release candidate, build16. Public release remains1.9.0 until
the signed artifact, protected GitHub publication and download checks finish.

## Scope and evidence

Three independent read-only reviews covered local release/test copies,
Apple-native interface organization and Swift button/lifecycle correctness.
The goal is clarity and reliability, not an arbitrary reduction in source size.
No database migration, new dependency, cloud service or telemetry was added.

## Changes

- Settings use a native, noncustomizable, icon-and-label macOS toolbar with
  five persistent categories and explicit selected state.
- History retention and image capture are separate from menu appearance and
  paste behavior. Launch-at-login has its own group.
- Numeric drafts apply on Enter, focus loss, section change, window close or
  app quit; Escape cancels. Partial keystrokes never trim history.
- One-shot skip/append commands remain in the menu, with state/cancellation;
  duplicated activation-only buttons were removed from Settings.
- Adding an already-excluded application gives clear feedback; retention
  cleanup errors are no longer swallowed. Permission labels identify actions.
- Native application commands provide About/version, Settings with Command-comma,
  and Edit responder-chain actions for ordinary text editing.
- The history inspector protects dirty drafts during close, replacement and
  quit. Failed saves retain the draft. Command-S saves, and only the newest
  asynchronous open request may present a result.
- Full data erasure clears inspector drafts, OCR and preview state and rejects
  stale pending loads. It cannot reinsert erased content through a saved draft.
- Inspector byte metadata refreshes after save; editing clears stale success
  feedback. Unchanged records have a disabled Save button.
- First-run help focuses on history, search and snippet folders. Explanations
  scroll while permission/continue actions remain reachable.
- Local menu commands use the same physical key mapping as global shortcuts,
  so Russian-layout letters do not disable E/P/S/Z/O or digit commands.
  Focus-gated AppKit key equivalents preserve ordinary text editing behavior.

## Apple design basis

Apple recommends a persistent, noncustomizable toolbar for macOS settings;
the implementation uses AppKit rather than a custom imitation. Concise action
labels and standard responder commands preserve platform conventions.
[Settings HIG](https://developer.apple.com/design/human-interface-guidelines/settings),
[Writing HIG](https://developer.apple.com/design/human-interface-guidelines/writing),
[Buttons HIG](https://developer.apple.com/design/human-interface-guidelines/buttons).

## Verification so far

- Final full normal and strict Swift6 complete-concurrency/warnings-as-errors
  suites:232 XCTest cases,2 optional skips,0 failures;11 Swift Testing checks
  passed (241 successful checks total).
- Final full ASan and TSan suites completed with exit0, the same test count and
  no sanitizer error after the menu command and isolated first-run test changes.
- Isolated Settings: all five categories rendered at600px width; native toolbar
  and Close remained visible (actual constrained height554px). All five shortcut
  recorders fit. Escape cancelled a shortcut recording and a numeric draft.
- A numeric value persisted across section changes; another persisted after
  red-button close. Destructive history confirmation offered Cancel; cancelling
  returned to Settings without deleting data.
- Dark inspector rendered at500px width, Command-S saved and disabled Save;
  dirty close presented Save/Discard/Cancel. Automated UI attachment after modal
  transitions was intermittent, so model tests separately prove cancel/failure,
  real full erase and stale-load behavior. No universal UI-coverage claim.
- Dark first-run rendered at560px width with scrollable help and fixed Continue;
  Continue followed by Command-comma opened native dark Settings. Standard About
  showed1.9.1(build16). Command-Shift-B opened snippet folders. Final manual
  Command-E verification was interrupted by unrelated keyboard input; synthetic
  key events and focus-routing tests prove the new handler without posting events
  to other applications. The isolated QA app was stopped to avoid intercepting input.
- Gitleaks canaries, publishable tree,44 HEAD commits and2 side-ref-only commits
  passed before the release commit. Final fetched-ref scan remains required.

## Local cleanup

An exact allowlisted cleanup removed four unused generated caches (2.17GB
allocated) and sent20 obsolete installer/test artifacts (50.5MB) to native
Trash. An independent pass verified every source target absent and every Trash
destination present, with exact SHA256 matches for all19 regular files.
The twentieth item is a retired application directory. Trash was not emptied.
APFS physical free-space increase is not claimed from allocated-size measurements.

Source Git ownership, active build files, all user databases/preferences and a
separately restored/signed/notarized rollback were retained. Production database
integrity and foreign keys passed;11 snippets,2 folders and100 history records
were present. Private paths and data are not part of public release metadata.

## Remaining delivery gate

Complete final first-run/settings/menu visual checks; finalize source input,
repeat release tests and secret scanning; sign/notarize/staple; pass protected
CI; independently verify the public download; update website/machine feeds;
install transactionally with fresh rollback and data verification; retire this
task's QA bundles and obsolete executable rollback duplicates. A local build
or an audit document is not evidence of publication or installation.
