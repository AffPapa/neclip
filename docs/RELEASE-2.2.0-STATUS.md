# NeClip 2.2.0 release status

Released 9 September 2026 from commit `cc4a02896f8de9689941e8a2a5d5f6607e277ce6`.

## Product change

- History remains the primary chronological menu surface.
- Snippet folders remain directly below history in the same menu.
- Low-frequency controls are grouped under `Ещё…`.
- Per-application layout pinning is no longer exposed in the menu. Legacy
  metadata remains migration-compatible and is not deleted from user databases.

## Verification

- 247 XCTest: pass; 4 opt-in tests skipped.
- 3 Swift Testing checks: pass.
- Swift 6 strict release build with warnings as errors: pass.
- Developer ID signing, app and DMG notarization, stapling, Gatekeeper and
  mounted-DMG verification: pass.
- Artifact: arm64 DMG, SHA-256
  `56d00d9ed8e88ff281c65a5f604478e788f8c3dd2fcaa332f472ed2ed9f8c8bb`.

The previous 2.1.0 release remains the rollback target until the new build is
verified on the user's Mac.
