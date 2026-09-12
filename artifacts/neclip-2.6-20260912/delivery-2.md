# Delivery 2 — candidate and release gates

## Verified

- Candidate version is NeClip 2.6.0, build 38; public manifest remains 2.5.8 until publication.
- Exact reviewed source commit: `f59a15fa1ae95814015b3593f801a5fdfcdd4ba0`.
- Full debug tests, strict Swift 6 build and local metadata/link verification passed.
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
