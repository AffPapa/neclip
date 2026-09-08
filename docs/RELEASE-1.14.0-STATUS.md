# NeClip 1.14.0 / build 21 — release status

## Product change

NeClip 1.14 keeps the immediate-use, menu-bar workflow and adds a small
contextual working set:

- **В работе** shows at most five clips from the current frontmost application
  and snippets that were actually used before;
- ordinary chronological history and direct snippet folders remain the
  fallback, with duplicate focus clips removed from the visible history;
- `⌘1`–`⌘5` paste the corresponding focus item without opening another window;
- the feature reuses existing local metadata and permissions. It adds no
  account, cloud sync, network state, migration, search, pin UI, telemetry or
  AI processing.

## Release gates

The exact source commit is
`dd7c5296b6149eea3ae39dce8e0fa3524d6b66ba` (merge of PR #17).
The arm64 DMG is 1,976,259 bytes with SHA-256
`4a83324e8ddc69c6efd24edb879b5f3caaea5b409bc149994790d9f6849c12f6`.

The gate passed 250 XCTest cases with 4 expected skips, 3 Swift Testing
checks, strict Swift 6 warnings-as-errors release build, Developer ID signing,
app and DMG notarization, stapling, Gatekeeper, and mounted-DMG validation.
The publishable tree and repository history were scanned for secrets; site,
manifest, checksum and release metadata were checked before publication.

Notarization submissions were accepted by Apple:

- app ZIP: `7e59cca4-a322-41ba-9a49-ac1f5cd72199`;
- DMG: `882674d9-38f1-49c7-a65e-0397b1d3e643`.

Rollback target: the immutable NeClip 1.13.0 release.
