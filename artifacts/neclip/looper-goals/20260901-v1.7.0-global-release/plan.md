# NeClip 1.7.0 — 100-point global release plan

Legend: unchecked means not yet proven in this loop. An item may close as
implemented, verified, deliberately rejected, or deferred with evidence.

Current closure: **80/100 items closed**. The remaining 20 are one connected
external release block, not unfinished product code: no valid GitHub CLI token
and no usable Apple notarization credential are available. The public 1.4.0
artifact and manifest stay untouched until those gates can run end to end.

## A. Scope, truth and release contract

1. [x] Freeze the current branch, commit, worktree and remote inventory.
2. [x] Reconcile every retained audit, research note, backlog and changelog.
3. [x] Inventory every production Swift file and its runtime owner.
4. [x] Inventory every test, script, workflow, Pages file and release asset.
5. [x] Verify source, installed, GitHub Release and Pages version truth separately.
6. [x] Confirm the local-only, no-account, no-cloud, no-telemetry boundary.
7. [x] Confirm menu-bar-only lifecycle and absence from the Dock.
8. [x] Define P0, P1 and P2 acceptance rules before product edits.
9. [x] Record protected areas and rollback points before publication.
10. [x] Complete three independent read-only audit tracks and synthesize them.

## B. Core clipboard behavior

11. [x] Verify text, rich text, image and file-list capture end to end.
12. [x] Verify duplicate handling never retains stale RTF or source metadata.
13. [x] Verify sensitive and transient pasteboard formats fail closed.
14. [x] Verify password-manager exclusions before and after app transitions.
15. [x] Verify count, age and byte-quota retention preserve pins and snippets.
16. [x] Verify append-next is one-shot, visible, bounded and cancelable.
17. [x] Verify paste, plain paste, copy-only and paste-and-delete result semantics.
18. [x] Verify temporary pasteboard restoration preserves every readable type.
19. [x] Verify sequential paste order, reset and target-app protection.
20. [x] Verify clear-hour, clear-today, clear-all and clear-on-quit boundaries.

## C. Menu, search and daily interaction

21. [x] Verify status-item click and every global shortcut use one appearance.
22. [x] Measure menu-open latency with maximum supported history and snippets.
23. [x] Verify bounded labels at 16, 32, 64 and 96 grapheme clusters.
24. [x] Verify long, multiline, emoji and right-to-left values cannot resize menus.
25. [x] Verify typing immediately focuses search and Escape closes predictably.
26. [x] Verify number shortcuts, arrows, Return, Space and Command actions.
27. [x] Verify structured filters are discoverable and do not pollute queries.
28. [x] Verify older-than-menu history remains available through full search.
29. [x] Verify preview/inspector actions expose source, type and safe-open state.
30. [x] Remove or rename ambiguous menu actions and duplicate navigation paths.

## D. Snippets, settings and layout UX

31. [x] Verify the snippet editor always selects or clearly invites an item.
32. [x] Verify row click, Return and Edit affordances open the same snippet draft.
33. [x] Verify folder create, rename, collapse, move, delete and Unfiled behavior.
34. [x] Verify autosave, failed-save retry, close, Quit and selection-change flushing.
35. [x] Verify starter snippets are useful, editable, removable and non-personal.
36. [x] Verify settings use one logical numeric-control pattern and clear units.
37. [x] Verify all five hotkeys are recordable, conflict-safe and reset atomically.
38. [x] Verify manual layout correction, automatic off shortcut, undo and HUD.
39. [x] Verify last-used and fixed per-app layout rules remain understandable.
40. [x] Simplify any settings copy or control that needs documentation to operate.

## E. Architecture and performance

41. [x] Trace main-thread work from pasteboard change to menu refresh.
42. [x] Prove menu queries never load original image, RTF or full snippet BLOBs.
43. [x] Audit every database query, index and transaction for bounded behavior.
44. [x] Audit clipboard polling, timers and notification coalescing for idle cost.
45. [x] Audit event taps and Accessibility reads for latency and redundant work.
46. [x] Audit Swift 6 actor isolation, Sendable boundaries and shared mutable state.
47. [x] Remove only proven dead declarations, compatibility wrappers and assets.
48. [x] Preserve required migrations while removing unreachable historical paths.
49. [x] Measure build size, launch time, resident memory and representative searches.
50. [x] Add regression budgets for any hot path changed during this loop.

## F. Privacy, security and repository hygiene

51. [x] Enumerate tracked, ignored, untracked, large and binary repository objects.
52. [x] Run self-verifying Gitleaks canaries before trusting clean results.
53. [x] Scan the publishable tree without printing matched secret values.
54. [x] Scan all reachable commits and every local/remote ref.
55. [x] Scan dangling histories and side-ref-only commits separately.
56. [x] Audit plist, entitlements, signing config, logs and crash paths for leakage.
57. [x] Audit dependency lock/provenance, advisories and license boundary.
58. [x] Audit GitHub Actions permissions, immutable SHAs and artifact handling.
59. [x] Audit issue templates, docs and examples for real clipboard/private data.
60. [x] Remediate any confirmed leak with revocation-first rollback-safe handling.

## G. Tests, compatibility and accessibility

61. [x] Run the complete XCTest and Swift Testing suites on full Xcode.
62. [x] Run strict Swift 6 complete-concurrency release build with warnings as errors.
63. [x] Run AddressSanitizer instrumented build and available test coverage.
64. [x] Run ThreadSanitizer instrumented build and available test coverage.
65. [x] Parse and lint Swift, shell, plist, JSON and Markdown release inputs.
66. [x] Run database migration tests including a disposable external-copy test.
67. [x] Exercise first-run and denied/revoked Accessibility recovery paths.
68. [x] Exercise pasteboard authorization wording and recovery behavior.
69. [x] Review VoiceOver labels, keyboard focus, contrast and reduced motion.
70. [x] Perform isolated visual QA in light and dark appearance at supported sizes.

## H. Exact release artifact

71. [x] Choose the next semantic version/build from the final change surface.
72. [x] Update every source/test/doc version contract atomically.
73. [ ] Produce the release app from the exact clean commit. **Blocked: notary credentials unavailable.**
74. [ ] Sign every required Mach-O and bundle with Developer ID Application.
75. [ ] Verify hardened runtime, entitlements and designated requirement.
76. [ ] Produce deterministic ZIP and DMG deliverables without private extras.
77. [ ] Notarize both public distribution paths and wait for acceptance.
78. [ ] Staple tickets and validate the app and mounted DMG offline.
79. [ ] Verify Gatekeeper assessment and deep code-sign consistency.
80. [ ] Generate independent SHA-256 hashes and a release evidence manifest.

## I. GitHub, Pages and documentation

81. [x] Check GitHub authentication, repository identity and protected main state. Authentication is invalid; public identity is verified and rules are intentionally not overclaimed.
82. [x] Rebase or merge onto the latest remote without losing unrelated work.
83. [x] Update README, changelog, backlog, project map and engineering audit.
84. [x] Update machine-readable project, backlog and changelog JSON sources.
85. [x] Update the standalone GitHub Pages landing for the new release.
86. [x] Verify Pages has one obvious download CTA, version, requirements and privacy.
87. [x] Update the strict version manifest only after artifacts exist.
88. [ ] Push the reviewed release commit and tag without force. **Blocked: GitHub authentication unavailable.**
89. [ ] Create the GitHub Release with exact ZIP/DMG, notes and hashes.
90. [ ] Verify workflows, Pages deployment and release checks complete successfully.

## J. Installation, live verification and closure

91. [x] Preserve the currently installed/public NeClip and its version metadata; no replacement was attempted without a notarized artifact.
92. [ ] Stop NeClip cleanly and install the exact public release artifact. **Blocked with the binary release gate.**
93. [ ] Verify menu-bar presence, Dock absence, Quit and relaunch behavior live.
94. [ ] Smoke-test history, search, snippets, hotkeys and layout actions live.
95. [ ] Verify Accessibility and Input Monitoring permission recovery after update.
96. [ ] Verify in-app update check reads the new Pages manifest and exact asset URL.
97. [ ] Download public assets anew and compare hashes with local release evidence.
98. [ ] Mount the public DMG and repeat Gatekeeper/signing/notarization checks.
99. [ ] Re-run public repository/history secret scans after publication.
100. [ ] Close the loop with a clean tree, final audit, rollback path and live URLs.
