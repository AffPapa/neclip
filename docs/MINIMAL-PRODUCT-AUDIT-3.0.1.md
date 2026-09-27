# Clipboard-only depth audit — 3.0.1 candidate

The audit reviewed architecture, native Swift execution, privacy, settings UX, concurrency, data preservation and release surfaces. Three independent read-only reviewers covered separate concerns; the parent integrated changes and verification.

## Removal boundary

All 15 screenshot/layout production files removed in 3.0.0 remain absent. None of their 64 top-level types is referenced by current production sources. No ScreenCaptureKit, screen-capture permission request, input-monitor/event-tap listener, TIS input-source switching, or AXUIElement selection-reading route remains. Build resources contain no retired feature payload. Carbon hotkeys, Cmd-V CGEvents and ImageIO remain required by the clipboard product.

The 14 retired preference keys match their actual historical writers. Startup clears only those keys. Database schemas, user records, image/file history, snippets, privacy controls, backups and remaining shortcuts are preserved. Historic release records and the two noindex retirement notices remain historical evidence rather than active feature claims.

## Confirmed defects and changes

- **Sequential paste ownership:** two overlapping requests previously shared one clip ID. An earlier failure could clear ownership before a later success, leaving the same item next. Reset/expiry could also accept stale completion for a new operation with the same ID. Each attempt now has unique ownership, busy presses do not start a second write, fetch errors release ownership, and stale/duplicate completions are rejected.
- **Exact settings:** an exact limit such as 10 or 1,000 was displayed as the nearest preset (50 or 500). The picker now shows the actual value without rewriting it.
- **Permission truthfulness:** privacy status previously showed active recording whenever not paused, even when macOS denied access. Text and icon now reflect permission plus pause state.
- **Update status:** the settings footer no longer labels a cached old manifest as current latest. It uses the updater's checked-state/failure text with check date in help.
- **Data counts:** SwiftUI previously queried history and fetched every snippet summary merely to count during body rendering. A single consistent SQL count read now runs off the main actor while the section is visible; notifications are coalesced and cancelled view tasks cannot publish stale results.
- **Less code and fewer repeated choices:** removed unused pagination/count helpers, impossible history-overflow state, and duplicated pause/skip/access actions inside the status submenu. Recovery remains reachable through the main history menu and Access settings. Backup labels describe both history and snippets.

## Acceptance and limits

Retain five visible settings sections, three global shortcuts and local-only clipboard/snippet scope. Test ownership overlap/retry/reset/expiry, full data counts beyond menu bounds, selective preference migration and existing data/undo/privacy behavior. Validate native settings using isolated synthetic data. Performance comparisons concern only the measured count query, not total launch/menu latency. No claim of universal cross-app paste, every supported macOS version, or VoiceOver audio certification.

Release-specific test results, signed artifact pins, publication and installed-app evidence are recorded separately after those gates complete.

## Local results

Strict debug and optimized release, AddressSanitizer and ThreadSanitizer each passed 286 XCTest (9 expected opt-in skips), plus 4 Swift Testing checks. Site tests passed 14 tests/45 assertions; SEO tests passed 18/52. A native isolated preview confirmed the exact 350-item custom limit, all five settings sections, three global shortcuts, asynchronous counts, backup copy, access explanations and status submenu without duplicate controls. The preview used synthetic history/snippets and capture remained locked off.

Synthetic release microbenchmark: in-memory SQLite with 2,000 short synthetic snippets, 100 warmed iterations, same fixture for old summary materialization and new SQL counts. Old p50 4.747625 ms / p95 5.453875 ms; new p50 0.017708 ms / p95 0.026875 ms. Setup is excluded. This measures count operations, not UI latency or a whole-app speedup. Environment: Apple Silicon, macOS 27, Xcode Swift 6.4.
