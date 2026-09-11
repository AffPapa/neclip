# NeClip full audit loop

Goal: ship the smallest safe NeClip release that fixes verified P0/P1 defects while preserving the keyboard-first local-only product boundary.

## Scope

- Included: source, tests, resources, scripts, docs, distribution artifacts, installed app evidence, GitHub release/PR/Pages state.
- Protected: user clipboard/snippet data, Keychain material, signing credentials, unrelated branches/worktrees, required CI checks.
- Excluded unless evidence requires it: cloud/accounts/telemetry/AI, broad redesign, destructive Git history rewrites.

## Gates

1. Baseline inventory and dependency/call-site map.
2. P0/P1/P2 audit with reproducible evidence.
3. Narrow implementation plus regression tests.
4. Debug, strict Swift 6, static/security, sanitizer and release checks.
5. Backup, signed/notarized build, atomic install and native smoke.
6. Required CI, immutable GitHub release and cache-busted public-site verification.
7. Repeat audit and evidence report.

## Stop guards

- Do not publish or install when tests, signing, notarization, Gatekeeper or required CI are not green.
- Do not print or copy user clipboard data or credentials into repository artifacts.
- Stop a revision path after two non-progressing attempts and record the blocker.
- Keep rollback assets until live verification completes.

