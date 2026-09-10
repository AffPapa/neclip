# Changelog

All known NeClip releases are documented here. A version is downloadable only
after Developer ID signing, Apple notarization, stapling, Gatekeeper and exact
DMG checksum verification have passed.

## 2.5.1 / build 30 — release candidate, 2026-09-10

Исправлен снимок всего экрана и больших областей на Retina-дисплеях. Когда
исходный кадр больше безопасного лимита ScreenCaptureKit, полный экран теперь
пропорционально масштабируется в целевой размер (`scalesToFit`) вместо обрезки
сверху слева. Соотношение сторон сохраняется; режим области и режим всего
экрана используют один и тот же безопасный путь.

## 2.5.0 / build 29 — published, 2026-09-10

Большой Retina-экран больше не блокирует снимок области: кадр автоматически
пропорционально уменьшается до безопасного лимита 32 Мп. Добавлен отдельный
снимок всего экрана без overlay с независимой клавишей `⌘⌥3`; область остаётся
на `⌘⇧2`. Меню и настройки используют короткие единые подписи, а проверки
покрывают масштабирование, пиксельный бюджет и сохранение хоткеев.

Подписанный и нотарифицированный arm64 DMG опубликован после полного
release-gate. SHA-256: `7cd94b6d29a892c07e51fe743e463a434d41d4dbb38142d8e276fe586e4de96f`.

## 2.4.0 / build 28 — published, 2026-09-10

Screenshot UX and performance pass based on a fresh comparison of 15 macOS
utilities and 50 documented features. The selection overlay now supports
Space‑move and live dimensions; the editor accepts text directly on the image
and `1…5` selects tools without opening a panel. Capture lifecycle is fail‑closed
when the pending overlay cannot be excluded, crop uses one target buffer, and
latency diagnostics record stages without content, paths or app names.

No accounts, cloud, gallery, search, OCR, video or new package dependency were
added. Full research and the deliberately rejected feature list are in
`docs/RESEARCH-SCREENSHOTS-2026-09-10.md`.

The signed, notarized and stapled arm64 DMG is published in GitHub Release
v2.4.0. SHA-256: `b56abc1823f190c078f4fc935fe38dc607a7e58ff7597c26bf5a9373c2599d07`.

## 2.3.1 / build 27 — published, 2026-09-10

Native region screenshots, five annotation tools, opaque redaction, undo/redo,
PNG clipboard output and PNG/JPEG file export. One configurable shortcut and
a destination folder reuse the existing settings. No new package dependency,
cloud service, gallery, background screen stream or raw screenshot file.

The capture shell now appears immediately and stays inert until the frame is
ready; only that shell is excluded from ScreenCaptureKit. Cancellation is
generation-safe and Retina crop runs off the main actor. The editor is now
image-first with a transparent titlebar, proportion-aware initial size and one
compact bottom toolbar of SF Symbols with Russian accessibility labels.
The selection overlay now clearly explains the gesture before the first drag,
shows a small crosshair, and removes the hint as soon as selection starts.

The synthetic editor, all five tools, undo/redo, native PNG save and isolated
clipboard copy have been exercised live. The signed 2.3.1/27 release is
installed locally with 2.3.0/26 retained for rollback. The exact notarized DMG
is published in GitHub Release v2.3.1; its checksum and source commit are
recorded in the release assets and status document.
See `docs/SCREENSHOTS-IMPLEMENTATION-STATUS.md` for current evidence.

## 2.2.0 / build 25 — published, 2026-09-09

Chronological history, snippet folders directly in the menu and low-frequency
commands grouped under `Ещё…`. Per-application layout pinning was removed from
the menu without deleting compatible stored metadata.
See `docs/RELEASE-2.2.0-STATUS.md` for signing and notarization evidence.

## 2.1.0 / build 24 — published, 2026-09-08

Built from merge commit `93a836dfc65a97c5e6d592f9d70b6629a63963bc`.
The final arm64 DMG is 1,985,474 bytes; SHA-256:
`8292611f70706e696ad304afa884ed57a806dee3d43629e49046650abd1bbfc8`.
The public [GitHub release](https://github.com/AffPapa/neclip/releases/tag/v2.1.0)
is live with the signed, notarized DMG and checksum.

This pass keeps the immediate-use product boundary from 2.0.1 and removes
avoidable work from the two most frequent paths:

- Opening the menu reuses the already bounded history snapshot instead of
  copying the same rows twice.
- History trimming first uses the indexed unpinned-row count and only runs the
  ordered delete when the configured limit is exceeded.
- Removed a duplicate warning-icon assignment in the menu renderer.
- No new permissions, network behavior, dependencies, database migration or
  user-facing search/pin/focus features were added.

Release evidence, checksum and notarization identifiers are recorded in
`docs/RELEASE-2.1.0-STATUS.md`.

## 2.0.1 / build 23 — published, 2026-09-08

Built from commit `292f637419a4bd06633675b973b546d5f15a70b1`.
The final arm64 DMG is 1,984,962 bytes; SHA-256:
`0e8d8e6f057b025d9bc9721f7edb9a99ec40f7d4e2fb61717ec08574df798752`.
The app and DMG passed Developer ID signing, Apple notarization, stapling,
Gatekeeper and mounted-DMG verification. The public [GitHub release](https://github.com/AffPapa/neclip/releases/tag/v2.0.1)
is live with the signed, notarized DMG and checksum.

- Remove the duplicate **В работе**/Focus Stack projection and its storage
  snapshot data. History is one chronological list: the newest copy is first.
- Keep saved snippet folders directly visible in the menu; no second ranking,
  usage list or hidden “latest snippets” mode remains.
- Show installed and latest checked version inline at the bottom of Settings,
  with an explicit refresh action and no modal update flow.
- Keep the product boundary small: no accounts, cloud sync, telemetry, AI,
  search or additional clipboard permissions.
- Release gate: 247 XCTest cases, four expected skips, three Swift Testing
  checks, strict Swift 6 build, notarized app/DMG and full-history secret scan.

## 1.14.0 / build 21 — published, 2026-09-08

Published from merge commit `dd7c5296b6149eea3ae39dce8e0fa3524d6b66ba`.
The [public release](https://github.com/AffPapa/neclip/releases/tag/v1.14.0)
DMG is 1,976,259 bytes; SHA-256:
`4a83324e8ddc69c6efd24edb879b5f3caaea5b409bc149994790d9f6849c12f6`.
The app and DMG passed Developer ID signing, Apple notarization, stapling,
Gatekeeper and mounted-DMG verification.

- Add the bounded **В работе** Focus Stack: current-app clips plus snippets
  that were actually used before.
- Keep the regular chronological history and folder snippets as the fallback;
  duplicate focus clips are removed from the visible history page.
- Add `⌘1`–`⌘5` quick paste for the contextual working set, including snippets.
- Reuse existing local metadata and permissions; no migration, account, cloud,
  search, pin UI, telemetry or AI was added.
- Add pure ranking tests and update the project map/backlog with the product
  boundary and release gates.
- Release gate: 250 XCTest cases, four expected skips, three Swift Testing
  checks, strict Swift 6 warnings-as-errors build, and full-history secret scan.

## 1.11.0 / build 18 — local candidate, 2026-09-07

Not published or installed. Public download remains 1.10.0/build 17.
Local evidence and release boundaries: `docs/AUDIT-1.11.0-2026-09-07.md`.

- Add a persistent Version Settings pane: running-bundle version/build,
  dated GitHub result, explicit checking/error/cached states and honest
  equal/newer/development-build comparisons. About opens this pane without a request.
- Replace modal update results with inline status; opening Settings never
  checks automatically. One manual request at a time, validated metadata cache,
  ephemeral transport, redirect refusal and a streamed 64 KB response bound.
- Share byte-compatible SHA-256 hexadecimal encoding without per-byte formatting;
  group snippet rows without intermediate tuple arrays; reuse stable SQL order
  instead of sorting each folder menu again.
- Compare 15 clipboard utilities through primary sources and attributable
  issues: `docs/RESEARCH-1.11.0-INVISIBLE-2026-09-07.md`.
- No new dependency, data migration or broader clipboard/keyboard permissions.
- Initial debug, strict release, ASan and TSan each passed 260 checks (260 XCTest
  cases, four opt-in skips, plus four Swift Testing checks). Secret scanning
  covered the publishable tree, 61 HEAD commits and one side-ref-only commit.
- Isolated native QA verified six tabs at minimum width, light/dark appearance,
  explicit check, local-newer state, dated cache, Close/Command-W and About navigation.
- Hex-encoding median improved about 12.2x in its microbenchmark, not whole-app
  speed. Normal `-O` size grew 0.97% with the Version feature; accepted target-only
  `-Osize` reduces it to 4,329,808 bytes, 2.17% below the same candidate's `-O`
  and 1.22% below public 1.10.0. GRDB keeps `-O`; a global `-Osize` trial was
  rejected after a repeatable DB snapshot regression.
- Target-only release validation passed 263 checks including three opt-in
  benchmarks. Three repeated runs showed no observed snapshot regression.
  CI now includes strict release tests; a distribution contract guards target
  scope and safety flags. None of these measurements claims GUI/startup speed.

## 1.10.0 / build 17 — 2026-09-07

Published artifact source/tag: `60b26ad6182550e3e9b2646a0ee3bf319ea6e8ac`.
[PR #13](https://github.com/AffPapa/neclip/pull/13) merged as
`682ce5370d6c8ee5a95291fa63e114c9e50d2546` after all required CI/CodeQL checks.
The [public release](https://github.com/AffPapa/neclip/releases/tag/v1.10.0)
DMG is 2,006,978 bytes; SHA-256:
`d1f52a358b716a14d1fe60d28870af9a486a7defe6094f6396000c742cee9d1c`.
App and DMG notarization, stapling, Gatekeeper and independent unauthenticated
public-download verification passed, including a full comparison of app contents.

Folders now appear directly
in both menus. Removed duplicate quick snippets, top-item actions, text-transform
tools and creation of new pins. Existing protected clips remain accessible with
explicit warned unpinning. Option-click inspects the chosen item; Shift still
pastes plain text. Snippet insertion no longer writes usage statistics or
refreshes an unchanged library. Settings titles follow the active panel;
secondary layout-memory controls use progressive disclosure. See
`docs/MENU-SIMPLIFICATION-2026-09-07.md` for scope and Apple sources.

- Removed search, snippet keywords and derived FTS work; recent copies and
  snippet folders are the entire browsing concept. Existing content is preserved.
- Refresh only changed menu domains; retry dirty/failed reads when opening.
- Bound application metadata caching; remove unused storage and OCR routes.
- Keep debug symbols outside distribution binaries, with UUID verification
  before stripping and Developer ID signing.
- Group advanced retention controls without resetting user preferences;
  active cleanup stays visible, and the full disclosure header is clickable.
- Include transaction-scoped erasure/undo protection, atomic history-to-snippet
  conversion, OCR-only payload reads and lazy append fallback from local development.
- CI checks website/JSON consistency with the verified public download.
- Each debug, strict release, ASan and TSan run passed 245 checks: 244 XCTest
  cases with three opt-in skips, plus four Swift Testing checks. The flat-menu
  pass removed a net 379 runtime source lines.
- Publishing did not replace the installed application or modify its database.
  Migration v7 removes only derived search structures; downgrading requires a
  matching pre-upgrade database backup. Evidence: `docs/RELEASE-1.10.0-STATUS.md`.

## 1.9.1 / build 16 — 2026-09-06

- Published artifact source/tag: `ab1f98039f70a33b92b48ff9a1be15ad3f9f8282`.
  Exact download and verification evidence are recorded in
  `docs/RELEASE-1.9.1-STATUS.md`.
- Replaced custom Settings navigation with a native, persistent macOS toolbar.
  History retention, menu presentation, paste behavior and launch settings
  now have distinct groups; lower-frequency actions remain in the menu.
- Numeric drafts apply on Enter, focus loss, section change, window close or
  app quit. Escape cancels; partial keystrokes never trim history.
- History editing asks before discarding unsaved changes, retains failed-save
  drafts and rejects stale pending opens. Full data erasure invalidates drafts,
  OCR and previews so old content cannot be reinserted through the inspector.
- Added standard About, Settings and Edit commands. Local menu commands use
  physical keys across EN/RU layouts while ordinary text editing keeps focus.
- First-run help concentrates on history, search and snippet folders, with
  scrolling explanations and always-reachable permission/continue actions.
- Local verification: 241 successful checks and isolated minimum-window
  scenarios. Swift 6.3.3 CI exposed an IRGen crash for a Binding method
  reference; an explicit setter closure fixed it and repeat CI passed.
  Final sanitizer status and visual limitations are recorded in the audit.
- Obsolete local test/install artifacts were reviewed against exact allowlists;
  user databases, preferences and verified rollback data were preserved.
  No dependency or database migration was added.

## 1.9.0 / build 15 — 2026-09-06

- Published after green required CI/CodeQL checks. Exact artifact source/tag:
  `d168d1015c3933221c718633e9a4dfbdc4362729`. Developer ID, notarization,
  stapling and independent public-DMG verification passed. See
  `docs/RELEASE-1.9.0-STATUS.md` for release and installation evidence.

- Consolidated history/snippet query construction, bounded layout preferences,
  shortcut persistence and native menu pagination without changing stored keys,
  ordering, search limits or migration behavior.
- OCR and pin changes no longer materialize or rebind full image/RTF payloads
  in Swift. Empty privacy-rule lists return immediately; oversized text is
  rejected before normalization and UTF-8 buffer allocation.
- Cancelled queued menu searches do not start SQL work; running reads still
  use the existing generation checks before presenting results.
- Common settings stay visible, rare explanations use disclosures, and folder
  creation is a visible button. Russian labels distinguish duplication,
  search keys and history retention. Clean editor refresh avoids a second
  full-body fetch while retaining dirty-draft protection.
- Added regression coverage for metadata-only writes, byte quotas, Unicode
  bounds, settings compatibility, pagination and queued-search cancellation.
- Measured runtime reduction is 99 lines (0.85%), not the requested 30%.
  Safety checks, tests, migrations and existing functions were not removed to
  meet a cosmetic target. See `docs/AUDIT-1.9.0-2026-09-06.md` for measurements.
- Public download and update metadata now identify the verified 1.9.0 artifact.

## 1.8.0 / build 14 — 2026-09-05

- Released with Developer ID signing, Apple notarization, stapling and
  independent verification of the publicly downloaded DMG. Exact artifact
  source: `24ebd53d15efa540d944823431c59524b9ae3afa`.
- Swift CI, full-history secret scanning and Swift/Actions CodeQL passed.

- Settings/editor follow-up: effective login authorization and privacy-rule
  limits, persistent progress, separate transfer/cleanup groups, friendly
  duplicate-key errors, retryable folder forms and truthful deselection.
- Added asynchronous capture barriers to bulk deletion, export/import size
  parity, search overflow hints and safer query-editing key routing.
- Fixed the follow-up runtime regression: settings expose native Command-W
  and a visible Close button; history/snippet commands also work through the
  application menu with the configured shortcuts. Carbon hotkeys dispatch
  after consuming the event and explicitly reject conflicting registrations.
- Capture resume now reports a command-line pause instead of false success.
  Isolated debug copies show Preview identity and retain their database
  isolation across Finder relaunches. See the runtime follow-up audit.
- Refreshed primary-source research: 19 clipboard products, 11 layout tools,
  100 evaluated recommendations and 27 selected refinements (including fixes).
- Completed folder-first snippet hotkey and right-click access. Folder order
  matches the editor; counts/context and Command-E direct editing are visible.
- Added snippet duplication, editor deletion undo and Command-F/N/D. Explicit
  full erasure also drops in-memory drafts, cached menu results and undo.
- Fixed search footer disappearance, literal snippet queries, old-result
  activation while searching, filter replacement and exact keyword ranking
  before LIMIT. Search now includes Unicode folder names.
- Refresh clean editor state after external pin/move and update quick items
  after use. Count whole folders independently of active editor search.
- Normalize protected layout identities, keep Settings synchronized, reset one
  shortcut at a time, explain paste modifiers and numeric input cancellation.
- Render placeholders lazily in one pass, never interpret inserted clipboard
  text, cap expanded output at 2 MB, add literal escaping and ISO date/time.
- Normalize CRLF in line actions; add blank-line removal/per-line trimming;
  correctly encode URL components instead of leaving query delimiters raw.
- Public manifest and download now point to the verified 1.8.0 release.

### Earlier source work included in 1.8.0

The notes below describe historical source milestones, not additional
downloadable releases. Their improvements are now included in 1.8.0.

- Prepared source version 1.7.0/build 13 while keeping the public update
  manifest and signed/notarized download on 1.4.0 until the exact release
  artifact passes the external notarization and publication gates.
- Replaced the snippet sidebar's nested row buttons with native List selection,
  visible-order arrow navigation, debounced search, cached grouping and a clear
  no-results recovery state.
- Shortened the history root menu by grouping capture, cleanup, sequential
  paste, layout and update controls under **Management**. Recent source apps are
  now offered by readable name while inserting their exact bundle identifiers.
- Removed paste-and-delete. A clipboard utility cannot prove that the receiving
  application accepted an injected paste, so deletion is now always a separate,
  undoable user action.
- Fixed the clear-on-quit queue race, added a native Command-Q application menu,
  distinguished pending pasteboard permission from granted access and moved
  destructive/import/export Data work off the main actor with visible progress.
- Reduced hot-path work with content-only FTS update triggers, paged semantic
  filtering, bounded off-main image previews, newest-pending OCR, cached layout
  key maps and coalesced Accessibility context refreshes.
- Made update comparison include the build number. Hardened release provenance,
  exact architecture checks, atomic local dist publication, CI credential
  persistence and secret scanning of fetched pull-request refs.
- Re-ran 143 normal checks, AddressSanitizer, ThreadSanitizer, a disposable copy
  of the live database and a strict Swift 6.4 release build with complete
  concurrency and warnings as errors.

- Prepared source version 1.6.2/build 12 while keeping the public update
  manifest and signed/notarized download on 1.4.0 until a separate release gate.
- Reworked snippet presentation around lightweight 280-character summaries.
  Menus, search and the editor sidebar no longer retain every full body; the
  selected snippet alone is fetched for editing or paste.
- Applied the import field bounds to local snippet writes, fixed stale RTF after
  a newer plain-text copy and made manual selection replacement abort before
  clearing when any advertised pasteboard representation is unreadable.
- Removed redundant automatic-layout Accessibility refreshes without weakening
  the event-sequence lock, whole-value compare-and-swap, verification or
  rollback.
- Made secret scanning self-test GitHub, AWS and Slack detectors before use and
  scan HEAD plus side-ref-only history explicitly. The audit contract now checks
  every public `AUDIT*.md` document, and version assertions match the source.

- Prepared source version 1.6.1/build 11 while keeping the public update
  manifest and signed/notarized download on 1.4.0 until a separate release gate.
- Made password-manager capture protection immutable and case-insensitive in
  both ordinary capture and the delayed application-transition guard. Protected
  applications stay visible, locked and human-readable in Privacy Settings.
- Added a one-click, target-aware **Do Not Save from This App** rule to the
  native menu, with an equally direct restore action for ordinary applications.
- Rejected empty or over-16 MB snippet-import files before JSON decoding and
  memory-mapped accepted imports where the system can do so safely.
- Removed five proven unreachable fields/wrappers/helpers without touching
  database migrations, compatibility tests or research evidence.

- Prepared source version 1.6.0/build 10 while keeping the public update
  manifest and signed/notarized download on 1.4.0 until a separate release gate.
- Added Space preview for the first result only while search is empty, so a
  normal multiword query never loses its spaces.
- Added an explicit one-shot append action for the next accepted text. It
  merges transactionally into the latest unpinned text, preserves a valid new
  copy as a separate record when the combined value exceeds the user's limit,
  and never consumes the action for files, images or rejected text.
- Added a fixed input source per application. It has priority over optional
  last-used layout memory, acts only on application activation, requires no
  Input Monitoring and has visible menu toggle, count and reset controls.
- Replaced row-by-row byte-quota trimming with one SQLite window query and
  normalized/deduplicated all application exclusion lists.
- Repeated the product study from a blank decision set: 20 clipboard managers,
  20 layout tools, five distinct layout architectures, exactly 100 candidates
  and a newly scored top 20.

- Prepared source version 1.5.0/build 9 while keeping the public update manifest
  and signed/notarized download on 1.4.0 until a separate release gate.
- Added a 64–2048 KB maximum for one captured text record. RTF is retained only
  while the complete text record stays inside that user limit.
- Added partial cleanup for the last hour and today plus full unpinned cleanup;
  pins and snippets remain protected.
- Added optional fail-closed clearing of unpinned history on quit. If storage
  cannot confirm deletion, NeClip cancels termination instead of implying that
  private data was erased.
- Added **Paste and Delete** for the top unpinned history result. Deletion runs
  only after a successful direct-paste dispatch; copy-only, missing
  Accessibility, target changes and failed paste never delete it.
- Added independent, default-off per-application input-source memory bounded to
  200 local mappings, with visible count/reset and no keyboard-event monitoring.
- Automatic-correction undo now keeps a bounded, memory-only ignore list for
  the current session so the same false correction is not repeated.
- Documented 18 clipboard products, 19 layout products, three different layout
  architectures and a new 100-candidate add/defer/reject catalogue.

- Added structured history search by base type, smart text category, source
  application, date window and pin state, plus a bounded fuzzy fallback.
- Added a focused full-item inspector with transactional text editing,
  renaming, safe HTTP(S)/file opening and direct OCR-text paste.
- Added memory-only sequential paste, then simplified it after product review:
  `⌃⌘V` now walks a stable snapshot of recent history without start/stop
  collection, resets after 30 seconds or a new copy, and stores identifiers only.
- Made the history, snippets and sequential-paste shortcuts locally
  configurable. All five NeClip shortcuts share conflict validation;
  registration failure preserves the previous working shortcut.
- Reorganized Settings into General, Keys, Privacy, Layout and Data sections.
- Unified the history-size and menu-label-length settings into matching numeric
  rows with a visible editable value, identical steppers, clear units and safe
  range normalization.
- Made snippet editing self-explanatory: the top visible snippet opens
  automatically, every full-width row has an edit affordance and accessible
  action, and the editor explicitly labels editing and automatic saving.
- Fixed the disabled **Quit NeClip** command by targeting a real controller
  action; application termination now flushes snippet edits and cancels quit if
  a draft cannot be saved.
- Expanded bounded menu browsing from 40 to 100 ordinary and pinned entries,
  while keeping older values searchable without constructing 1,000 menu rows.
- Simplified search wording and renamed first-result actions to explicitly say
  they operate on the top visible item.
- Added a native magnifier menu for the common structured history filters, so
  type, date, pin and application search no longer depend on memorized syntax.
- Bounded the menu snapshot to 200 snippets and only their referenced folders;
  the full imported library remains available through on-demand search/editor
  queries.
- Replaced per-snippet full-data deletion with one atomic transaction that
  removes clips, snippets and snippet folders together.
- Replaced technical bundle identifiers in the item inspector with the local
  source application's display name.
- Removed obsolete paste compatibility wrappers left behind by the deleted
  legacy history panel.
- Added age retention for ordinary history, independent image capture,
  local sensitive-phrase exclusions and a default plain-text paste preference.
- Added a nested, offline transform menu for whitespace, case, lines, URL and
  JSON operations; transforms paste a temporary result without mutating history.
- Added deterministic, versioned snippet JSON export and atomic merge-only
  import. History and usage metadata are never exported.
- Documented the 100-function competitor catalogue and the scored top-20
  selection in `docs/FEATURE-RESEARCH-2026-08-31.md`.
- Expanded the pre-1.5 local suite to 119 checks: 111 XCTest cases plus eight
  Swift Testing cases (one optional external-database case is skipped unless
  its disposable fixture is supplied); strict Swift 6 release
  compilation and full-history secret scanning pass.

## 1.4.0 — 31 August 2026

- Unified the complete native menu tree under the application's current system
  appearance, so status-item and global-hotkey entry points no longer inherit
  different light/dark presentation contexts.
- Added a Settings field for menu-label length (16–96, default 64). Multiline
  and Unicode whitespace collapse to one line; truncation counts complete Swift
  graphemes and appends an ellipsis without splitting emoji or combined text.
- Made manual layout correction configurable and added a configurable,
  deliberately off-only shortcut for immediately disabling automatic
  correction. Conflicting candidates fail transactionally and preserve the old
  working registration and persisted preference.
- Rebuilt the snippet editor as a compact two-column interface with visible
  folders, empty sections, an explicit unfiled section, folder-aware search,
  fixed labels, folder create/rename/delete and snippet moves.
- Fixed a draft-loss race in the previous editor. Pending edits now flush before
  selection, folder operations, window close, view disappearance and app exit;
  failed saves remain visible and block navigation until retry succeeds.
- Preserved snippets when their folder is removed and prevented stale editor
  state from overwriting newer usage counters and timestamps.
- Expanded the suite from 45 to 76 tests. The full suite, strict Swift 6
  complete-concurrency build, sanitizers, GitHub CI and CodeQL passed.
- Signed and notarized the exact app and DMG, stapled both tickets, passed
  Gatekeeper outside and inside the read-only mounted public image, and
  independently matched the GitHub download to its SHA-256 file.

## 1.3.2 — 31 August 2026

- Restored individual item management inside the compact native menu without
  bringing back a large main window: pin/unpin, save text as a snippet, delete
  and undo now act on the first visible result.
- Added `Command-P`, `Command-S`, `Command-Delete` and `Command-Z` search-first
  keyboard actions with an explicit, discoverable submenu.
- Made snippet deletion exactly reversible, preserving its identifier, keyword,
  pin, usage counters and timestamps; undo safely moves it out of a folder that
  was deleted in the meantime.
- Added visible recovery guidance when a fixed global shortcut is already owned
  by macOS or another application.
- Removed the unreachable 846-line legacy clipboard window and the duplicate
  menu refresh after every accepted copy.
- Updated the sole source dependency from GRDB.swift 7.10.0 to 7.11.1 after the
  newly enabled Dependabot check identified the current upstream release.
- Added weekly SwiftPM and GitHub Actions Dependabot checks. Enabled immutable
  releases, private vulnerability reporting, vulnerability alerts, security
  updates, GitHub-owned-only Actions with full-SHA enforcement, CodeQL default
  setup and deletion/force-push protection for `main`.

## 1.3.1 — 30 August 2026

- Moved the manual update manifest from AffPapa hosting to the repository-owned
  GitHub Pages endpoint.
- Restricted update metadata to the exact GitHub Pages manifest path and exact
  `AffPapa/neclip` GitHub Release download path.
- Added fail-closed validation for semantic version, build number, SHA-256,
  response size, MIME type, URL credentials, ports, query and fragment.
- Added a machine-readable GitHub source-of-truth index for website and release
  integrations.
- Removed the obsolete AffPapa landing implementation from the NeClip repository.

## 1.3.0 — 30 August 2026

- Rebuilt the primary interface as a compact native menu inspired by ClipMenu
  and Clipy: history inline, older items grouped by tens, snippets in folders.
- Kept NeClip exclusively in the macOS menu bar and out of the Dock.
- Added immediate search, keyboard navigation, quick keys 1–9, plain-text paste,
  copy-only mode, pinned history and reversible history deletion.
- Added starter snippets, snippet folders, keywords, local placeholders and a
  focused editor.
- Added manual EN/RU layout correction with Option-Shift-L and Control-Return
  correction directly from clipboard history.
- Added conservative, default-off automatic layout correction after Space with
  dictionary validation, protected contexts, bounded RAM and five-second undo.
- Added pause, ignore-next-copy, excluded applications, concealed/transient
  pasteboard filtering, source attribution guards and a 250 MB hard quota.
- Added bounded image decoding, thumbnails, serialized local OCR and FTS5 search.
- Added macOS 15.4+ pasteboard privacy onboarding, visible authorization state
  and fail-closed behavior for Always Deny.
- Migrated to real Swift 6 language mode and strict concurrency.
- Upgraded and exactly pinned GRDB.swift 7.10.0; removed the HotKey dependency
  in favor of the native Carbon global-hot-key API.
- Hardened release automation so existing artifacts survive any failed gate.

## 1.1.1

- Last known signed, notarized and publicly downloadable baseline before 1.3.0.
- Local clipboard history, search, snippets and menu-bar operation.

## Verification status

- Source tests, Thread Sanitizer, Address Sanitizer, strict Swift 6 release
  build, GitHub CI and CodeQL: passed for 1.4.0.
- The app and DMG are signed with Developer ID, notarized by Apple, stapled and
  accepted by Gatekeeper outside and inside the mounted image.
- Public download: [NeClip 1.4.0](https://github.com/AffPapa/neclip/releases/download/v1.4.0/NeClip-1.4.0.dmg).
- SHA-256: `0dc548a6625a74c6fac22bb4bf128ae174ab192631025cf7095a4d7fcceaf612`.
## 2.2.0 — 9 September 2026

- Unified the menu into one chronological feed: history stays first and snippet folders remain directly visible below it.
- Renamed the low-frequency controls to `Ещё…` and removed per-application layout pinning from the user-facing menu.
- Kept legacy layout metadata only for database compatibility; no stored history or snippets are changed.
