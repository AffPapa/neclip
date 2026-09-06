# NeClip 1.9.0 simplification loop

Baseline: eaea2d59aeb595cf3ac51d1d04ca372f39373253, 11,669 physical runtime
Swift lines / 10,430 nonblank, non-line-comment lines; tests 4,029 lines.
The 30% target means 3,501 runtime lines, not deletion of tests or documents.

## Plan gate: passed

Three independent read-only audits (architecture, performance, UX) completed
before implementation. Evidence supports safe consolidation, not removing
30% of this runtime without losing behavior or safeguards. No minification,
test deletion, migration removal, or new dependencies to conceal code size.

## Ordered delivery

1. P0: unblock pending 1.8.0 website PR7 by replacing version-pinned manifest
   assertions with valid-version and matching owned-download contracts; add
   mismatch regression, retain hostile URL coverage.
2. P1 architecture: shared bounded layout-map writes and shortcut persistence.
3. P1 performance: metadata-only OCR/pin updates, empty-rule fast return,
   early text-size rejection, shared safe SQL where justified. Synthetic
   before/after benchmarks, no real clipboard fixtures.
4. P1 menu: shared pagination, skip cancelled queued search, preserve exact
   event/target/generation and privacy semantics.
5. P1 UX: visible folder creation, accurate Russian copy, common limits stay
   visible; move rare explanations to disclosures without changing defaults.
6. Verify targeted and full tests, strict release, sanitizers, isolated UI,
   full-ref secret scan, public metadata contracts and source-size delta.
7. Checkpoint before publication; signed/notarized exact artifact, CI/CodeQL,
   GitHub release, public-download verification, website/manifest, safe local
   replacement with data backups and automatic rollback.

## Boundaries / stop rules

No accounts/cloud/telemetry/external AI; no real user-data tests; keep macOS14,
arm64 and existing database/preferences migration compatibility. No forced Git
push or weakening required checks. Two review/fix passes per slice before
re-scoping a risky change. Final report must distinguish measured speedups,
structural improvements, unverified UI scenarios and deferred opportunities.

## Checkpoint: source and local QA

- PR7 merged after all required checks; 1.8.0 public site/manifest verified live.
- Steps 2–5 implemented, independently re-reviewed and regression-tested.
- Runtime source: 11,570 lines / 465,121 bytes, down 99 lines (0.85%).
- Strict release suite: 222 passed, one external-database opt-in skip.
- Synthetic baseline/after fixture matches; results and limits recorded in
  `docs/AUDIT-1.9.0-2026-09-06.md`.
- Minimum-size isolated Settings/editor QA passed the documented scenarios.
- Remaining in progress: final sanitizer/security gates and step 7, including
  publication, public-download verification, website and safe installation.
