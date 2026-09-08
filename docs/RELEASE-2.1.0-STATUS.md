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

The public 2.0.1 release remains the rollback target until every gate passes.
