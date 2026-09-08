# Focus Stack — 1.14.0

## Product decision

NeClip is an immediate-use menu, not a library browser. The first menu section
is therefore allowed to appear only when the current app already provides
enough context. It is labelled **В работе** and contains at most five items:

- recent clips copied from the current frontmost app;
- snippets that the user has already used, ordered by last use and frequency.

The ordinary chronological history and direct snippet folders remain the
fallback. Focus items are removed from the repeated history page, so the menu
never shows the same clip twice.

## Guardrails

- No search, tags, pin UI, account, sync, telemetry or AI.
- No new macOS permission: only the existing frontmost-app identifier and
  stored metadata are read.
- One item is not enough to create a new visual group; the regular menu stays
  unchanged until at least two contextual items exist.
- Ranking is deterministic and local. A fresh install has no Focus Stack.
- `⌘1`–`⌘5` select the visible working set. History keeps its existing number
  shortcuts when the contextual section is absent.
- The current app is captured when the menu opens; storage reads stay on the
  existing background queue and use bounded projections.

## Implementation

`Sources/NeClip/FocusStack.swift` is a pure ranking function. `Storage` exposes
the existing snippet usage fields through `SnippetSummary`; no migration or
new persisted state was introduced. `StatusBarController` builds one shared
snapshot and renders the focus rows before the chronological history.

## Verification

`FocusStackTests` cover case-insensitive app matching, used-versus-unused
snippets, the minimum-context rule and the no-current-app fallback. The full
Swift 6 test suite remains the release gate.
