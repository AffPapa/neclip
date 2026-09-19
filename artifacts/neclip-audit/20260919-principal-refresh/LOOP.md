# NeClip principal refresh goal

## Outcome

Produce a smaller, faster, safer and more coherent NeClip release only where
current-source evidence proves an improvement. Preserve the local, menu-bar and
keyboard-first product boundary.

## Scope

Included: Swift 6/AppKit architecture, input and layout correction, menu and
settings UX, storage/search/screenshot paths, performance, accessibility,
security, build/release provenance and direct-distribution verification.

Excluded: accounts, cloud sync, telemetry, advertising, AI/OCR, App Store
distribution, reading or exporting user clipboard/history contents, unsupported
claims about physical keyboard events.

## Gates

1. Plan: current source, release state and independent audit findings recorded.
2. Delivery: each P0/P1 has a focused regression test and a measured or
   programmatic acceptance criterion.
3. Release: clean secret scan; full tests; strict Swift 6; artifact signing,
   notarization, stapling and Gatekeeper; protected PR checks; public DMG,
   Pages and exact update endpoint; rollback-safe local installation.

## Stop conditions

Ship only confirmed P0/P1 work. Defer speculative redesigns and unmeasurable
feature expansion to a dated backlog. Never bypass branch protection or replace
an installed app without a verified rollback copy.
