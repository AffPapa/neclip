# NeClip 1.5.0 product loop

## Objective

Research current clipboard managers and keyboard-layout tools, compare their
useful local-first patterns with the actual NeClip tree, then implement one
coherent, minimal, keyboard-first 1.5.0 source release without accounts, cloud,
telemetry, AI or a permanent Dock/main window.

## Professional roles

1. Desktop-product researcher: primary-source competitor matrix and explicit
   add/defer/reject decisions.
2. macOS privacy and input engineer: permissions, TIS, Accessibility and
   fail-closed keyboard behavior.
3. Swift 6/AppKit engineer: bounded capture, native menu, lifecycle and local
   persistence.
4. Keyboard-first UX reviewer: the smallest discoverable settings and actions.
5. Release-quality engineer: tests, strict compilation, sanitizers, secret scan
   and visual QA.

## Invariants

- Menu-bar only; `LSUIElement=true`; no Dock icon.
- Local storage and local processing only.
- Automatic typing observation remains explicit, default-off and protected.
- Per-application layout memory must not read typed text or request Input
  Monitoring.
- Pinned history and snippets survive ordinary/partial cleanup.
- Public 1.4.0 metadata and `/Applications/NeClip.app` remain unchanged until a
  separate signed/notarized release instruction.

## Stop rule

Stop only after the selected source slice, documentation, complete local gates
and a repeat audit pass. Do not claim a public release from a local source
commit.
