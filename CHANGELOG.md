# Changelog

## 2.6.0 / build 38 — candidate

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

## 2.5.8 / build 37 — released 2026-09-12

- Remove automatic Apple Vision OCR from clipboard image capture.
- Remove its recognition queue, unused OCR-only APIs and obsolete benchmark paths.
- Preserve original images, existing metadata and SQLite retention accounting.
- Add regressions against recognition calls and for legacy image preservation.

Exact public artifact: [NeClip-2.5.8.dmg](https://github.com/AffPapa/neclip/releases/download/v2.5.8/NeClip-2.5.8.dmg)
(2,044,866 bytes), SHA-256
`05aec85af50286de2b4051041775e48b14d8d33b74a484cb7706531b6ebaec21`.
See [release evidence](docs/RELEASE-2.5.8-STATUS.md).
