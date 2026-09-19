# Plan and acceptance criteria

## P0

- Input/layout data loss, security or privacy violation, crash/deadlock, release
  integrity failure. Acceptance: deterministic regression plus full release gate.

## P1

- Measurable typing/menu/storage latency regression, incorrect keyboard UX,
  inaccessible navigation, unsafe update/rollback edge. Acceptance: focused
  regression and benchmark or policy check.

## P2

- Visual redesign, speculative features and broad preference additions. Record
  only; do not ship in this pass.

## Evidence sources

- Current `main`, app source and test suite.
- Current public release/tag/Pages/update endpoint.
- Official Apple documentation plus primary competitor documentation/source.
- Three independent, read-only reviews: platform, UX/performance and release.
