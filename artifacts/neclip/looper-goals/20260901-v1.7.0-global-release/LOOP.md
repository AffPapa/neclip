# NeClip 1.7.0 global release loop

Date: 1 September 2026

## Outcome

Turn the current local 1.6.2/build 12 source into the next minimal, fast,
privacy-first public NeClip release, with the application, GitHub repository,
GitHub Pages project site and update feed agreeing on one verified version.

## Included

- Complete product, UX, accessibility, code, performance and security audit.
- Repair of proven P0/P1 gaps without expanding the account/cloud boundary.
- Full Swift 6, sanitizer, signing, notarization and update verification.
- Public GitHub release, Pages update and post-release smoke checks.

## Excluded

- Accounts, cloud sync, telemetry, ads and remote AI.
- A Dock icon or permanent large workspace window.
- Destructive Git-history rewriting without a confirmed secret.
- New permissions or broad automatic behavior without a proven need.

## Verification types

- Programmatic: tests, strict builds, sanitizers, static checks, secret scans,
  artifact hashes, signing/notarization/Gatekeeper, HTTP and update-manifest
  checks.
- Judge: three independent read-only product/code/security audits and a final
  simplicity review.
- Human: only unavoidable Apple credential prompts or subjective visual taste;
  neither can replace programmatic release evidence.

## Gates

1. Plan gate: source map, public state, 100-point plan and three audits exist.
2. Delivery gate: every accepted P0/P1 has a targeted regression test.
3. Release gate: full suite, strict release, sanitizers and repository security
   checks pass on the exact release commit.
4. Publication gate: exact signed/notarized artifacts, release metadata and
   Pages source agree.
5. Live gate: public downloads, hashes, Gatekeeper and in-app update checks are
   independently verified.

## Stop guards

- Success: all 100 items are completed, explicitly rejected with evidence, or
  deferred with a documented non-release reason; every mandatory release gate
  is green.
- No-progress: stop after three repeats of the same external blocker and leave
  a resumable evidence artifact instead of claiming completion.
- Safety: never print credential values; never force-push merely to make a scan
  look clean.
