# NeClip 2.0 rethink loop

## Outcome

Turn NeClip from a feature-rich clipboard archive into an invisible contextual
memory: one menu, three visible zones, three understandable settings questions,
and no extra permission or cloud service in the default path.

## Scope

Included: current UX/settings audit, analogue research, safe architecture
reduction, menu and settings simplification, performance measurements, tests,
release and rollback evidence.

Excluded: accounts, cloud sync, AI, telemetry, macro scripting, global
keystroke-driven text expansion, unrelated repository/services, and permanent
database deletion without a migration/rollback proof.

## Gates

1. Research and baseline gate: this plan and `docs/NECLIP-2.0-VISION-2026-09-08.md`.
2. P0 implementation gate: menu/settings contracts and safety preservation.
3. P1 polish gate: native UX, wording, accessibility and measured latency.
4. Delivery gate: full tests, strict/sanitizers, secret scan, artifact,
   notarization, Pages/release sync, install and rollback evidence.

## Stop guards

- Do not delete migrations, safety barriers or tests to hit a line-count target.
- Stop a slice if it changes persisted keys or database schema without a
  forward/reopen/rollback test.
- Stop publication if source, checksum, website or installed identity disagree.
- Revisit after each slice; no more than three revisions of one UX slice without
  a new measurement or a human wording decision.

## Current baseline

- Source: `.work-neclip-ui`, public 1.14.0/build 21.
- Runtime: 10,351 physical / 9,384 nonblank non-comment Swift lines.
- Tests: 5,193 physical Swift lines.
- Settings sections: 6. Legacy storage compatibility remains protected.
