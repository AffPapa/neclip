# NeClip 1.4.0 engineering audit

This is the public engineering record for the unified-menu, editable-hotkey and
snippet-editor cycle. GitHub remains NeClip's only source, update and release
channel. No account, cloud synchronization, telemetry, AI processing,
background network service, permanent Dock icon or broad workspace was added.

## User-visible problems

1. Opening the native menu from the status item and from a global shortcut could
   inherit different light/dark appearances.
2. A long copied value could make the menu unnecessarily wide.
3. The manual layout shortcut was fixed in code, and automatic correction had
   no dedicated emergency off shortcut.
4. The snippet editor hid folder membership and could discard a pending edit
   when selection changed before its delayed save executed.

## Independent read-only audits

Three tracks inspected clean source commit
`682168499820448bb31d9befc7d1d3955ea4d1d8` before mutation.

- AppKit/menu track: both entry points built the same `NSMenu`, but one popup was
  anchored to `NSStatusBarButton` and the other detached at the pointer. No
  shared explicit appearance existed. A stored title-length preference was not
  exposed or consumed, while runtime truncation was hardcoded.
- Input/hotkey track: `Option-Shift-L` was duplicated through Carbon
  registration, the live event tap, menus, onboarding and feedback. Rebinding
  needed a register-new-before-release-old transaction.
- Snippet/data track: the live database had two folders, eight snippets and no
  broken folder references. The editor flattened that hierarchy. Its delayed
  save was cancelled by a selection change, creating a real data-loss race.

## Decisions

- Follow `NSApplication.effectiveAppearance`; do not add a separate theme
  preference.
- Format labels with a pure single-line Unicode-grapheme function. Persist a
  bounded integer from 16 through 96, default 64, and append `…` only when the
  normalized value exceeds the exact limit.
- Record only physical A–Z/0–9 keys with at least two modifiers. Keep
  `Option-Shift-L` as the manual default and use `Control-Option-A` for an
  off-only emergency action. Reserved NeClip shortcuts cannot be selected.
- Keep a compact two-column snippet editor. Show every folder, empty folders and
  `Без папки`; make field labels permanent; add folder CRUD and a move picker.
- Bind each pending draft to its original snippet identifier and synchronously
  flush before navigation or close. A failed save stays in memory and blocks
  the destructive transition.

## Verification evidence

- Full Swift test suite: 76 executed, 75 passed, one intentionally skipped
  external-database-copy test, zero failures.
- Menu presentation: 9 tests for 32/64 boundaries, whitespace, CJK, emoji/ZWJ,
  combining marks, clamping and recursive appearance.
- Shortcut descriptors: 8 tests for persistence, physical keys, framework flag
  conversion, reserved combinations and noisy modifier flags.
- Storage/editor: folder rename, move and delete preservation; draft flush;
  failed-save retention; and newer usage-metadata preservation.
- Strict Swift 6 build: complete concurrency checking plus warnings-as-errors.
- Address Sanitizer and Thread Sanitizer passed. Both GitHub Swift CI jobs and
  CodeQL's Actions and Swift analyses passed with zero open alerts.
- Apple accepted the exact app ZIP (`d235f751-6468-4864-bbda-014c4e02bd52`)
  and DMG (`6b436521-f4ea-4fe3-8ed6-69467965151d`). Both tickets were stapled;
  Gatekeeper accepted the app, DMG and app inside a read-only mounted image.
- The independently downloaded immutable GitHub asset is 2,426,819 bytes and
  matches SHA-256
  `0dc548a6625a74c6fac22bb4bf128ae174ab192631025cf7095a4d7fcceaf612`.

## Data and permission invariants

- No schema migration or destructive data rewrite was introduced.
- Deleting a folder keeps its snippets and their metadata in `Без папки`.
- Editable snippet saves do not overwrite `useCount` or `lastUsedAt`.
- The safety shortcut stops the automatic event tap before changing its setting
  and cannot enable Input Monitoring.
- Shortcut recording observes only key events sent to NeClip's active Settings
  window and requests no new permission.

## Deferred work

Nested folders, drag ordering, imports, cross-device sync, configurable history
and snippet popup shortcuts, and a separate theme selector are intentionally not
part of this release.
