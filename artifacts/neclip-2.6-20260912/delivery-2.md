# Delivery 2 — candidate and release gates

## Verified

- Candidate version is NeClip 2.6.0, build 38; public manifest remains 2.5.8 until publication.
- Exact reviewed code commit: `3aa11db` (the final release commit will include this reviewed code plus its evidence metadata).
- Full debug tests: 285 XCTest, 5 expected skips, 0 failures; three Swift Testing tests passed.
- Strict Swift 6 release build with warnings-as-errors passed on the reviewed code.
- Local metadata/link verification passed.
- Search read-time benchmark passed at 100, 500 and 2,000 synthetic rows without persistent indexing.
- Physical isolated UI smoke passed for the 2.6.0 Data preferences window, backup
  Save panel, synthetic screenshot editor, PNG/JPEG format selector and screenshot
  Save panel; all dialogs were cancelled without writing user files.

## Not yet claimed

- Mixed display scale, multiple monitors, Spaces/fullscreen and denied Screen
  Recording matrix are not claimed: this host exposed one active display and the
  release UI-test bundle is isolated from those hardware/permission variants.
- Developer ID signature, Apple notarization, stapling, Gatekeeper and mounted-DMG verification.
- GitHub Release, Pages publication and anonymous live artifact/hash verification.

## Blockers

The configured release script uploads the app/DMG to Apple notarization and uses
Apple credentials. The safety reviewer stopped that external transfer until the
owner explicitly authorizes it. Existing personal backup files outside the
worktree were left untouched because changing their permissions or deleting them
is a separate protected action.
