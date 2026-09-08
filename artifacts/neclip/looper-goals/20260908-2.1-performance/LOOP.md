# NeClip 2.1 performance and clarity loop

## Working brief

Act as a senior Swift/macOS performance engineer, Apple UX reviewer and
release-security engineer. Audit the complete NeClip product, then implement
only changes with evidence of lower work, clearer behavior or lower risk.
Keep the product local, menu-bar-only and immediate-use: no accounts, cloud,
telemetry, AI or search.

## Scope

- inspect every production Swift file, settings/menu flow, storage projection,
  hot-key path, update path and release metadata;
- remove duplicate work and dead compatibility surface only when dependency
  checks prove it is unused;
- improve menu/settings logic without reintroducing hidden ranking or clutter;
- preserve migrations, privacy exclusions, pasteboard restoration, hot-key
  conflict safety and automatic-layout safety;
- release a new semver version only after the complete release gate passes.

## Verification types

- programmatic: Swift tests, strict Swift 6, release-size check, sanitizers,
  site/manifest contract, git diff check, gitleaks and Gatekeeper/notarization;
- judge: source-level review for one menu model, bounded reads, no accidental
  network on startup, and Apple-style settings copy;
- human: user smoke test of history, snippet folders, Settings footer and
  hotkeys after installation.

## Stop guards

- stop after one coherent 2.1 slice and its release gate;
- do not delete migrations or privacy/security code without a proven replacement;
- do not bypass required CI checks except the previously authorized temporary
  `Analyze (swift)` removal, and restore it immediately after merge;
- if the same external blocker repeats twice, preserve the verified local build
  and report the blocker instead of weakening another gate.
