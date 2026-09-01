# Run log

- 2026-09-01: Baseline worktree clean at `fc02f10`; 28-commit Gitleaks result
  from the immediately preceding 1.6.0 gate was clean.
- 2026-09-01: Three read-only tracks covered retained promises/research, symbol
  reachability/hot paths, and Git/release/supply-chain hygiene.
- 2026-09-01: Found a real privacy gap: password-manager bundle IDs were default
  exclusions, not an immutable capture deny policy.
- 2026-09-01: Found five proven dead compatibility members/fields and no unused
  private declaration by repository-wide reference count.
- 2026-09-01: Made password-manager denial mandatory/case-insensitive, including
  the delayed app-transition guard; added a target-app menu toggle and bounded
  snippet import before decode.
- 2026-09-01: Removed five proven dead source members while retaining migrations,
  compatibility tests, research and release evidence.
- 2026-09-01: Debug and strict release builds passed. The current Apple CLT is
  internally incomplete: compiler `6.4.0.30.4`, SDK interfaces `6.4.0.31.4`, no
  XCTest framework and no TestingMacros plugin. The test target can be compiled
  through a temporary projection but its runtime gate cannot execute here.
- 2026-09-01: ASan- and TSan-instrumented application builds passed. Gitleaks
  8.30.1 found no secret in the publishable tree or all 29 fetched commits;
  plist/JSON, diff and Git integrity checks passed.
- 2026-09-01: Isolated QA of General/Privacy Settings found unreadable fallback
  password-manager names. Added canonical display names and rechecked the
  corrected accessibility tree. Installed/public NeClip remained untouched.
