# Changelog

## 2.8.3 / build 49 — candidate

- Recheck clipboard generation before deferred paste; never restore unrelated
  clipboard data after an unacknowledged layout-correction paste.
- Restore validated records into an app-created database instead of importing
  arbitrary schema/triggers. Reject incompatible backups and invalidate old undo.
- Publish SQLite backups atomically and preserve existing destination-folder permissions.
- Align screenshot crops with the visible preview, synchronize remembered PNG/JPEG
  formats and filenames, and keep committed text at its visible editing anchor.
- Add optional light/dark backgrounds with bounded padding and unchanged source
  pixels. Show export dimensions, disclose reduced large-screen resolution, and
  keep editor controls on two rows at the minimum supported window size.
- Public download remains 2.8.2 until release verification is complete.

## 2.8.2 / build 48 — released 2026-09-19

- Cancel stale history-search actions before local storage work and clear temporary
  result rows after a changed query, close or full history erase.
- Let standalone Option correction use the preceding text token after whitespace,
  preserving surrounding whitespace and punctuation.
- Restrict restore cleanup to app-managed snapshot names and serialize restore
  with full data erasure.
- Add keyboard and VoiceOver controls for screenshot selection and annotations.
- 333 XCTest (5 expected skips, 0 failures), 3 Swift Testing tests and strict Swift 6
  passed. Signed, notarized, stapled app and DMG passed Gatekeeper and mounted-DMG validation.

Exact public artifact: [NeClip-2.8.2.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.2/NeClip-2.8.2.dmg)
(2,124,738 bytes), SHA-256
`84b16e5396ca5dbc3093fe1dbdd2b3e9173e9f77e2600e7e23f63dfd694e916a`.
See [release evidence](docs/RELEASE-2.8.2-STATUS.md).

## 2.8.1 / build 47 — superseded 2026-09-14

- Replace verified word ranges in multiline Accessibility editors while preserving
  surrounding rich text; retry briefly when the editor has not displayed a key yet.
- Recover first strokes during focus refresh, reevaluate after Backspace and
  prevent delayed callbacks from cancelling newer live correction attempts.
- Fix punctuation-position mappings, exact undo, overlapping Option gestures and
  manual/automatic operation overlap. Avoid nested input-source run-loop deadlock.
- 312 XCTest (5 expected skips, 0 failures), 3 Swift Testing tests and strict Swift 6
  passed. Signed, notarized, stapled app and DMG passed Gatekeeper verification.
- Recognition uses local dictionaries starting at four characters. Physical-keyboard
  end-to-end validation remains unconfirmed; synthetic UI events bypass the event tap.

Exact public artifact: [NeClip-2.8.1.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.1/NeClip-2.8.1.dmg)
(2,104,770 bytes), SHA-256
`6dee89524f5349d1b92744f50862162f870ea86fc74060d9944907243246901b`.
See [release evidence](docs/RELEASE-2.8.1-STATUS.md).

## 2.8.0 / build 46 — released 2026-09-14

- Analyze automatic EN/RU layout correction after each eligible key instead of
  waiting for a space; `руддщ` can become `hello` while the user is still typing.
- Keep safe dictionary confidence, protected-field exclusions, sequence checks,
  exact AX compare-and-set replacement and boundary fallback for Space, Tab,
  Return and safe punctuation.
- Make standalone Option correction reliable for the selected text or the last
  word, including active-layout conversion of mixed text and layout-specific
  symbols such as `$`.
- Split settings into logical `Раскладка`, `Приватность`, `Данные` and `Доступы`
  sections instead of mixing them under security.

Exact public artifact: [NeClip-2.8.0.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.0/NeClip-2.8.0.dmg)
(2,096,066 bytes), SHA-256
`d7f869cb90a49d175f681c5d037d2f69ab499a0d44793ee11e54b1060a1d2e51`.
See [release evidence](docs/RELEASE-2.8.0-STATUS.md).

## 2.7.3 / build 45 — released 2026-09-14

- Use the active EN/RU keyboard layout when manual correction receives
  arbitrary selected text, mixed content, digits or symbol-only input.
- Translate layout-specific punctuation and symbols instead of stopping at the
  script-only heuristic used by automatic correction.
- Add regression coverage for symbol-only and mixed manual selections.

Exact public artifact: [NeClip-2.7.3.dmg](https://github.com/AffPapa/neclip/releases/download/v2.7.3/NeClip-2.7.3.dmg)
(2,104,771 bytes), SHA-256
`cf77a7ea28b237d7307b05488ff41ad1c533a74cbd8db7dab99a54c31968a54e`.
See [release evidence](docs/RELEASE-2.7.3-STATUS.md).

## 2.7.2 / build 44 — superseded 2026-09-14

- Move history search out of the top-level menu and into «Ещё из истории»,
  keeping the older history flat and discoverable.
- Preserve an already selected word instead of re-selecting it through
  Accessibility before correction.
- Accept exact replacement verification when an editor keeps pasted text
  selected as well as when it collapses the selection to a caret.
- Add regression coverage for menu placement and selected-layout correction.

Exact public artifact: [NeClip-2.7.2.dmg](https://github.com/AffPapa/neclip/releases/download/v2.7.2/NeClip-2.7.2.dmg)
(2,104,770 bytes), SHA-256
`f83fe7e5d0782b4d1a797c6c8ff1c34333d915642e11093044435180a6ea4343`.
See [release evidence](docs/RELEASE-2.7.2-STATUS.md).

## 2.7.1 / build 43 — superseded 2026-09-13

- Move heavy clipboard representation reads off the main thread and protect
  failed paste writes with a bounded, generation-checked clipboard rollback.
- Make local history search race-safe and Unicode-aware across the full history;
  preserve file paths containing newlines and show safe file previews.
- Invalidate layout caches when the input source changes, harden Option event-tap
  lifecycle, and verify the selected text before Accessibility replacement.
- Keep screenshot editing on the capture display and expose explicit retry/error
  states for history search and menu snapshots.

Exact public artifact: [NeClip-2.7.1.dmg](https://github.com/AffPapa/neclip/releases/download/v2.7.1/NeClip-2.7.1.dmg)
(2,104,771 bytes), SHA-256
`655445405a9ee970b557cc71f9ebde01cd0b881335c1131cf3f92e19646ee23d`.
See [release evidence](docs/RELEASE-2.7.1-STATUS.md).

## 2.7.0 / build 42 — superseded 2026-09-13

- Replace the high-level standalone Option monitor with a passive Quartz event
  tap that recovers after system timeouts without consuming user input.
- Retry and verify input-source switches so successful conversions are not lost
  to notification timing races.
- Prefer direct Accessibility replacement for manual correction, retain a safe
  clipboard fallback, and report separately when text changed but the layout did
  not switch.
- Switch the active layout after selected-text correction and preserve Space,
  Tab, Return and safe terminal punctuation during automatic correction.
- Add competitor research and regression coverage for repeated Option gestures.

Exact public artifact: [NeClip-2.7.0.dmg](https://github.com/AffPapa/neclip/releases/download/v2.7.0/NeClip-2.7.0.dmg)
(2,096,579 bytes), SHA-256
`4485ff2ee56f59f9665fdae81e8a1abff4cb29fcac12d706151260b6b77d23fa`.
See [release evidence](docs/RELEASE-2.7.0-STATUS.md).

## 2.6.3 / build 41 — superseded 2026-09-13

- Add an explicit opt-in standalone Option (Alt) gesture for correcting selected
  text or the last entered word; normal Option combinations remain untouched.
- Add direct menu-bar toggles for standalone Option correction and automatic
  EN/RU correction, with permission and layout-pair checks.
- Keep the Option gesture event-safe: it triggers only on a standalone release,
  never suppresses keyboard or mouse events, and preserves the existing manual
  correction path.

Exact public artifact: [NeClip-2.6.3.dmg](https://github.com/AffPapa/neclip/releases/download/v2.6.3/NeClip-2.6.3.dmg)
(2,093,507 bytes), SHA-256
`c74e620488e109d3679a536c66b830b70b115347b58d4c984116c15ad44e0525`.
See [release evidence](docs/RELEASE-2.6.3-STATUS.md).

## 2.6.2 / build 40 — superseded placeholder 2026-09-13

The immutable GitHub tag was created without binary assets during an interrupted
publication. It is intentionally not a supported download; use 2.6.3 below.

## 2.6.1 / build 39 — superseded 2026-09-13

- Add a separate setting for how many recent history buffers appear in the
  first menu list; enter any value from 10 to 1,000.
- Put every remaining stored buffer under one flat «Ещё из истории» submenu,
  without folder/page grouping and without changing the retention limit.

Exact public artifact: [NeClip-2.6.1.dmg](https://github.com/AffPapa/neclip/releases/download/v2.6.1/NeClip-2.6.1.dmg)
(2,088,898 bytes), SHA-256
`f7dabbc368306ddebe14776866915b69e3931f7208f2fbfbee59db03d29267a3`.
See [release evidence](docs/RELEASE-2.6.1-STATUS.md).

## 2.6.0 / build 38 — released 2026-09-12

- Add one-step history-to-snippet saving with first-line titles, folder choice,
  duplicate detection and raw-text preservation.
- Add explicit original/plain/copy-only paste actions, safe link/file opening and
  bounded local history search with type, application and date filters.
- Add a compact capture status center, pause controls and clear explanations for
  pasteboard, Accessibility and Ignore Next Copy state.
- Close screenshot release debt with safer export-format persistence and keep
  screenshot clipboard content intact; automated redaction remains local.
- Add token palette/preview, bilingual removable starter snippets, and full
  SQLite backup/restore with isolated validation, manifest and rollback backup.
- Add opt-in history-search scaling measurements for 100, 500 and 2,000 rows.

Exact public artifact: [NeClip-2.6.0.dmg](https://github.com/AffPapa/neclip/releases/download/v2.6.0/NeClip-2.6.0.dmg)
(2,087,874 bytes), SHA-256
`8329ff378f6c9a4d5bc5da0efbceebc6ecf48e9f0bac5790439e6d0d77ca0636`.
See [release evidence](docs/RELEASE-2.6.0-STATUS.md).

## 2.5.8 / build 37 — released 2026-09-12

- Remove automatic Apple Vision OCR from clipboard image capture.
- Remove its recognition queue, unused OCR-only APIs and obsolete benchmark paths.
- Preserve original images, existing metadata and SQLite retention accounting.
- Add regressions against recognition calls and for legacy image preservation.

Exact public artifact: [NeClip-2.5.8.dmg](https://github.com/AffPapa/neclip/releases/download/v2.5.8/NeClip-2.5.8.dmg)
(2,044,866 bytes), SHA-256
`05aec85af50286de2b4051041775e48b14d8d33b74a484cb7706531b6ebaec21`.
See [release evidence](docs/RELEASE-2.5.8-STATUS.md).
