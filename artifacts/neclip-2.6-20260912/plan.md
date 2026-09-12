# Implementation plan

## Slice 1 — history actions and save-as-snippet

- Extend storage API with explicit folder selection, first-nonempty-line title derivation,
  exact duplicate lookup by folder and content, and a result describing created/existing.
- Add context submenu to text history entries: paste original, paste plain, copy only,
  open validated http/https URL, save as snippet.
- Add tests for text-only behavior, folder choice, duplicates, token preservation and URL safety.

## Slice 2 — local search

- Add a bounded in-memory query model over text summaries/metadata, not OCR or network data.
- Keep history menu chronological when query is empty; add type/app/date filters in popup.
- Add 100/500/2000 benchmark fixtures and performance regression budget against 2.5.8.

## Slice 3 — trust center and snippet UX

- Consolidate capture, pasteboard, Accessibility, pause and ignore-next-copy states.
- Add token palette/preview and 10–20 opt-in RU/EN starter snippets without personal data.
- Add explicit backup/export/restore commands with atomic validation and recovery tests.

## Slice 4 — screenshot and release

- Add only privacy-focused redaction polish and last-successful save format persistence if
  the existing editor model supports it without hidden source pixels.
- Run physical screenshot/permission/display matrix, then full release ladder and live checks.
