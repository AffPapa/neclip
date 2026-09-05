# NeClip: settings and usability follow-up

Local 1.8.0/build 14 candidate, 5 September 2026. No public release claim.

## Working prompt and scope

Audit every settings section, history/search and the snippet editor as a native
macOS utility. Prefer clear states and fewer mistakes to new features. Preserve
user data; implement confirmed high-value fixes and verify the result. Three
independent read-only tracks preceded implementation: settings/lifecycle,
menu/editor UX and privacy/data QA. Looper provided the audit-before-edit and
verification gates. Production install, security grants and publication remain
outside this pass.

## Changes

1. Data operations retain their progress indicator until they finish.
2. Login-at-launch reflects actual macOS authorization; a pending request is
   not presented as enabled, and offers the system Login Items settings.
3. Refreshing login status cannot itself register/unregister the application.
4. Privacy rules show the effective count, overflow and truncated long phrases.
   The editor preserves its draft/caret rather than rewriting every keystroke.
5. Terminal/IDE can be excluded from layout memory independently of their
   mandatory automatic text-correction protection; duplicates ignore case.
6. Failed snippet saves retain visible retry/Command-S and detailed feedback.
7. Duplicate keys return a friendly domain error, checked within the write
   transaction. Other editor database errors no longer expose SQL.
8. Deselection distinguishes an existing library from no snippets/no results.
9. Folder creation/rename uses a compact sheet: blank names cannot save, and
   storage failures retain the name and editing context for retry.
10. Search fetches only one extra row per source, caps display at 20 and tells
    users when refining the query can find more results.
11. Search-field key handling leaves undo/delete for editing a nonempty query;
    modified arrows are not treated as menu navigation.
12. All explicit bulk history deletion paths share an asynchronous capture
    barrier: stop observations, drain queued snapshots, delete, resume only
    previously running observation. Capture preferences remain unchanged.
13. A failed VACUUM no longer misreports a successful deletion as a failure.
14. Export rejects libraries exceeding the import count/byte contract before
    writing an unusable backup; the UI explains the failure.
15. Data settings separate transfer, starter examples and destructive cleanup.
16. Retention timing and the actual Management → Layout menu path are explicit.

## Verification

- 196 XCTest cases: 195 passed, one opt-in external-database test skipped;
  11 Swift Testing cases passed. **206 passed, one skipped, zero failures.**
- Tests include queued-capture ordering, cleanup serialization/failure recovery,
  export >16 MB, duplicate-key transaction validation, save retry, folder draft
  retention, login states, privacy-rule limits and search boundaries.
- All five settings tabs and the folder-first snippet menu were inspected in
  an isolated disposable app. General/Layout/Data screenshots were reviewed.
  Native duplicate-key input confirmed that retry stayed visible; it also
  exposed the SQL message subsequently replaced by the domain error.
- UI-driver quirks prevented treating programmatic field edits as proof of
  every physical-keyboard interaction. Those cases retain behavioral tests;
  global shortcut/audio coverage and both system themes are not claimed.
- Strict release build, complete concurrency, warnings-as-errors, JSON and diff
  whitespace checks passed on the final source. Secret scanning passed for
  the publishable tree, 32 HEAD commits and two side-ref-only commits.
  Destructive GUI tests never
  target the user's actual database; the disposable capture is launch-paused.
- Final Data-tab screenshot confirmed the three separate groups. The disposable
  audit process was normally quit; only the pre-existing working preview
  remained running. Neither it nor `/Applications/NeClip.app` was replaced.

## Deliberately retained limits

Age-based retention remains event-triggered, not a background deletion timer;
its timing is now stated when enabled. Search remains bounded rather than
infinite scrolling. Very large snippet exports are rejected, not split into
multiple files. No new accounts, cloud, telemetry or permissions were added.

## Primary design/API references

- [Apple Settings guidance](https://developer.apple.com/design/human-interface-guidelines/settings)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Login registration requires user approval](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29)
- [RequiresApproval state](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval?language=objc)
