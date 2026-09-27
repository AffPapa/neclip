# NeClip clipboard-only release

Goal: remove screenshot capture/editing and all layout correction/switch/memory code, menus, preferences, shortcuts, permissions and active product claims. Keep clipboard history including images/files, snippets, search, paste, backups and privacy. Preserve user database/schema and installed data.

Base: main888c96f, immutable2.8.8/build54; signed source76a3884. Three read-only independent tracks map architecture, QA/data compatibility, website/docs. Parent owns all writes/tests/release/install.

Gates: dependency map -> coherent removal and targeted regressions -> strict debug/release, sanitizer checks, source/history secrets, site/SEO + isolated physical settings/history/snippets QA -> protected PR with required CI/CodeQL -> exact merged source DeveloperID/notary/stapledZIP+DMG -> immutable release/publicbytes -> metadataPR/Pages/live -> install exact verified publicapp preserving data.

No feature additions or unrelated refactor. Keep historical tags/releases/reports factual. Retire guide routes coherently without advertising removed functionality. Checkpoint after local tests before publish. Record source/binary size delta without claiming unmeasured UI speedup.

## Local verification checkpoint

- Removed 15 production subsystem files; no database/schema or storage changes. Startup removes only 14 named retired preference keys, idempotently. Generic image/file history and backup/restore retained.
- Strict debug, strict optimized release, AddressSanitizer and ThreadSanitizer: each 283 XCTest, 8 expected opt-in skips, zero failures; plus 4 Swift Testing checks.
- Site 14 tests / 45 assertions and SEO 13 / 37 pass with public 2.8.8 and source candidate 3.0.0/build55.
- Secret detector canaries, publishable tree, 267 HEAD commits and 26 side-ref-only commits clean.
- Native isolated 3.0 preview: five preferences sections, three shortcuts, only clipboard/accessibility permission copy, synthetic legacy database retains 2 history rows and 10 snippets. History and snippet menus show retained fixtures and no removed actions. Conflicting shortcuts correctly report the running installed app. Editor transition was interrupted by computer-use focus protection; no new physical editor/undo claim. Existing editor regression tests pass.
- Independent architecture and QA reviews found no blocking removal/data compatibility issue. Website review provides separate post-publication scope.
- Existing rapid overlapping sequential-paste ownership edge case remains a documented P2; no unrelated refactor in this removal release.

Public release, protected CI, signed artifacts, website update and installation are still pending.

## Additional native verification

Configured the isolated debug bundle to open the editor directly. Token replacement at selection, Undo/Redo, switching documents, undo isolation and save/relaunch passed in the native editor. Preview quit normally after the test. The disposable old database migration test also passes. All user data remains untouched.

## Immutable release

PR76 required checks passed, merged source c539ae0ad6aad80b84aa89d6a1d6ca7ce0d0173f. Version3.0.0/build55 published immutable at2026-09-27T13:45:20Z, release397666129. Both archives and sidecars match independent public downloads; ZIP app, DMG and mounted app pass signature/stapler/Gatekeeper, Info3.0.0/55 and executable parity. Archive/binary secret scans pass; no local-path strings or removed ScreenCaptureKit/input-source/event-tap dependencies in the signed executable. Public ZIP1,929,891bytes, DMG1,960,899bytes.

Publication branch updates six active indexable routes and two retired noindex notices, eighteen alternatives, README, manifest, product data, roadmap, current release evidence and repository copy. Site14/45 and SEO18/52 pass. Native browser desktop/390px/skip-link smoke passes locally. Website deployment and installed-app replacement still pending.
