# Delivery 1 — local data and retrieval core

## Evidence

- `Storage.saveClipAsSnippetResult` now supports folder selection, exact same-folder duplicate reuse, first non-empty line titles, sensitive-content/source rejection, and body preservation without template rendering.
- History rows expose explicit paste/copy/open/save actions; `Command-F` opens a dedicated search panel with local text search and type/app/date filters.
- Token catalog, preview-only rendering, 10 bilingual starter snippets, private SQLite backup snapshots, validation and staged restore are implemented.
- Screenshot save remembers the last successful PNG/JPEG format and exposes an accessibility label.
- Clipboard processing rechecks pause at the storage boundary.

## Tests

- Targeted `ClipToSnippetTests`: 7 passed.
- Targeted `HistorySearchTests`: 2 passed.
- Targeted `StorageBackupTests`: 3 passed.
- Full debug XCTest after these slices: 280 tests, 0 failures, 4 expected skips before the final starter-pack expectation was updated; the updated targeted storage suite is green.
- Strict release build: passed.

## Partial / blocked

- Full release version metadata is still 2.5.8 and must not be changed until the remaining QA gates pass.
- Physical screenshot permission/display/Save dialog smoke remains required.
- Existing personal backup files outside the worktree were observed by an audit with permissive permissions; they were not read or modified. Do not publish until that release blocker is resolved with explicit owner approval.
- Git branch creation was blocked because the linked Git metadata lives outside the writable workspace.
