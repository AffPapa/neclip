# NeClip 3.0.2 simplification audit

Scope: clipboard history and snippets, settings, local storage and paste.
Three independent read-only reviews covered native UX/accessibility,
Swift/SQLite performance and correctness/privacy. The parent implemented and
verified the selected changes. No new feature subsystem or dependency.

## Findings and changes

- Five settings destinations became three: General, Privacy and Data. Shortcuts
  and menu appearance use expandable groups with clickable labels. Active
  history/snippet shortcuts remain visible. One exact history-limit editor
  replaces two controls; custom values and every retained preference survive.
- Privacy includes macOS permission recovery, pause, exclusions and phrase
  rules. Automatic cleanup remains visible in the collapsed group label.
  Phrase editing has an explicit accessibility label.
- Opening ordinary Settings after About returns to the last visible section.
  Legacy shortcut/access entry points resolve to the new destinations; repeated
  shortcut navigation opens its group. One transactional reset replaces three
  individual reset buttons and still recovers swapped shortcut assignments.
- Restoring a backup now names the selected file and explains that history and
  snippets are replaced, while settings remain. Cancel occurs before the data
  operation. The existing automatic rollback snapshot remains intact.
- Plain-text file paste previously wrote internal JSON and still advertised
  file objects. A named-pasteboard regression reproduced this. It now writes
  decoded paths as text only; ordinary file paste retains file objects.
  Tests cover JSON and legacy records, multiple paths, Unicode/newlines and
  restoring the previous clipboard when an empty file record cannot be written.
- History trimming no longer calculates an unused size aggregate. The size
  calculation after count-based deletion remains, preserving quota correctness.
  Search retains native application-menu items when its app list is unchanged.
  Two uncalled storage helpers were removed.

## Measurement

Actual `Storage.trimToLimits()` on warmed in-memory synthetic databases,
100 iterations per size, arm64 macOS 27, Apple Swift 6.4.0.27.1, optimized release.
Fixture creation and insertion are outside timing; history limit 1,000,
retention disabled, no records deleted during the measured loop.

| Rows | Before p50, ms | After p50, ms | Before p95, ms | After p95, ms |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 0.040625 | 0.029333 | 0.152584 | 0.034542 |
| 500 | 0.089083 | 0.060750 | 0.214541 | 0.211875 |
| 1,000 | 0.155917 | 0.102042 | 0.585625 | 0.253500 |

This isolates a small storage operation, not total capture, search, startup or
UI latency. Menu-item reuse is verified by object identity and selected-item
regressions, without claiming a measured overall search speedup. Package size
must be compared on the final signed archives, not inferred from source lines.

## Verification and boundaries

Strict debug, optimized release, ASan and TSan: 291 XCTest, 10 expected opt-in skips, zero failures,
plus four Swift Testing checks. The benchmark-enabled optimized run
passed all 291 XCTest with one unrelated opt-in skip.

Native isolated preview checked three sections, a persisted custom limit of
350, Escape cancelling numeric input, About-to-Settings return, disclosure
label clicks, backup warning and cancellation, and scrollable 600×500 layout.
Only synthetic data was used; clipboard capture remained locked off. Site and
SEO tests passed (14/45 and 18/52 tests/assertions); source/history secret scan
passed. No screenshot capture, input monitoring or layout-switching APIs remain;
the selective fourteen-key retirement migration and database schema are unchanged.

Physical automatic paste across every third-party app, all supported macOS
versions and VoiceOver speech are not certified. Accessibility remains optional
for copying and required for automatic paste. Release, public-byte and installed
data-preservation evidence are verified separately after the protected PR.

[Проект Иванова](https://affpapa.org/).
