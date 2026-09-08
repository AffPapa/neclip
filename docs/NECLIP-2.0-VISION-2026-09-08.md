# NeClip 2.0 — Zero-friction clipboard

Status: product specification and audit baseline, 8 September 2026. This
document is a design gate; it is not a claim that the 2.0 changes are shipped.

## One-sentence product

NeClip is the invisible local memory of the Mac: press one shortcut, choose
what you need now, press Return, and keep working. Everything else stays
quiet until it is genuinely needed.

## What the audit found

The current public 1.14.0 experience is already local, menu-bar-only and
search-free, but the source still carries compatibility and preference weight:

- 10,351 physical runtime Swift lines and 9,384 nonblank/non-comment lines;
  the test suite is 5,193 physical lines. A cosmetic 30% deletion target would
  be unsafe without a measured replacement.
- The visible Settings surface has six toolbar sections: General, Shortcuts,
  Privacy, Layout, Data and Version. General, Privacy and Layout each contain
  nested controls with overlapping retention, permission and exclusion concepts.
- Storage still has legacy `pinnedAt`, `isPinned`, keyword and FTS migration
  code for upgrade compatibility. These must not be deleted without a tested
  forward migration and rollback boundary.
- The menu previously had a separate Focus Stack projection. Testing the
  concept showed that a second “latest” list makes a clipboard manager less
  predictable: the same item can appear twice and the user has to learn a new
  ranking rule. The 2.0 candidate removes that projection completely.
- Automatic EN/RU correction remains a high-risk opt-in subsystem because it
  can require Input Monitoring. It should be invisible by default and exposed
  as one safety option, not a peer of ordinary clipboard settings.

## The 2.0 mental model

The menu has exactly two visual zones, in this order:

1. **Недавнее** — the bounded chronological clipboard history. A row always
   means “paste this”; no inspector, pin state or hidden click mode.
2. **Сохранённое** — snippet folders shown directly in the same menu. A folder
   opens one level; a snippet pastes immediately. No search field, keyword,
   tags, smart collections or duplicate quick list.

 The footer contains only four low-frequency actions: Pause capture, Edit
 snippets, Settings and Quit. Destructive data actions live in Settings, never
 in the primary selection path.

## Settings 2.0

Replace six peer tabs with three user questions:

### How it works

- Keep recent copies: one control with presets `50 / 100 / 250 / 500` and one
  optional “clear on quit” switch. Age-based cleanup is an Advanced disclosure.
- Save images: on/off.
- Paste as plain text: on/off.
- Launch at login: on/off.

### Shortcuts

- Open NeClip (history + context): one shortcut.
- Open saved snippets directly: one shortcut.
- Paste next: one shortcut, disclosed as Advanced.
- Correct layout: one shortcut, shown only when layout correction is enabled.

### Safety & privacy

- Capture enabled / pause for 15 minutes / pause until resumed.
- Protected apps are always visible and cannot be removed.
- Add an app to “Never capture”.
- Optional conservative EN/RU correction. Input Monitoring and Accessibility
  status appear inline only after opting in.
- Export/import saved snippets and erase local data at the bottom.

Version and update status move to the standard About window. There is no
separate Version toolbar tab. This follows the macOS convention of a Settings
scene for preferences and About for identity/release information.

## The novel part: chronological certainty, not an archive

Most clipboard managers optimise for searching a large archive. NeClip 2.0
optimises for the next action being obvious. The rule is fully local and
explainable:

`latest copy first + saved folders always visible`.

No embeddings, AI, cloud, tags, app profiling or second ranking are needed. A
fresh install shows only the chronological history and saved folders.

## 100 candidate improvements

### Immediate-use menu (1–20)

1. Remove the duplicate “latest/context” projection. 2. Keep one shared
snapshot per open. 3. Make Return always paste. 4. Make Command-Return copy
only. 5. Make Option-Return plain-text paste. 6. Keep visible numbers only
for the first ten rows. 7. Preserve physical-key navigation in EN/RU layouts.
8. Keep folders one submenu deep. 9. Put saved folders directly in the root
menu. 10. Remove empty visual groups. 11. Show type icons consistently. 12.
Bound row previews by grapheme-safe length. 13. Keep link/file/image labels
readable. 14. Reuse one menu snapshot for status-item and hotkey paths. 15.
Refresh only the changed domain. 16. Retry a failed read on explicit open.
17. Keep folder order stable. 18. Give the first ten history rows physical
number shortcuts. 19. Keep the menu free of network work. 20. Keep the menu
usable while settings are open.

### Snippets (21–35)

21. Rename “Сниппеты” to “Сохранённое” in the primary menu. 22. Keep folders
as the only grouping concept. 23. Remove keyword storage from new exports.
24. Keep legacy keyword import inert. 25. New snippet form has title, text and
folder only. 26. Select title on creation. 27. Save on focus loss and close.
28. Keep failed drafts visible for retry. 29. Create from the current clip in
one action. 30. Add a one-click “Редактировать сниппеты” footer entry. 31. Show
folder counts only when nonzero. 32. Keep folder creation inline. 33. Rename
folder from its own ellipsis menu. 34. Delete folder with explicit move-to-
unfiled confirmation. 35. Keep placeholder help to `{date}`, `{time}` and
`{clipboard}` until a real need appears.

### Settings (36–55)

36. Collapse six tabs into three questions. 37. Move version to About. 38.
Unify history count and cleanup wording. 39. Use presets before free numeric
input. 40. Keep rare controls behind Advanced. 41. Show active cleanup state.
42. Hide layout memory until enabled. 43. Hide Input Monitoring until the
  user enables auto-correction. 44. Keep protected password apps immutable.
45. Show app names, not bundle IDs, by default. 46. Add “why” text next to
permission buttons. 47. Keep one capture pause control. 48. Keep data erasure
at the bottom. 49. Preserve existing defaults on upgrade. 50. Persist drafts
only after valid completion. 51. Make Escape cancel edits. 52. Keep Close and
Command-W equivalent. 53. Keep keyboard focus order deterministic. 54. Make
every destructive action explicit. 55. Remove controls for retired search,
pinning and hidden inspection.

### Safety and privacy (56–70)

56. Reject concealed pasteboard items before persistence. 57. Keep protected
password managers case-insensitive. 58. Keep unknown-source copies fail closed.
59. Keep oversized text rejection before normalization. 60. Keep empty-rule
fast path. 61. Keep lossless pasteboard restoration. 62. Keep capture barrier
for bulk deletion. 63. Keep full-erasure generation invalidation. 64. Keep
atomic import bounds. 65. Keep no network by default. 66. Keep no telemetry.
67. Make pause state visible in the menu. 68. Make auto-layout correction
off by default. 69. Add a one-shot “не сохранять следующее копирование”. 70.
Keep all safety rules local and inspectable.

### Performance and code health (71–85)

71. One menu snapshot model. 72. One projection path for context/history.
73. Metadata-only OCR updates. 74. Metadata-only usage updates. 75. Bound
database projections. 76. Avoid loading image/RTF blobs for labels. 77. Cancel
obsolete menu work. 78. Avoid duplicate sorting. 79. Cache stable folder order.
80. Measure release-mode menu latency. 81. Measure cold launch separately.
82. Keep GRDB optimisation scope local. 83. Remove dead UI adapters only after
dependency graph proof. 84. Keep migration definitions and compatibility tests.
85. Track binary size by target, not source-line count.

### Release and maintenance (86–100)

86. Keep one current release pointer. 87. Keep immutable rollback artifacts.
88. Verify exact source commit in release JSON. 89. Verify DMG checksum after
public download. 90. Keep notarization profile out of source. 91. Scan HEAD,
all refs and generated artifacts. 92. Make Pages manifest and release agree.
93. Keep a clean-room install check. 94. Keep app/database rollback pairing.
95. Test light/dark menu appearance. 96. Test status-item and hotkey parity.
97. Test Settings Close/Command-W. 98. Test first-run permission recovery.
99. Keep changelog/backlog/project map machine-readable. 100. Never claim a
revolutionary feature without a measurable interaction or reliability win.

## Recommended 20 for the first 2.0 slice

The first implementation slice is deliberately small enough to verify:

1. Three-zone menu language and shared snapshot.
2. “В работе” contextual ranking and duplicate removal.
3. One unified history/snippet hotkey model.
4. Three-question Settings navigation.
5. Move Version to About.
6. Unified history retention presets.
7. Hide layout memory until enabled.
8. Inline permission explanations only when needed.
9. Remove retired pin/inspection affordances from all visible contracts.
10. Simplify snippet editor to title/text/folder.
11. Keep save-on-close and failed-draft recovery.
12. One visible pause-capture control.
13. Keep protected apps immutable and readable.
14. Keep safety fast paths and erasure barriers.
15. One bounded menu projection and one refresh decision.
16. Measure cold launch and hot menu latency.
17. Add accessibility identifiers and keyboard traversal checks.
18. Add light/dark and status-item/hotkey parity QA.
19. Add a release-size report with target-level attribution.
20. Ship only after source, tests, notarization, Pages and rollback agree.

## Explicitly not in 2.0 defaults

Accounts, cloud sync, AI, telemetry, tags, smart collections, global text
expansion, macro scripting, auto-learning that reads every keystroke, a large
permanent window, or a new permission without a demonstrated safety benefit.

## Primary-source signals

- [Maccy](https://github.com/kymokleo/maccy): lightweight keyboard-first
  history, direct Return/Option-Return actions, pinning and app exclusions.
- [Raycast Clipboard History](https://manual.raycast.com/clipboard-history):
  type filters, rich/plain paste, edit, rename, save as snippet and sequential
  paste; useful patterns, but too much surface for NeClip defaults.
- [Raycast Snippets](https://manual.raycast.com/snippets): folders/tags,
  placeholders and import/export; tags remain outside NeClip's immediate-use
  core.
- [CopyQ](https://github.com/hluk/CopyQ): tabs, edit, drag-and-drop, scripts
  and custom commands; powerful but deliberately not the default model here.
- [Pasta](https://pasta-app.com/): local-first history, snippets,
  placeholders and command mode; validates a compact context-first direction.
- [Microsoft Advanced Paste](https://learn.microsoft.com/en-us/windows/powertoys/advanced-paste):
  shows the value of an explicit paste action surface on Windows.
- [Apple Settings scene](https://developer.apple.com/documentation/swiftui/settings)
  and [menu-bar guidance](https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui):
  use standard Settings access and contextual menu commands rather than custom
  modal systems.

## Definition of done for 2.0

Programmatic: all existing safety/migration tests pass; new menu/settings
contracts pass; strict Swift 6, ASan, TSan, size and latency reports pass;
gitleaks scans all refs. Judge: a cold-start user can find and paste a recent
item or saved snippet without search or explanation. Human: release owner
approves the visible trade-offs and wording after a clean-room QA pass.
