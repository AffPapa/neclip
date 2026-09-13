# Changelog

## 2.6.3 / build 41 — released 2026-09-13

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
