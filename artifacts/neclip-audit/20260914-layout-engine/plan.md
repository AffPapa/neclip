# NeClip layout engine and settings plan

## Outcome

Make keyboard-layout correction reliable for both automatic typing and the
manual Option gesture, without changing protected-app or privacy boundaries.
The shipped behavior must support `руддщ` before a space, selected arbitrary
text, mixed text, and layout-specific punctuation such as `$`.

## Scope and exclusions

### P0 — must ship

- Analyze the current token after each eligible key event, not only at a word
  boundary.
- Correct only when the translated token is a strong dictionary match and the
  typed token is not; keep minimum/maximum length, case, secure-field,
  protected-app, and race guards.
- Keep a boundary fallback for punctuation/space and preserve the terminator.
- Make the manual Option path discover the selected text first, then the word
  immediately before the caret; use the active EN/RU source for mixed or
  symbol-only text and retain safe failure when no source/AX context exists.
- Ensure event ordering cannot overwrite a keystroke: sequence checks,
  whole-value compare-and-set, exact replacement verification, cursor restore,
  undo, and refresh after success/failure.
- Add deterministic policy tests for every state transition and regression
  cases for `руддщ`, `ghbdtn`, partial prefixes, backspace, punctuation,
  modifiers, Caps Lock, source changes, symbols, selection, and stale AX state.

### P1 — coherence and UX

- Move layout correction, source memory, permissions required by layout, and
  layout exclusions into the `Раскладка` settings section.
- Keep `Безопасность` focused on access/permissions, protected capture, and
  sensitive-content rules; keep data backup/export in `Данные`.
- Update menu/settings copy so it describes correction during typing, the
  Option gesture, and the actual fallback behavior.
- Add source-level contract tests for toolbar sections and remove duplicate
  controls from the safety surface.

### P2 — explicitly deferred

- No macro language, cloud/OCR indexing, network translation, fuzzy semantic
  correction, or unrestricted auto-replacement in protected apps.
- No broad redesign of screenshot/snippet surfaces in this release.

## Verification gates

1. **Plan gate:** current event monitor, AX replacement path, source maps,
   settings navigation, and existing tests inspected before mutation.
2. **Logic gate:** targeted layout/Option/preferences tests pass; new tests
   cover the exact user reports and negative/safety cases.
3. **Build gate:** full Swift test suite, strict production build, secret scan,
   and `git diff --check` pass.
4. **Release gate:** versioned notarized app/DMG, stapling, codesign,
   Gatekeeper, SHA-256, public GitHub asset and tag verified.
5. **Install gate:** public DMG is the installed source; old app is retained
   at an explicit rollback path; installed process/version/signature are
   checked after launch.
6. **Live/physical gate:** run available local runtime smoke. Accessibility and
   third-party editor behavior are tested through deterministic AX contracts;
   if the headless desktop harness cannot drive a real editor, report that
   limitation rather than claiming a physical editor test.

## Stop conditions

- Stop and preserve rollback if a replacement can mutate text without exact
  range/value verification, if protected contexts are weakened, or if a
  release artifact differs from the tested hash.
- Do not bypass a required CI/security check.
- Stop after the release/install audit passes; defer unrelated cleanup.
