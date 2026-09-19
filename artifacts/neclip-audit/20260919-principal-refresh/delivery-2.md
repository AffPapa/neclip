# Delivery 2 — confirmed P1 hardening

## Accepted fixes

- Search invalidates visible rows and action targets as soon as a query changes,
  so Return, buttons and double-click cannot act on a previous result during the
  debounce window. Closing and full erasure also invalidate queued replies.
- When the application selected in the search filter disappears, the filter
  truthfully returns to “All applications” and the list is reloaded with that
  filter.
- Manual layout correction now identifies the prior token after spaces, tabs or
  newlines, converts only that token, and retains trailing whitespace in the
  replacement/undo range. Source-aware conversion keeps symbol-only cases.
- Full data erasure removes only NeClip-managed restore snapshots with a strict
  UUID filename, no recursive traversal and no symlink following. A partial
  cleanup is reported after the database erasure and view invalidation.
- Screenshot selection and markup have usable keyboard and VoiceOver flows:
  arrows move, Shift resizes, Option changes the step, Return confirms and
  Escape cancels. A new keyboard/VoiceOver mark commits an active text draft
  first.

## Evidence

- Strict Swift 6 full suite: 333 XCTest, 5 documented opt-in skips, 0 failures.
- Targeted search/layout/screenshot/backup suite: 76 tests, 0 failures.
- Hot-path measurements: history search median/p95 ms — 100: 0.598/0.638;
  500: 2.811/2.904; 2,000: 11.251/11.471. Menu full median/p95: 1.186/1.245.
- Site tests: 8 runs, 21 assertions, 0 failures; source 2.8.2 and public 2.8.1
  correctly remain distinct until publication.
- Secret scan: publishable tree, 221 HEAD commits and 21 side-ref-only commits
  clean.

## Release effect

The already notarized local candidate is based on an earlier source commit and
must not be published. Rebuild, notarize and verify a new 2.8.2 candidate from
the exact final protected-merge commit, then update the release automation to
that commit and its checks.
