# NeClip project map

Updated: 1 September 2026. This is the source map for the current unreleased
tree. Public release metadata remains pinned to 1.4.0 until the release gate is
completed.

The matching evidence report is `AUDIT-1.6.2-2026-09-01.md`; competitor
matrices, the 100-item catalogue and top-20 decisions are in
`RESEARCH-1.6.0-ZERO-2026-09-01.md`.

## Product boundary

- Native macOS 14+ menu-bar utility; `LSUIElement=true`, no Dock icon.
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
- `Storage.swift`: migrations, SHA-256 deduplication, retention, byte quota,
  FTS and atomic persistence.

### Menu and paste

`StatusBarController` owns both entry points: status-item click and global
history/snippet shortcuts. Both build the same native `NSMenu`, apply the same
effective appearance and use lightweight `ClipSummary`/`SnippetSummary` rows.
The ordinary and pinned browse windows are capped at 100 each; the menu snippet
projection is capped at 200 and every content preview at 280 characters. Full
local history and snippet bodies are fetched only for the chosen action.

- `MenuPresentation.swift`: single-line, grapheme-safe menu titles.
- `ClipboardSearch.swift`: ordinary and structured search, smart categories,
  bounded fuzzy fallback.
- `PasteService.swift`: direct/plain/copy-only paste and lossless,
  compare-and-swap restoration of a temporary pasteboard; an unreadable
  advertised representation aborts before clearing. Paste-and-delete proceeds
  only for an unpinned record after the direct-paste result.
- `HistoryItemInspector.swift`: preview, rename/edit, safe open and OCR paste.
- `TextTransform.swift`: deterministic local transforms.
- `SequentialPasteSequence.swift`: memory-only stable IDs for `Control-Command-V`.

### Snippets

`SnippetsEditor` reads lightweight summaries for folders, search, empty folders
and **Unfiled**, then fetches one full body when selected. Selection, navigation
and termination flush pending drafts; failed saves remain visible. Local writes
and imports share title, keyword and 2 MB content bounds. `SnippetRenderer`
expands only local
`{date}`, `{time}` and `{clipboard}` placeholders. `Storage` provides versioned
JSON export and atomic merge-only import without history or usage metadata;
empty and over-16 MB import files are rejected before JSON decoding.

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

- `Settings.swift`: normalized local preferences, mandatory password-manager
  capture exclusions and a 200-entry per-app layout map plus a separate bounded
  fixed-layout map with explicit reset.
- `ShortcutDescriptor.swift`, `ShortcutRecorder.swift`, `GlobalHotKey.swift`,
  `HotKeyCoordinator.swift`: five transactional, conflict-safe native hotkeys.
- `PreferencesWindow.swift`: General, Keys, Privacy, Layout and Data.
- `OnboardingWindow.swift`: permission explanation and recovery.
- `AppMetadata.swift`: human-readable source application metadata.
- `UpdateChecker.swift`: explicit-only, GitHub-bound update check.

## Data invariants

1. Menu/history queries never load original image or RTF BLOBs.
2. Ordinary history is bounded by count, optional age and 250 MB total storage.
3. Pins and snippets are not trimmed as ordinary history.
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

## Verification map

- Storage/search/performance: `StorageTests`, `ClipboardSearchTests`.
- Privacy/pasteboard: `PrivacyLogicTests`, `CapturePreferencesTests`.
- Layout: `LayoutCorrectionTests`.
- Hotkeys: `ShortcutDescriptorTests`, `HotKeyCoordinatorTests`.
- Menu/app-mode contracts: `ApplicationModeContractTests`,
  `MenuPresentationTests`.
- Snippets/transforms/actions: `SnippetTransferTests`, `TextTransformTests`,
  `HistoryItemActionsTests`.
- Release/update/security: `UpdateManifestTests`,
  `SecretScanningContractTests`, `scripts/secret-scan.sh`, `build-app.sh`.

## Release gate

Run the full suite, strict Swift 6 complete-concurrency release build,
sanitizers, JSON validation, full-history secret scan and isolated visual QA.
Publishing additionally requires Developer ID signing, notarization, stapling,
Gatekeeper checks on the exact mounted DMG and independent SHA-256 verification.
Source changes, a local build or a local commit are not a release.
