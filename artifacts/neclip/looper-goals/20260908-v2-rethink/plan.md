# Plan

## P0 — visible complexity and correctness

1. Freeze the three-zone menu contract and remove any remaining retired visible
   labels/actions.
2. Reduce Settings to How it works, Shortcuts and Safety & privacy; keep legacy
   storage keys behind compatibility accessors.
3. Make snippets title/text/folder-first and preserve failed drafts.
4. Keep automatic layout correction opt-in and progressively disclosed.
5. Add keyboard and appearance contract tests before moving code.

## P1 — measured polish

6. Unify retention controls and wording. 7. Add accessibility identifiers and
   focus-order QA. 8. Measure cold launch, menu-open and paste latency. 9.
   Remove proven dead adapters only after `rg`/typecheck evidence.

## P2 — release

10. Run full debug/strict/ASan/TSan, gitleaks all refs, public release/site
    consistency, notarization, install, rollback and clean-room verification.

## Verification matrix

Programmatic: `swift test --disable-sandbox`, strict Swift 6 release build,
sanitizers, `ruby scripts/verify-site.rb`, `git diff --check`, gitleaks and
release-size/latency scripts.

Judge: menu can be understood without search, the first useful paste takes one
shortcut plus Return, and settings answer “how it works / keys / safety”.

Human: final wording and the removal of rarely used controls are accepted by
the product owner before public 2.0 publication.
