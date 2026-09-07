# NeClip: flat menus and safe simplification

7 September 2026. **1.10.0/build 17 released at 08:15:45 UTC**.
[Public release](https://github.com/AffPapa/neclip/releases/tag/v1.10.0).
The DMG is independently verified; website/updater-feed changes are being
published separately and are not claimed live in this report.

## Professional task prompts and plan gate

1. macOS engineer: expose snippet folders directly, remove implicit top-item
   commands and redundant runtime work, preserve all existing protected data.
2. Apple-platform UX reviewer: use relevant primary HIG guidance for shallow
   menus, stable grouping, standard Settings panels and progressive disclosure;
   simplify controls without removing privacy or loss-prevention safeguards.
3. Release engineer: inspect existing signing/notarization access without
   reading or printing private keys; verify exact code, artifact and public site.

All three started as independent read-only audits. Their findings agreed before
implementation. Scope excludes production database changes, new signing certificates,
accounts, cloud, broad machine cleanup and unrelated services. The release gate
requires tests, strict Swift, sanitizers, isolated UI checks, secret scanning,
protected GitHub checks, exact signing/notarization and live download/site checks.
The initial notarization-access blocker was resolved by the user configuring
the local Keychain profile before signing/notarization and binary publication.

## Implemented

- Both menus use the same direct folder list. No outer Snippet Folders submenu,
  duplicated quick snippets, implicit first-item actions or pin-creation UI.
- Deleted the now-unreachable text-transform toolset and its feature-only tests.
  Privacy, migrations, safe paste, cleanup and regression tests remain.
- Option-click inspects the selected clip by exact ID before paste work starts.
  It replaces the old Option formatting override; Shift remains plain-text paste,
  Command copy-only and Control layout correction. A visible menu hint explains it.
  Native testing caught a late modifier-polling issue: actions now capture the
  activating NSEvent flags, not the keyboard state after tracking ends. The same
  correction applies to snippet copy-only and numeric history shortcuts.
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

Debug, strict-release, ASan and TSan tests passed: each ran 244 XCTest cases, three opt-in skips,
zero failures, plus four Swift Testing checks (245 successful checks total).
New checks cover stable bounded folder ordering, preservation of protected
payloads, idempotent exact-ID unpinning, invalidated inspectors, draft conversion,
legacy snippet editing and removed menu paths. Structural menu tests do not
replace live interaction testing. All required GitHub Swift CI, full-history
secret scanning and Swift/Actions CodeQL checks passed before PR #13 merged.

Isolated native QA verified direct root folders, the dedicated snippet menu,
light/dark editor without pin controls, active-panel Settings title, disabled
zoom and disclosed layout memory. Option-Return on a selected synthetic legacy
clip opened its exact inspector; Unpin showed a warning, retained the text in
history and removed the now-empty legacy group. Inspector Command-W and menu
Quit worked. One earlier CUA timeout followed Settings closure; a one-second
process sample showed an idle event loop, not a blocked main thread. Only that
synthetic QA process was restarted. No production clipboard/database was used;
global hotkey registration conflicts are expected while the installed app runs.

The previous Developer ID identity was reused. Filename-only checks initially
did not find the former .p8; the user subsequently configured the local `neclip`
Keychain profile, resolving the blocker without a new signing certificate.
The profile check, full release build, application/DMG notarization, stapling
and Gatekeeper checks passed. Account details and secret contents are not
included here.

Exact artifact source/tag: `60b26ad6182550e3e9b2646a0ee3bf319ea6e8ac`.
[PR #13](https://github.com/AffPapa/neclip/pull/13) merged as
`682ce5370d6c8ee5a95291fa63e114c9e50d2546` after all required checks passed.
The public DMG is **2,006,978 bytes**, SHA-256
`d1f52a358b716a14d1fe60d28870af9a486a7defe6094f6396000c742cee9d1c`.
Independent unauthenticated download verification checked the actual Git tag,
provenance, checksum, size, full mounted-app equality, arm64, signatures, staple
and Gatekeeper. The image was ejected after verification. Private local evidence:
`/tmp/neclip-110-release.log`, `/tmp/neclip-110-public.log`,
`.qa/110/public.Tme2dT/`. Full release details and accepted Apple submission IDs
are in [release status](RELEASE-1.10.0-STATUS.md).

The installed app and production data are unchanged. Version 1.10.0 includes
prior v7 FTS retirement: back up the database and export snippets before updating.
Downgrade requires the matching pre-upgrade database backup, not just replacing
the binary. Site and updater-feed publication and live verification are tracked
separately in [PR #14](https://github.com/AffPapa/neclip/pull/14), including its
post-deployment receipt.
