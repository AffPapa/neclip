# NeClip fresh-pass optimization

Baseline: public 1.9.1/build16, clean source `0bd5d8fdedebfc449867f63fe077d7200b7f843a`.

## Professional prompts and independent goals

1. Apple UX designer: audit menu, Settings and editors from a new user's perspective; minimize ambiguous actions and layout pressure without adding features.
2. Swift performance engineer: find avoidable payload loads, allocations and computations; preserve privacy checks and prove behavior with tests.
3. QA engineer: audit lifecycle, commands and persistence independently; reproduce races with deterministic regression tests before accepting fixes.

All three read-only audits completed before source changes. Root owns integration,
baseline/final builds, isolated native UI review and evidence synthesis.

## Selected delivery (bounded)

- P0: full-data erase must invalidate pending history-deletion undo in both UI and storage transactions.
- P0: history-to-snippet conversion must read and insert atomically across full erasure (found by independent post-change review).
- P1: OCR paste fetches only text metadata, not image/RTF payloads.
- P1: append-next creates/hashes a standalone text item only when a fallback needs it.
- P1: snippet save status distinguishes state from action; long subtitles stay one line with full accessible context.
- P1: clarify count/age limits and keep inspector feedback out of its button row.

Deferred: broad snapshot invalidation redesign, fuzzy-search rewrite and extra
features. These increase risk and need independent measurement/slices.

## Verification and stop rule

- Baseline full tests, then targeted regressions and full debug/strict release tests.
- ASan/TSan for storage/async changes; secret scan and diff/format checks.
- Native isolated QA with separate bundle ID/database, capture paused, no new permissions.
- Judge minimum-width editor, save state, Settings labels and inspector feedback.
- Keep installed 1.9.1, production data, recovery ZIP, release feeds and public site unchanged in this local implementation pass.
- Finish when the bounded changes pass gates and their exact evidence/limitations are recorded; do not equate local code with a published release.

## Protected boundaries

No account/cloud/telemetry/dependency/migration additions. No security weakening,
user database reads of content, old-version cleanup, signing credential access,
Git history rewrites or deletion of tests/safeguards to meet a line-count target.

## Primary design references

- https://developer.apple.com/design/human-interface-guidelines/menus
- https://developer.apple.com/design/human-interface-guidelines/disclosure-controls
- https://developer.apple.com/documentation/foundation/adding-a-settings-interface-to-your-app

Use clear action labels and progressive disclosure within existing native controls.
