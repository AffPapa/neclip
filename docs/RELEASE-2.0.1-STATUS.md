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
The final arm64 DMG is 1,984,962 bytes with SHA-256
`0e8d8e6f057b025d9bc9721f7edb9a99ec40f7d4e2fb61717ec08574df798752`.

The gate passed 247 XCTest cases with 4 expected skips, 3 Swift Testing
checks, strict Swift 6 warnings-as-errors release build, Developer ID signing,
app and DMG notarization, stapling, Gatekeeper and mounted-DMG validation.
The full repository history and publishable tree were scanned with gitleaks;
no secrets were found.

The notarization submissions were accepted by Apple:

- app ZIP: `afc406f5-7338-459f-bc3b-1195a2b6414f`;
- DMG: `ff02d115-7b81-434d-9182-dca66e6dfa6e`.

Rollback target: the preserved local NeClip 2.0.0 build 22 copy in the macOS
Trash and the immutable 1.14.0 GitHub release.
