# NeClip 1.6.2 second zero-based audit

Objective: repeat the complete retained-history, source, performance and
repository-security audit from a clean baseline; fix the highest-confidence
correctness and hot-path gaps; remove only code proven obsolete; and leave a
reproducible local release candidate without publishing or replacing the
installed application.

## Invariants

- Local, menu-bar-only, no account, cloud, telemetry, ads or remote AI.
- Manual layout correction remains primary; automatic correction stays
  conservative, optional and default-off.
- Password-manager clipboard capture always fails closed.
- Old migrations and research remain when they provide compatibility or
  evidence; source is removed only with positive reachability proof.
- No Git history rewrite without a confirmed leak and a separate destructive
  gate.
- Public 1.4.0 metadata and `/Applications/NeClip.app` remain untouched.

## Stop condition

Stop when the selected security/correctness/performance slice passes every
available test, strict Swift 6 build, sanitizer build, deterministic secret
scanner self-test, complete-ref scan and repository-integrity check; otherwise
name the exact external blocker and preserve a resumable state.
