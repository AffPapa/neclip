# NeClip: discovery and refinement

Date: 2026-09-05. Scope: NeClip only, not NeAntik.

## Professional prompts

1. Product researcher: compare official clipboard/snippet and input-source tools; distinguish advertised features from measured behavior, automatic correction from manual conversion. Deliver 100 candidates with evidence, implementation status and priority. Do not import cloud, accounts, scripting or telemetry.
2. macOS engineer: audit menu/search/editor/storage behavior before changing it. Implement a coherent keyboard-first slice; preserve drafts, original clipboard contents, migrations and existing uncommitted snippet-shortcut work.
3. Quality/privacy engineer: verify exclusion policies, shortcuts and settings state; test behavior with synthetic/in-memory data, never real clipboard contents or credentials.

## Plan gate

Read: PROJECT-MAP, BACKLOG, prior 1.6.0 research, live source/diff. Three independent read-only tracks returned findings before implementation. Xcode-beta/Swift 6.4 now available. Native update_plan tool unavailable; this file records the plan instead.

## Selected implementation scope (maximum 30 improvements)

P0/P1 correctness first:

- Stable Settings/Quit footer during all search states.
- Literal snippet-only queries, with truthful search help.
- Invalidate old keyboard results immediately while a new search loads.
- Replace conflicting search filters rather than accumulate them.
- Refresh clean snippet drafts after external edits, preserve dirty drafts.
- Correct folder deletion count under search.
- Rank exact snippet keywords before limiting results.
- Update quick-snippet snapshot after use.
- Case-insensitive protected layout contexts and helper exclusions.
- Live settings state and discoverable numeric-input validation.

P1 convenience within existing surfaces:

- Folder-first dedicated snippet shortcut and right-click access.
- Stable folder ordering, count/context labels.
- Edit the first found snippet directly with Command-E.
- Duplicate and undo snippet deletion in the editor.
- Visible clear-search, editor keyboard shortcuts, folder-title search.
- Individual hotkey reset and truthful paste-modifier help.
- Bounded local snippet rendering and useful deterministic text transforms.

## Execution

1. Discovery + independent audits: completed; provenance reconciliation continues.
2. Implementation of selected fixes: completed; final review also fixed deferred paste destination capture and bounded-preview scanning, removed two unused aliases.
3. Synthesis: completed; exactly 100 recommendations, 27 selected, existing/deferred/rejected distinguished.
4. Local delivery gate: completed; full suite (177 passed/1 opt-in skip), strict release, AddressSanitizer, ThreadSanitizer, secret scan, diff/plist/JSON validation and sampled isolated UI QA passed.
5. Handoff: completed; project map/backlog/source metadata updated, local/source/public/installed states distinguished. Public binary release and all-target-app UI certification are not claimed.

## Boundaries and stop rules

Do not alter installed NeClip, user clipboard database, signing credentials, unrelated projects, or public download manifest. Publishing a binary requires the exact signing/notarization/release gate. No destructive history rewrite without evidence and a recovery plan. Stop on genuinely missing authority or external release prerequisites; finish unaffected local work. Do not add features to reach a count if they compromise minimalism.
