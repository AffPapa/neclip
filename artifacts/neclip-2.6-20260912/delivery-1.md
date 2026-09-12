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
- Full debug XCTest: 283 tests, 4 expected skips, 0 failures; three Swift Testing tests passed.
- Strict Swift 6 release build with warnings-as-errors: passed.
- History-search benchmark: 100 rows median/p95 1.48/1.74 ms; 500 rows 7.27/8.49 ms; 2,000 rows 27.85/28.51 ms.
- ASan and TSan builds complete, but Xcode-beta aborts before test execution because sanitizer interceptors load too late; this remains an environment gate, not a passing sanitizer claim.
- Candidate `verify-site.rb`: passed while preserving the verified 2.5.8 public download.

## Partial / blocked

- Physical screenshot permission/display/Save dialog smoke remains required; the UI control service could not attach to the LSUIElement-only smoke bundle.
- Existing personal backup files outside the worktree were observed by an audit with permissive permissions; they were not read or modified. Cleanup needs explicit owner approval.
- The release pipeline requires explicit authorization before sending the app to Apple notarization and using the configured Apple credentials; that authorization has not yet been granted.
