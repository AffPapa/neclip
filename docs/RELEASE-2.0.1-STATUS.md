# NeClip 2.0.1 / build 23 — release status

## Product change

NeClip 2.0.1 completes the minimal immediate-use menu:

- history is one chronological list with the newest copy first;
- the duplicate **В работе**/Focus Stack projection is removed;
- saved snippet folders remain directly available from the menu;
- Settings shows the installed version and the latest checked GitHub version at
  the bottom, with an explicit refresh action;
- accounts, cloud sync, telemetry, search and new clipboard permissions remain
  outside the product boundary.

## Release gates

The exact source commit is
`292f637419a4bd06633675b973b546d5f15a70b1`.
The arm64 DMG is 1,984,963 bytes with SHA-256
`43bdffb962c887e9e040547cf0bdc0cf8a27d09934aa623907eab21e2526bd93`.

The gate passed 247 XCTest cases with 4 expected skips, 3 Swift Testing
checks, strict Swift 6 warnings-as-errors release build, Developer ID signing,
app and DMG notarization, stapling, Gatekeeper and mounted-DMG validation.
The full repository history and publishable tree were scanned with gitleaks;
no secrets were found.

The notarization submissions were accepted by Apple:

- app ZIP: `e30626af-d925-4838-ad7d-e2c8386f7c06`;
- DMG: `a423e427-9b46-4301-b88b-55d3cf6a8f6c`.

Rollback target: the preserved local NeClip 2.0.0 build 22 copy in the macOS
Trash and the immutable 1.14.0 GitHub release.
