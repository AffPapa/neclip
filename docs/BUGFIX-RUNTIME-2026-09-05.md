# Runtime follow-up: close, capture, shortcuts

Date: 2026-09-05. Source candidate remains 1.8.0 / build 14.
This is not a published or notarized release.

## Task and responsibilities

Prompt: establish the cause of settings not closing, empty capture history and
Command-Shift-V feedback; make minimal corrections, preserve user data, and
test both the code and the running application. Three independent audit tracks
covered AppKit windows, capture state, and Carbon shortcut routing before edits.

## Evidence and corrections

- The only running NeClip was the prior isolated QA copy, launched with
  `-capturePausedIndefinitely YES`. UserDefaults command-line overrides take
  priority over persistent preferences. Removing the persistent pause could
  not resume capture. This was a test-runner mistake, not a damaged database.
- Capture resume now checks its effective result and explains launch-locked
  pause. An empty paused history no longer instructs the user to keep copying.
- The red settings close button worked during inspection. The app did not
  expose the standard Command-W command. Added native responder-chain
  `performClose`, a visible Close button and focus-aware Escape handling.
  Editor unsaved-draft close veto remains in force.
- Added application-menu history and snippet-folder commands, refreshed when
  shortcuts change. Own Carbon events now return `noErr` before dispatching
  menu actions asynchronously; unrelated events remain unhandled. Exclusive
  registration makes shortcut conflicts explicit instead of allowing sharing.
- Debug preview identity is visible in window titles and history. A debug-only
  bundle fallback preserves the isolated database path when Finder relaunches
  the app without its original environment. Release ignores this override.

## Runtime repair and verification

- Normally quit the old QA process. Backed up its app and SQLite database;
  preserved a second recovery database outside both Git and temporary storage.
- Rebuilt and ad-hoc signed only the same isolated QA bundle. Restarted with
  its original data and without forced capture pause. Automatic correction and
  per-application layout memory remained disabled for this QA run.
- Settings reported capture and paste permissions already allowed, and
  `История записывается`; no security setting was changed by this repair.
- Command-Shift-V from settings opened the history menu. Command-W removed
  the settings window; the app remained running with an idle main event loop.
  The native UI driver timed out with no regular window left, so that timeout
  is not reported as evidence of an application hang.
- Copied a known synthetic marker from a newly created TextEdit document;
  a read-only exact-match query found it in the QA history. All seven snippets
  remained present. Discarded only the synthetic TextEdit document afterward.
- Full suite: 175 XCTest cases, one opt-in skip, zero failures, plus 11 Swift
  Testing cases passed: **185 passed, 1 skipped**. Eight new regression cases
  cover native commands/focus handling, launch overrides and Carbon dispatch.
- Strict release build with complete concurrency and warnings-as-errors passed
  after the final code changes. `git diff --check` passed.

## Explicit verification limits

The UI tool does not reliably exercise physical global key delivery after all
NeClip windows close, and it does not verify audible output. Local command
opening and Carbon dispatch tests passed; absence of sound across arbitrary
external apps is not claimed. The exact original sound source is unproven.

The installed `/Applications/NeClip.app`, GitHub and public 1.4.0 download were
not replaced by an unsigned debug candidate. The repaired running copy is
explicitly labeled NeClip Preview and uses its own history. Do not delete its
data or recovery backup when preparing the signed release.
