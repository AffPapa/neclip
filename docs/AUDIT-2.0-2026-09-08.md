# NeClip 2.0 audit — evidence and decisions

Date: 8 September 2026. Branch: `codex/neclip-2.0-rethink`.

## Evidence first

- Public source baseline: NeClip 1.14.0/build 21, merge commit
  `dd7c5296b6149eea3ae39dce8e0fa3524d6b66ba`.
- Runtime Swift: 10,351 physical lines; 9,384 nonblank/non-comment lines.
- Test Swift: 5,193 physical lines.
- Baseline suite: 250 XCTest, 4 expected skips, 0 failures; 3 Swift Testing
  checks passed on the Xcode beta toolchain.
- Candidate P0 slice: 250 XCTest, 4 expected skips, 0 failures; the focused
  PreferencesNavigation suite is green after the Settings redesign.
- Release artefact remains independently signed/notarized; this audit does not
  mutate the installed 1.14.0 app or its production database.
- Static source audit found no live menu search UI, but legacy storage
  compatibility still contains keyword/FTS and pin fields by design. Those are
  migration contracts, not proof of a visible feature.

## Three read-only audit tracks

### Product/UX

The strongest workflow is already “open → choose → Return”. The current weak
point is naming and hierarchy: Focus Stack, history and snippets are three
different concepts to learn, while Settings exposes six peer categories for a
menu-bar utility. The proposed three-zone menu and three-question Settings
model reduce the number of concepts without deleting safety controls.

### Architecture/performance

The current code is bounded and careful on the hot path: menu projections use
metadata, Storage has OCR/usage fast paths, queued work is cancellable, and
privacy checks precede persistence. The safe reduction opportunity is not a
blind line-count cut; it is consolidating duplicated presentation state and
moving retired behavior behind compatibility boundaries. Migrations, tests,
pasteboard restoration, capture barriers and hotkey rollback must remain.

### Release/security

The release path is now proven for 1.14.0: strict build, signing,
notarization/stapling, mounted-DMG Gatekeeper, public checksum and gitleaks.
2.0 must retain this gate and add visual parity for status-item/hotkey paths,
light/dark mode and Settings close behavior. GitHub Pages metadata must be
updated only through a protected, check-backed merge.

## Remove / keep / redesign

### Remove from the visible product

- Version as a Settings toolbar peer; show identity in About.
- Any retired pin, history inspection, search or keyword affordance.
- Separate “Data” and “Layout” toolbar peers when their controls are not
  active; keep their safety actions behind the relevant question/disclosure.
- Explanatory prose that repeats the same permission or retention fact.

### Keep unchanged internally

- Database migrations and legacy columns required to open upgraded databases.
- Concealed/unknown-source/password-manager protection.
- Capture barriers and full-erasure invalidation.
- Pasteboard snapshot restoration, hotkey conflict rollback and tests.
- Bounded projections and no-network/no-telemetry defaults.

### Redesign

- Menu: **В работе → Недавнее → Сохранённое**.
- Settings: **Как работает → Клавиши → Безопасность и приватность**.
- Snippet editor: title, text and folder first; all other fields are gone or
  compatibility-only.
- Retention: one user-facing “keep recent copies” control with presets; age,
  clear-on-quit and byte limits are Advanced.
- Layout correction: one opt-in switch in Safety; only then show permissions,
  app exclusions and memory.

## Acceptance rubric for implementation

1. A new user can paste a recent item with one shortcut and Return.
2. A saved snippet is reachable without search, tags or a second library.
3. No visible setting uses an internal term such as FTS, keyword, bundle ID or
   pinned state.
4. Settings has at most three peer destinations and each answers one question.
5. All existing data opens; no migration deletes user payloads.
6. Menu construction remains bounded and does not load large blobs for labels.
7. Light/dark appearance and menu-bar/hotkey presentation are identical.
8. The binary and cold/hot latency are measured before and after each slice.
9. Full release/security gates remain green.

## Decision

Implement P0 as a separate candidate branch, with no public release or
database migration until the rubric is green. The detailed candidate matrix
and product boundary are in `NECLIP-2.0-VISION-2026-09-08.md`.

## Candidate implementation note

The candidate now exposes only **Основные**, **Клавиши** and **Безопасность** in
the Preferences toolbar. Privacy, layout and data controls are grouped into the
Safety screen with disclosures; their old enum cases remain addressable for
compatibility and QA. History uses 50/100/250/500 presets, while the exact
numeric limit remains available under additional settings. No database schema,
payload, permission policy or release artifact was changed.
