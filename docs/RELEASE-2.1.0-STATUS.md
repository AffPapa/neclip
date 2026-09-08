# NeClip 2.1.0 / build 24 — release status

## Product and performance scope

This release keeps NeClip's immediate-use, menu-bar-only product boundary:
one chronological local history, saved snippet folders directly in the menu,
no accounts, cloud sync, telemetry, search, pinning or Focus Stack.

The audit focused on the two hot paths that run on every normal interaction:

- menu opening reuses the already bounded history snapshot and a first-page
  slice instead of allocating two temporary arrays;
- history trimming checks the indexed unpinned count first and executes the
  ordered overflow delete only when the configured limit is exceeded.

The menu renderer also drops one duplicate warning-icon assignment. No schema,
permission, dependency, network or user-data behavior changed.

## Release gates

This file is intentionally completed only after the signed build. It will
record the exact reviewed source commit, DMG size and SHA-256, Apple
notarization identifiers, test totals, Gatekeeper/mounted-DMG evidence and
full-history secret scan result.

## Exact release evidence

The exact reviewed source commit is
`93a836dfc65a97c5e6d592f9d70b6629a63963bc`.
The public arm64 DMG is 1,985,474 bytes with SHA-256
`8292611f70706e696ad304afa884ed57a806dee3d43629e49046650abd1bbfc8`.

Apple accepted both notarization submissions:

- app ZIP: `1104dffb-5198-4398-b3c6-ff68605f8089`;
- DMG: `216d91fb-9d7f-40b5-8a13-16a1f2b57b09`.

The release passed 247 XCTest cases with 4 expected skips, 3 Swift Testing
checks, strict Swift 6 warnings-as-errors release build, ASan, TSan, Developer
ID signing, app and DMG notarization, stapling, Gatekeeper and mounted-DMG
validation. The full repository history and publishable tree passed gitleaks
with no secrets found.

The public [GitHub release](https://github.com/AffPapa/neclip/releases/tag/v2.1.0)
contains the exact DMG and checksum. The immutable previous 2.0.1 release is
the rollback target.
