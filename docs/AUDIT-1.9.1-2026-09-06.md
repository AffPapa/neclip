# NeClip 1.9.1 — native settings and safer editing

Status: public release 1.9.1, build 16. The exact signed artifact and independent
download evidence are recorded in `RELEASE-1.9.1-STATUS.md`.

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

## Local verification and scope

- Full normal and strict Swift 6 complete-concurrency/warnings-as-errors
  suites: 232 XCTest cases, 2 optional skips, 0 failures; 11 Swift Testing checks
  passed (241 successful checks total).
- Swift 6.3.3 CI exposed an IRGen compiler crash when a Binding setter used a
  direct method reference. An explicit setter closure preserves behavior and
  fixes the crash. Repeat strict build/tests passed in
  [CI run 34019002501](https://github.com/AffPapa/neclip/actions/runs/34019002501).
- The first local source `f6c4a9f663b33eee741fce49a83c93f78c988bf2` was
  superseded before publication. The final artifact source is
  `ab1f98039f70a33b92b48ff9a1be15ad3f9f8282`.
- Final-source normal, strict, ASan and TSan suites each completed with
  232 XCTest cases, 2 optional skips, 0 failures and 11 Swift Testing checks:
  241 successful checks per suite, with no sanitizer error.
- Isolated Settings: all five categories rendered at 600 px width; native toolbar
  and Close remained visible (actual constrained height 554 px). All five shortcut
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
- Gitleaks canaries, publishable tree, 46 HEAD commits and 1 side-ref-only commit
  passed for the source scan. The final fetched-ref scan remains a separate
  publication check.

## Local cleanup

An exact allowlisted cleanup removed four unused generated caches (2.17GB
allocated) and sent20 obsolete installer/test artifacts (50.5MB) to native
Trash. An independent pass verified every source target absent and every Trash
destination present, with exact SHA256 matches for all19 regular files.
The twentieth item is a retired application directory. Trash was not emptied.
APFS physical free-space increase is not claimed from allocated-size measurements.

Seven more stopped QA application bundles were moved to Trash in a separate
allowlisted pass. Independent verification confirmed their source paths absent,
Trash destinations present and content hashes unchanged. This is in addition
to the 20 artifacts and four caches above, not a claim that final distribution
cleanup or installation has finished. Trash was not emptied.

Source Git ownership, active build files, all user databases/preferences and a
separately restored/signed/notarized rollback were retained. Production database
integrity and foreign keys passed;11 snippets,2 folders and100 history records
were present. Private paths and data are not part of public release metadata.

## Publication and installation evidence

Artifact source: `ab1f98039f70a33b92b48ff9a1be15ad3f9f8282`.
The public release record separates signing, protected CI and independent
download verification from local tests. Installation, data preservation,
rollback and final cleanup need their own observed results; a published DMG
or this audit alone does not prove them. See `RELEASE-1.9.1-STATUS.md`.
