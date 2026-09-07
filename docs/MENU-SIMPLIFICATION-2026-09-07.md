# NeClip: flat menus and safe simplification

7 September 2026. Source candidate **1.10.0/build 17**, not a published DMG.

## Professional task prompts and plan gate

1. macOS engineer: expose snippet folders directly, remove implicit top-item
   commands and redundant runtime work, preserve all existing protected data.
2. Apple-platform UX reviewer: use relevant primary HIG guidance for shallow
   menus, stable grouping, standard Settings panels and progressive disclosure;
   simplify controls without removing privacy or loss-prevention safeguards.
3. Release engineer: inspect existing signing/notarization access without
   reading or printing private keys; verify exact code, artifact and public site.

All three started as independent read-only audits. Their findings agreed before
implementation. Scope excludes production database changes, new credentials,
accounts, cloud, broad machine cleanup and unrelated services. The release gate
requires tests, strict Swift, sanitizers, isolated UI checks, secret scanning,
protected GitHub checks, exact signing/notarization and live download/site checks.
Absent notarization access blocks a new binary, not safe source/site publication.

## Implemented

- Both menus use the same direct folder list. No outer Snippet Folders submenu,
  duplicated quick snippets, implicit first-item actions or pin-creation UI.
- Deleted the now-unreachable text-transform toolset and its feature-only tests.
  Privacy, migrations, safe paste, cleanup and regression tests remain.
- Option-click inspects the selected clip by exact ID before paste work starts.
  It replaces the old Option formatting override; Shift remains plain-text paste,
  Command copy-only and Control layout correction. A visible menu hint explains it.
- Existing pinned clips keep protection from retention, including image/file/RTF
  payloads. The conditional Previously Pinned group remains accessible. Its
  inspector offers explicit Unpin with a retention warning. The unpin operation
  changes metadata only, never runs cleanup and never touches another clip.
- Old snippet pin fields are inert compatibility metadata; editing/duplicating
  preserves them without showing a pin control. No new schema migration is needed.
- Menu projection is stable by folder/snippet sortIndex/ID before applying its
  bound. Pasting no longer writes usage metadata or refreshes unchanged snippets.
- Creating a snippet from an inspector draft is transactional and checks that
  the source still exists; it does not save/trim the original first. Independent
  review found this deletion hazard in an initial draft and it was corrected.
- Settings title follows the selected panel; zoom/minimize are disabled while
  resizing remains available. Secondary layout-memory controls are disclosed
  on demand, without resetting existing rules. Legacy cleanup wording is explicit.

## Apple guidance, not an Apple endorsement

Reviewed the relevant sections, not every guideline Apple publishes:

- [Menus](https://developer.apple.com/design/human-interface-guidelines/menus):
  shallow hierarchy and related command grouping support direct folders.
- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings):
  standard macOS panels and panel-specific window titles.
- [Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls):
  secondary details can be revealed when needed without hiding active state.
- [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards):
  conventional navigation and understandable shortcut descriptions.
- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra):
  menu-bar utility role. Existing AppKit NSStatusItem is retained; no framework rewrite.

The HIG menu-bar page returned a JavaScript placeholder in one retrieval and is
not counted as read. Option-click is a NeClip product decision, not a claimed
Apple requirement. No popularity assumptions justify removing privacy settings.

## Verification and delivery status

Debug and strict-release tests passed: 244 XCTest cases, three opt-in skips,
zero failures, plus four Swift Testing checks (245 successful checks total).
New checks cover stable bounded folder ordering, preservation of protected
payloads, idempotent exact-ID unpinning, invalidated inspectors, draft conversion,
legacy snippet editing and removed menu paths. Structural menu tests do not
replace live interaction testing. Sanitizers/native QA/publication results are
recorded in the associated PR evidence after they actually run.

The previous Developer ID identity is available. Filename-only checks across
relevant local locations did not find the former .p8; the neclip Keychain profile
is absent. No secret values were read or printed. New certificates are unnecessary;
existing notarization credentials must be restored locally before publishing a
new DMG. The public download remains verified 1.9.1 and the installed app/data are
unchanged. Source 1.10.0 also includes prior v7 FTS retirement: downgrade requires
the matching pre-upgrade database backup, not just replacing the binary.
