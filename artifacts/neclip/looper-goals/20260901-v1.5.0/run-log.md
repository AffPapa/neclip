# Run log

## 2026-09-01 — read-only discovery

- Confirmed clean `codex/neclip-product-reset` at `bf1868c`.
- Reviewed 18 clipboard products and 19 keyboard-layout products.
- Classified layout tools as manual conversion, automatic word correction or
  per-application input-source memory.
- Audited current capture, storage, menu, settings, layout, lifecycle and tests.
- Selected a six-capability source slice; rejected boards, accounts, sync, AI,
  scripts, telemetry and aggressive multi-language autocorrection.

## Verification log

### Implementation

- Added bounded text-record capture, partial and on-quit cleanup, safe
  paste-and-delete, per-app input-source memory and session ignore after an
  automatic-correction undo.
- Updated source version to 1.5.0/build 9 while leaving public 1.4.0 metadata,
  release assets and the installed app unchanged.
- Updated README, changelog, backlog, machine-readable feeds, project map,
  research and the 1.5.0 audit.

### Gates

- Final normal suite: 111 XCTest plus eight Swift Testing cases; zero failures,
  one opt-in external-database XCTest skipped.
- Strict Swift 6 complete-concurrency release build with warnings as errors:
  passed.
- Complete AddressSanitizer and ThreadSanitizer runs: passed.
- Official checksum-verified Gitleaks 8.30.1 scan: publishable tree and all 26
  commits clean.
- JSON, 100-item catalogue sequence, version separation and diff checks:
  passed.
- Isolated native visual QA: onboarding, Settings General/Layout and snippet
  editor passed without changing `/Applications/NeClip.app`.
