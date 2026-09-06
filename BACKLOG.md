# Public backlog

NeClip deliberately stays small: fast local history, snippets and safe keyboard
layout correction. Accounts, cloud sync, subscriptions, telemetry and AI are
not planned.

## Done in 1.3.0

- Native menu-bar history and snippet sections
- Search, keyboard-first paste and quick selection
- Pins, local OCR, FTS5 and bounded storage
- Privacy controls, exclusions, pause and ignore-next-copy
- Manual and conservative automatic EN/RU layout correction
- macOS pasteboard authorization UX and fail-closed denial
- Swift 6 strict concurrency and one pinned dependency
- Hardened signed/notarized DMG pipeline
- Standalone GitHub Pages project landing

## Done in 1.3.1

- Repository-owned GitHub Pages update manifest with strict GitHub Release URL
  validation
- Machine-readable GitHub source-of-truth index for website integrations
- Removal of the obsolete AffPapa landing implementation from this repository

## Done in 1.3.2

- Pin/unpin, save-as-snippet, individual delete and exact undo in the native
  menu, with search-first keyboard commands
- Visible explanation when a global shortcut is already occupied
- Single storage-driven menu refresh path and removal of the unused large window
- Weekly dependency updates plus immutable releases, CodeQL, vulnerability
  alerts and action SHA enforcement
- Private vulnerability reporting and a public bug form that forbids real
  clipboard contents

## Done in 1.4.0

- One system appearance for status-item and global-hotkey menus
- User-defined 16–96 character menu labels with grapheme-safe ellipsis
- Conflict-aware shortcut recording for manual layout correction and the new
  off-only automatic-correction safety action
- Visible snippet folders, empty and unfiled sections, folder CRUD and moving
  snippets between folders
- Draft-safe autosave that flushes before navigation and window close and keeps
  failed edits available for retry

## Done in 1.8.0 / build 14

Published 5 September 2026. Its matching public manifest and website update
were delivered in PR #7. Earlier 1.7 and 1.6 source
milestones below are included in this release, not separate pending releases.

- [100 recommendations and 27 selected refinements](docs/RESEARCH-2026-09-05.md)
- Folder-first shortcut, right-click access, direct editing and stable folder context
- Duplicate, deletion undo, keyboard-first creation/search and full-erasure draft cleanup
- Literal/folder-aware search, exact-key priority before LIMIT and safe pending results
- Consistent Settings/Quit footer and replacing mutually exclusive search filters
- Clean-editor external refresh, whole-folder counts and quick-snippet usage refresh
- Individual hotkey reset, live settings, numeric Escape and precise modifier help
- Normalized protected layout identities and system/self exclusions
- Bounded nonrecursive placeholders with ISO formats/literal escaping
- CRLF-aware line cleanup and correctly scoped URL component encoding

### Earlier source milestones included in 1.8.0

- Source 1.7.0/build 13 improvements, now shipped in 1.8.0
- Native snippet-list selection and visible-order arrow navigation, debounced
  search and a query-aware empty state
- A shorter root menu with low-frequency actions under **Management**, plus
  exact recent-application filters with readable names
- Distinct pending/denied pasteboard permission states and recovery actions
- Off-main Data operations, bounded image previews, newest-pending OCR and
  coalesced layout-context refreshes
- FTS triggers that ignore metadata-only writes and semantic search that pages
  beyond the newest 200 rows
- Race-free clear-on-quit, a native application-menu Quit command and removal
  of the unsafe paste-and-delete workflow
- Build-number-aware updates and a provenance-bound, atomic local release
  pipeline with pull-request ref secret scanning
- Self-verifying secret scanning with generated canaries plus explicit HEAD and
  side-ref-only history scans
- Source 1.6.0–1.6.2/builds 10–12 improvements, now shipped in 1.8.0
- Lightweight 280-character snippet projections in menus, search and editor;
  complete bodies load only for the chosen snippet
- Local snippet field limits matching portable import, without loading JSON or
  complete libraries into presentation state
- Latest-copy RTF semantics: a newer plain-text copy cannot paste old styling
- Lossless fail-closed pasteboard snapshots for manual selection replacement
- Fewer redundant Accessibility reads in automatic correction while retaining
  sequence locks, whole-value CAS, verification and rollback
- Immutable case-insensitive password-manager capture protection with readable names
- One-click capture exclusion/restoration for the application that opened the menu
- Pre-decode size limit for snippet JSON imports
- Removal of five proven unreachable source members
- Space preview when search is empty without stealing spaces from real queries
- One-shot append of the next accepted text to recent unpinned text
- Fixed per-application input source with priority over last-used memory
- Set-based SQLite byte-quota trim instead of loading and deleting rows one by one
- Normalized and deduplicated clipboard/layout application exclusions
- User-bounded 64–2048 KB text records
- Last-hour/today/all-unpinned cleanup and optional fail-closed cleanup on quit
- Per-application last-used input source without keyboard-event monitoring
- Bounded session ignore after undoing a false automatic correction
- Reset and visible count for up to 200 remembered application layouts
- Direct recent-history sequential paste without a collection mode
- Configurable, conflict-safe history, snippet and sequential-paste shortcuts
- Five concise Settings sections instead of one long form
- Matching editable numeric controls for history size and menu-label length
- Immediately discoverable snippet editing with automatic initial selection,
  full-row edit actions and explicit autosave status
- Always-enabled native Quit command with draft-safe snippet termination
- Bounded browsing for 100 recent and 100 pinned values, with full search for
  older local history
- Native magnifier menu for common structured-search filters
- A bounded 200-snippet menu projection with complete on-demand search/editing
- One-transaction erasure of history, snippets and their folders
- Human-readable source application names in the item inspector
- Simpler search/action labels and removal of obsolete paste compatibility code

## Done in 1.9.0 / build 15

Published 6 September 2026 after CI/CodeQL, notarization and independent
public-download verification. [Release evidence](docs/RELEASE-1.9.0-STATUS.md).

- Metadata-only OCR and pin updates that avoid loading or rebinding original
  image and RTF payloads while preserving byte accounting and capacity checks
- Fast path for text capture when no sensitive-phrase rules are configured
- Shared history/snippet SQL, shortcut and layout preference persistence, and
  menu pagination helpers
- Cancellation of superseded pending menu searches before database work starts
- Simpler Settings wording and an explicit folder-creation button

## Next

- Verify first-run pasteboard wording across currently supported macOS releases
- Expand local layout pairs only when system-layout tests can keep false fixes low
- Repeat measured menu latency before changing the bounded 100-history and
  200-snippet browse windows
- Consider manual drag ordering only if folder counts grow beyond the current
  compact section model

## Not planned

- Accounts or cloud synchronization
- Cross-device clipboard transport
- Analytics, telemetry or advertising
- AI processing of clipboard contents
- A permanent Dock icon or a large workspace-style main window
