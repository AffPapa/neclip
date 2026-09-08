# NeClip project map

Updated: 8 September 2026. Public release: **2.0.1/build 23**.

The 2.0.1 pass is the current minimal product direction: one chronological
history list, with the newest copy first, and saved snippet folders directly in
the menu. The duplicate **В работе**/Focus Stack projection and its derived
`recentSnippets` snapshot are removed. Settings shows the installed version
and the latest checked GitHub version at the bottom.

The public 2.0.1 app and DMG passed signing, notarization, stapling, Gatekeeper,
mounted-DMG and full-history secret checks. The signed DMG and checksum are in
GitHub Release `v2.0.1`; `docs/version.json` is the update manifest.

The 1.13 release removes pinning and history inspection from the product
surface. Legacy pin flags are retired by migration `v8-retire-pins`; the
history menu is one chronological list and the snippet editor no longer has
the secondary duplicate action.
`RELEASE-2.0.1-STATUS.md` records the signed, notarized and independently
verified public release. The immutable previous 1.14.0 release remains the
public rollback target. The global research compares 21
clipboard/layout utilities in `RESEARCH-GLOBAL-1.12-2026-09-07-research.md`
and keeps search, cloud, accounts, AI and plugins outside the product boundary.
The 1.12 release keeps the Version pane and measured 1.11 hot-path work, then
indexes snippet-folder titles once per menu build instead of performing a
linear folder lookup for every row. This is an O(snippets × folders) to
O(snippets + folders) projection change; order, previews, orphan fallback and
paste behavior are unchanged.
Initial CUA path timeouts were resolved by selecting the QA app by bundle ID.
The audit distinguishes native checks from unit-only offline/oversize scenarios.
Normal `-O` size grew 0.97%, but accepted NeClip-target-only release `-Osize`
produces approximately 4,329,816 stripped bytes in the 1.12 release: 2.17%
below the same candidate's normal `-O` and 1.22% below public 1.10.0. GRDB stays
`-O`; the global `-Osize` trial was rejected for
snapshot regression. Target-only release passed 263 checks with opt-in benchmarks.
The 12.2x hex-encoding improvement is only a microbenchmark. Current release
evidence is in `RELEASE-2.0.1-STATUS.md`.

Current menu design: `MENU-SIMPLIFICATION-2026-09-07.md`. Both roots expose
snippet folders directly; no quick-list duplication, top-item actions, text
transform tools, pins, Focus Stack or history inspector. Release evidence:
`RELEASE-2.0.1-STATUS.md`. Site/download consistency is checked by
`scripts/verify-site.rb`. Artifact source and checksum are recorded in
`docs/version.json` after the release build.
Required CI/CodeQL, app and DMG notarization, stapling, Gatekeeper and independent
unauthenticated download verification passed, including the full app comparison.
Each debug, strict release, ASan and TSan run passed 245 checks (244 XCTest
cases with three opt-in skips, plus four Swift Testing checks). The flat-menu
pass removed a net 379 runtime source lines. Publishing did not replace the
installed app or modify its production database.

Development recorded in `20260906-fresh-pass` under
`artifacts/neclip/looper-goals/` is included in 1.10.0:
transaction-scoped erasure invalidation for undo,
atomic history-to-snippet conversion, an OCR-only projection, lazy append
fallback payloads and editor/Settings clarity changes. No dependency was added.
Migration v7 retires only derived search structures, not stored content;
rollback requires a matching pre-upgrade database backup.

Historical Settings and simplification evidence remains in
`AUDIT-1.9.1-2026-09-06.md`, `AUDIT-1.9.0-2026-09-06.md` and
`RESEARCH-1.9.0-SIMPLIFICATION.md`.

The prior evidence report is `AUDIT-1.8.0-2026-09-05.md`; the refreshed
19-clipboard/11-layout comparison, 100-item matrix and 27 selected refinements
are in `RESEARCH-2026-09-05.md`. Older reports remain historical evidence, not
current feature or release claims.

The later close/capture/shortcut repair and its live QA evidence are recorded
in `BUGFIX-RUNTIME-2026-09-05.md` (185 checks passed, one opt-in skip).

The earlier settings/editor usability audit is `UX-SETTINGS-2026-09-05.md`
(206 checks passed, one opt-in skip). `HistoryCleanupCoordinator` now owns the
capture barrier for explicit bulk deletion; `PreferencesUXPolicy` describes
effective settings states. The no-search pass included in 1.10.0 retires all search UI
and execution; see `NO-SEARCH-2026-09-06.md` for the current scope and checks.
The optimization pass included in 1.10.0 is `OPTIMIZATION-2026-09-06.md`: selective
menu invalidation, bounded app metadata, smaller distribution binaries and
progressive disclosure of retention controls.

## Product boundary

- Native macOS 14+ menu-bar utility; `LSUIElement=true`, no Dock icon.
- Immediate reuse: recent copies and folder snippets, with no search or search keys.
- Local SQLite history and snippets; no account, sync, telemetry, ads or AI.
- Network is used only after the user chooses **Check for Updates**.
- Accessibility is optional for direct paste and selected-text replacement.
- Input Monitoring is requested only for explicit, default-off automatic
  EN/RU correction.

## Runtime flows

### Clipboard capture

`main.swift` -> `AppDelegate` -> `ClipboardMonitor` -> privacy/source policies ->
`Storage.insert` -> one storage-change notification -> bounded menu snapshot.

Important owners:

- `ClipboardAccess.swift`: macOS pasteboard authorization state and recovery.
- `ClipboardMonitor.swift`: generation-based polling, source attribution and
  asynchronous payload processing, including the user-bounded text payload.
- `ClipboardTextMerge.swift`: deterministic one-newline append policy and
  single-line title generation for the explicit one-shot append action.
- `SensitiveContentPolicy.swift`: immutable case-insensitive password-manager
  policy plus literal sensitive-phrase rejection; concealed/transient types are
  rejected by `ClipboardMonitor` before payload reads.
- `OCRService.swift`: serialized local Vision OCR.
- `ContentDigest.swift` (1.12.0 release): shared byte-compatible SHA-256 hex
  encoding for capture and storage fallback, without per-byte string formatting.
- `Storage.swift`: migrations, SHA-256 deduplication, retention, byte quota,
  atomic persistence and v7 retirement of derived FTS tables/triggers/indexes.
  History reads use one bounded summary API; snippets retain bounded projections. OCR and pin updates select metadata
  only, preserve payloads and remain within the existing quota transaction.

### Menu and paste

`StatusBarController` owns both entry points: status-item click and global
history/snippet shortcuts. Both build the same native `NSMenu`, apply the same
effective appearance and use lightweight `ClipSummary`/`SnippetSummary` rows.
The ordinary and pinned browse windows are capped at 100 each; the menu snippet
projection is capped at 200 and every content preview at 280 characters. Full
local history and snippet bodies are fetched only for the chosen action.

- `MenuPresentation.swift`: single-line, grapheme-safe menu titles and shared
  ten-item pagination with stable absolute indices.
- `MenuRefreshState.swift`: dirty-domain/generation tracking; unchanged history
  or snippets are reused, obsolete reads cannot restore erased snapshots.
- `PasteService.swift`: direct/plain/copy-only paste and lossless,
  compare-and-swap restoration of a temporary pasteboard; an unreadable
  advertised representation aborts before clearing. Paste never deletes the
  source because event dispatch cannot prove target-app acceptance.
- `HistoryItemActions.swift`: explicit safe open/edit actions for selected history
  rows. The old inspector window and option-click workflow are retired.
- `SequentialPasteSequence.swift`: memory-only stable IDs for `Control-Command-V`.

### Snippets

The dedicated shortcut and ordinary history menu show folders directly;
right-clicking the status item is an alternative. The bounded SQL projection
and folder browse use stable folder/snippet sortIndex/ID, not usage or pins.
History is strictly chronological: the newest accepted copy is first, with no
second “latest snippets” ranking. Counts describe displayed items; an overflow
hint points to the complete editor. There is no duplicate quick list, pin UI or
history inspector. Native arrows and Return own selection.

`SnippetsEditor` reads lightweight summaries for folders, empty folders
and **Unfiled**, then fetches one full body when selected. Selection, navigation
and termination flush pending drafts; failed saves remain visible. Local writes
and imports share title and 2 MB content bounds. `SnippetRenderer`
expands local `{date}`, `{time}`, `{clipboard}`, `{date:iso}` and `{time:iso}`
placeholders in a single bounded pass. `{{date}}` escapes a literal token;
inserted clipboard text is never reinterpreted. Formatters are lazy, expanded
output above 2 MB fails before appending, and preview truncation uses slice
indices rather than counting the entire stored body. `Storage` provides versioned
JSON export and atomic merge-only import without history or usage metadata;
empty and over-16 MB import files are rejected before JSON decoding.

The editor always shows the folder library. Search fields, Command-F, queries,
filtering, debounce tasks and keyword fields are gone throughout the app.
Creation/duplicate use Command-N/D and visible buttons. Duplicate preserves
content/folder/legacy pin metadata but not usage; pin UI is absent. One-item undo survives ordinary refresh but not
explicit full-data erasure. Clean editors refresh external pin/move changes;
dirty drafts remain protected. Legacy keyword data is inert in SQLite and
ignored when importing old JSON; exports contain no keys. Historical migrations
are retained for upgrades, followed by v7 derived-index retirement. A database
backup is required before installing this schema on a production database;
older binaries cannot consume the retired FTS schema.

### Keyboard layout correction

- `KeyboardLayoutService.swift`: system-derived layout map.
- `LayoutCorrectionCore.swift`: pure mapping and confidence rules.
- `LayoutAccessibility.swift`: guarded focused-range read/write.
- `AutoLayoutController.swift`: bounded in-memory keystroke buffer and event tap.
- `LayoutFeedbackHUD.swift`: brief status/undo feedback.
- `ApplicationLayoutMemory.swift`: independent app-activation/TIS observer for
  bounded last-used and fixed source maps; fixed rules have restore priority
  and the controller never observes text or key events.

Manual correction is the dependable path. Automatic correction is conservative,
off by default, EN/RU-only, Space-boundary-only and fails closed in secure,
unknown, terminal, IDE, remote-control and input-method contexts.
Undoing an automatic correction adds the token to a 200-entry memory-only
ignore list until restart.

### Settings, shortcuts and lifecycle

- `RuntimeIdentity.swift`: debug-only preview label and persistent bundle
  fallback for isolated QA data; production ignores the override.
- `AppDelegate.swift`: native Close/Command-W and configured history/snippet
  commands, refreshed after shortcut changes.
- `Settings.swift`: normalized local preferences, mandatory password-manager
  capture exclusions and a 200-entry per-app layout map plus a separate bounded
  fixed-layout map with explicit reset.
- `ShortcutDescriptor.swift`, `ShortcutRecorder.swift`, `GlobalHotKey.swift`,
  `HotKeyCoordinator.swift`: five transactional, conflict-safe native hotkeys.
- `PreferencesWindow.swift`: General, Keys, Privacy, Layout and Data.
  AppKit owns the noncustomizable toolbar; `PreferencesNavigation` commits numeric
  drafts before navigation/close/quit without applying partial typed numbers.
  The title follows the active pane; zoom/minimize are disabled while resizing
  remains available. Secondary layout-memory controls use progressive disclosure.
- `OnboardingWindow.swift`: permission explanation and recovery.
- `AppMetadata.swift`: human-readable source application metadata.
- `UpdateChecker.swift` (1.12.0 release): shared observable update state,
  running-bundle identity, validated dated cache and explicit-only GitHub check.
  Ephemeral transport refuses redirects and bounds the response while streaming.
- `PreferencesWindow.swift` adds the candidate Version pane; About and the
  update menu route to it. Only the check action starts a request; opening the
  pane or reading saved status does not. No modal update-result window remains.

## Data invariants

1. Menu/history queries never load original image or RTF BLOBs.
2. Ordinary history is bounded by count, optional age and 250 MB total storage.
3. Previously pinned clips and snippets are not trimmed as ordinary history;
   there is no new pin-creation UI, and explicit unpinning itself never trims.
4. Full-data deletion removes clips, snippets and folders in one transaction.
5. A temporary pasteboard is restored only if no other process changed it.
6. Sensitive-content decisions happen before persistence.
7. Automatic correction never writes typed tokens to disk or the pasteboard.
8. A conflicting shortcut never replaces the previous working registration.
9. Partial/quit cleanup never removes pins or snippets.
10. Per-app layout memory does not enable or depend on automatic key monitoring.
11. Append-next is consumed only by accepted text and never loses a valid copy
    when the combined value exceeds the per-record limit.
12. A fixed per-app input source overrides last-used memory only on activation;
    a temporary manual layout change remains possible until reactivation.
13. Password-manager capture exclusions are mandatory, case-insensitive and
    apply to both immediate source checks and delayed app-transition checks.
14. Snippet JSON is bounded before decoding; importing remains merge-only and
    transactional.
15. Menu/editor snippet lists never retain complete bodies; paste and editing
    fetch exactly one full snippet by identifier.
16. Secret scanning must first detect generated GitHub, AWS and Slack canaries,
    then scan the publishable tree, HEAD history and side-ref-only commits.
17. Menu selection is native, with no custom search field or query tasks;
    Settings/Quit remain reachable in empty menus and normal browsing.
18. Deferred keyboard activation captures the destination with the selected
    item, never reads a later menu's target; old completions do not clear it.
19. Full data erasure drops editor drafts, undo payloads, menu snapshots and
    sequential-paste state as well as database rows.
20. No snippet expansion silently truncates output or recursively expands
    clipboard text.

## Verification map

- Storage/migration/performance: `StorageTests`, `SearchRetirementTests`.
- Privacy/pasteboard: `PrivacyLogicTests`, `CapturePreferencesTests`.
- Layout: `LayoutCorrectionTests`.
- Hotkeys: `ShortcutDescriptorTests`, `HotKeyCoordinatorTests`.
- Menu/app-mode contracts: `ApplicationModeContractTests`,
  `MenuPresentationTests`, `MenuSimplificationContractTests`.
- Snippets/selected-item actions: `SnippetTransferTests`, `LegacyPinRetirementTests`,
  `HistoryItemActionsTests`, `SnippetsEditorTests`, `StorageSnippetDiscoveryTests`,
  `SnippetRenderingBehaviorTests`.
- Release/update/security: `UpdateManifestTests`,
  `SecretScanningContractTests`, `scripts/secret-scan.sh`, `build-app.sh`.
- Release 1.12.0: `UpdateStateTests`, `UpdateTransportTests`,
  `HotPathOptimizationTests`, `HotPathBenchmarks` and the six-pane navigation
  contract. Local results and measurement limitations are recorded in its audit;
  no current release gate is implied by the existence of these tests.
- `Package.swift` applies `-Osize` only to release builds of the NeClip executable;
  GRDB keeps normal `-O`. `DistributionSizeContractTests` protects this scope and
  safety flags. CI includes strict release tests in addition to debug checks.

## Release gate

Run the full suite, strict Swift 6 complete-concurrency release build,
sanitizers, JSON validation, full-history secret scan and isolated visual QA.
Publishing additionally requires Developer ID signing, notarization, stapling,
Gatekeeper checks on the exact mounted DMG and independent SHA-256 verification.
Source changes, a local build or a local commit are not a release.
