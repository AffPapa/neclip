# Fresh-pass delivery — 6 September 2026

## Status and scope

Local, tested source on `codex/neclip-fresh-pass`, based on public 1.9.1/build16
(`0bd5d8fdedebfc449867f63fe077d7200b7f843a`). This is not a published release.
Installed `/Applications/NeClip.app`, public GitHub release, update feeds and
website were not replaced. No dependencies, database migrations or new permissions.

Three independent read-only audits preceded changes; two independent follow-up
reviews examined the storage boundaries and found no blockers in the final diff.
Looper shaped the bounded audit → fix → regression → visual review sequence.

## Delivered

1. Full erasure invalidates deletion undo. A per-Storage UUID rotates only after
   a successful erase commit while still owning the serialized database queue.
   Both clip/snippet restoration validate it inside the write transaction;
   late menu success/error completions cannot republish stale undo tokens.
2. History-to-snippet conversion reads metadata/text and inserts in one write
   transaction. Erasure cannot interleave after a read and resurrect its content.
   Shared insertion preserves folder, keyword, content validation and order.
3. OCR paste projects only title, OCR text and creation date, without materializing
   image/RTF representations in Swift. Full OCR text is preserved, not preview-truncated.
4. Successful append avoids constructing/hashing a standalone text item. Both
   fallbacks still use one ordinary insertion path after existing privacy preflight.
5. Snippet save status is static; actions say Save/Retry. Failure details remain
   visible across list refresh. Long secondary labels stay one line; full context
   remains available to help/accessibility.
6. Settings distinguish history count and retention and explain protected items.
   Inspector feedback gets its own full-width row above the action buttons.

## Tests and integrity

- Baseline: 241 successful checks, 2 optional skips.
- Red reproduction: queued undo restored erased clip and snippet; 2 tests failed
  with 4 assertions before the generation fix.
- Final debug, strict release (`complete` concurrency, warnings-as-errors),
  ASan and TSan: each 251 XCTest cases (2 skipped, 0 failed) + 11 Swift Testing
  checks = **260 successful checks and 2 optional skips**.
- Added 19 regression tests, including failed erasure rollback, cross-instance
  tokens, both conversion/erase orders, Unicode bounds, OCR projections and retry.
- Ordinary debug rebuild after sanitizers passed.
- Two old source-wiring assertions were updated to the new history label and
  atomic storage method; behavioral validation was not removed.
- Gitleaks detector canaries, publishable tree, 49 baseline HEAD commits and
  2 side-ref-only commits passed with values fully redacted. The final local
  commit is scanned again before handoff. No remote publication/history rewrite.
- `git diff --check` passed. Existing recovery files and production data untouched.

Private command logs: `.qa/fresh-pass/neclip-fresh-*.log`.

## Measured performance, not a general speed claim

Opt-in synthetic release benchmark, same database, 20 calls per query; setup is
excluded. This measures the fetch path, not end-to-end paste or whole-app latency.

| Image payload | Full fetch median / p95 | OCR projection median / p95 |
| --- | --- | --- |
| 1 MiB | 0.150 / 0.375 ms | 0.027 / 0.070 ms |
| 10 MiB | 1.358 / 1.524 ms | 1.373 / 1.512 ms |

The 1 MiB fixture improved; the 10 MiB fixture did not show a meaningful latency
improvement. The reliable benefit is avoiding image/RTF materialization in Swift;
SQLite may still traverse overflow pages to reach later columns. No schema change
was introduced just to improve a benchmark. No percentage reduction of the whole
app or line-count target is claimed; regression protection adds code/tests.

## Native visual QA and limits

An isolated, separately identified debug app used its own database, with capture
paused and automatic correction disabled. Existing application/data were untouched.

Observed at 640×420 in dark appearance:

- Existing row selection opens editable fields.
- A long keyword stays on one line with ellipsis; AX retains its full value.
- Saved status is no longer a button.
- A duplicate key produces a readable separate error and Retry action; retry and
  a corrected key return to Saved without losing the text.

Observed Settings at 600×554: new Limit/Retention labels, protected-record
explanation, existing five-category native toolbar and visible Close button.
Concurrent user keyboard/navigation input occurred during the later Settings
inspection, so closing/navigation results from that portion are not counted.
Inspector footer was independently reviewed in code and covered by existing
model save/error tests; a fresh light-mode/error screenshot was not obtained in
this pass. Cmd-S remains on dirty/failed actions; saved-state acoustic behavior
was not verified. No exhaustive all-buttons/all-macOS/all-apps claim.

The native QA launcher was changed locally to LaunchServices after tool-managed
direct child launches ended and were reopened without their launch environment.
No production runtime behavior was changed to accommodate the testing tool.

## Deliberately deferred

- Domain-selective snapshot refresh and fuzzy-search allocation rewrite need
  separate measurement and cancellation tests.
- A dirty snippet concurrently deleted elsewhere needs explicit discard/recovery UX;
  an external pin/folder change while dirty needs a field-level merge policy.
- Wider cosmetic redesign and new features are not needed for this bounded pass.

Primary design references: [Apple menus](https://developer.apple.com/design/human-interface-guidelines/menus),
[disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls)
and [native Settings](https://developer.apple.com/documentation/foundation/adding-a-settings-interface-to-your-app).
Recommendations informed the native-control approach; they are not proof of QA.
