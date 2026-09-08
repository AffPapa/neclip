# NeClip 2.1 audit plan

## P0 — correctness and product clarity

1. Establish the exact public baseline and run full tests/security checks.
2. Trace menu construction from status-item click and hotkey to storage reads;
   prove one chronological history projection and direct snippet folders.
3. Trace Settings lifecycle, update checking and footer state; remove accidental
   work or ambiguous copy without changing the explicit update contract.
4. Inspect storage queries, payload materialization, refresh generations and
   hot-key registration for redundant work or race-prone behavior.

## P1 — safe performance slice

1. Choose only changes backed by source evidence and a regression test.
2. Keep all bounded limits and privacy decisions fail-closed.
3. Add/adjust contract tests for the new invariant.

## P2 — release and publication

1. Bump version/build, update changelog/project map/backlog/version manifest.
2. Run local debug/release tests and strict release build.
3. Sign, notarize, staple and verify app + DMG; install with rollback copy.
4. Merge via protected GitHub PR, publish Release and update GitHub Pages.
5. Re-fetch public manifest/DMG, compare checksum, scan full history and report.

## Definition of done

- one measurable optimization or simplification is shipped;
- no behavior regression in history, snippets, settings, paste or privacy;
- installed app and public release are the same version/build;
- main branch protection is restored and the repository is clean.
