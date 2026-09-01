# NeClip 1.6.1 history, code and security cleanup

Objective: reconcile the complete retained research/backlog with the current
source, close the highest-value coherent privacy/UX gap, remove only proven
dead code, and repeat code, repository and release-quality verification without
publishing or replacing the installed application.

## Invariants

- Local, menu-bar-only, no account, cloud, telemetry, ads or AI.
- Password-manager clipboard capture fails closed and cannot be opted into.
- Old migrations, research and audits remain as compatibility/evidence.
- No history rewrite without a confirmed secret and a separate destructive gate.
- Public 1.4.0 metadata and `/Applications/NeClip.app` remain untouched.

## Stop condition

Stop when the selected privacy/UX slice and proven dead-code cleanup are green
under normal tests, strict Swift 6 release compilation, sanitizers, repository
security checks and isolated visual QA, or when a named external toolchain
blocker prevents the same gate from running.
