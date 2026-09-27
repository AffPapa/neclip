# NeClip minimal-product depth audit

Goal: independently verify removal of screenshot and keyboard-layout functionality; remove confirmed residual work or confusing settings; fix reproducible clipboard/snippet defects; publish the next immutable Direct release and install verified public bytes without data loss.

Base: clean main 664ec284e646162a0a9c29937e84461923474fc4, public 3.0.0/build55 confirmed live. Three read-only tracks cover architecture/privacy, performance/state/QA, and settings/UX/current documentation. Parent owns changes, tests and release.

Scope: retained clipboard/history/snippets, settings, permissions, background processing, dependencies, current public copy. Historical release evidence and rollback artifacts remain. No database redesign, additional product features, arbitrary preference resets or unmeasured speed claims.

Gates: reproduce -> smallest coherent fix -> strict debug/release and relevant sanitizers, migration/privacy regressions, site/SEO/secrets, isolated native UI -> checkpoint -> protected PR and required CI -> exact merged commit build/sign/notarize/staple/Gatekeeper -> immutable draft-assets-before-publication -> fresh public-byte checks -> metadata PR/Pages/live -> installed bundle/data verification.

Stop: complete verified release/install; if external access blocks a stage, retain evidence and report the exact unresolved gate. Do not bypass branch protections. Prioritize data/privacy/correctness, then measured waste and clear UX defects. Agent recommendations require parent synthesis before changes.

## Local checkpoint

Independent reviewers confirmed full retired subsystem removal and exact 14-key selective migration. Fixed sequential attempt ownership, exact history-limit presentation, truthful permission/update state and off-main SQL counts; removed dead menu helpers/state and duplicate controls. No schema or user-data mutation.

Strict debug/release + ASan/TSan: each 286 XCTest, 9 expected skips, zero failures; 4 Swift Testing checks. Native isolated five-section/three-shortcut/settings/history menu smoke passed. Synthetic 2,000-snippet count p50 4.747625 -> 0.017708 ms, p95 5.453875 -> 0.026875 ms, 100 warmed release iterations. Site14/45, SEO18/52 pass. Full release and public installation remain pending.

## Immutable release

PR78 passed every required check, including Swift CodeQL22m21s, and merged as8a76c079d53ead5876f7efff4288ffdf621367e5. Exact source was built, signed, app/DMG notarized and stapled, ZIP/mounted-DMG Gatekeeper verified. Immutable release397694785/v3.0.1/build56 published2026-09-27T15:07:26Z with both archives and sidecars attached first. Fresh anonymous downloads match all four files; public ZIP and mounted-DMG app executables/Info match and pass all signature/notary/Gatekeeper checks. Source/history and binary/archive secret scans pass; retired APIs/local-machine paths absent from signed binary.

DMG1,970,627bytes, SHA256 b36326a73ccc82e7b7ed112d2d51d6e7032b6d02940360e4cbef2cc4fcbba3e5. ZIP1,939,207bytes, SHA2562847185a4b5c66f5bc83a5e093b69ab44101b6aee35e36730ebc6dec95cd7b7a.

Publication metadata now derives from verified immutable assets. Site14/45 and SEO18/52 pass. Pages deployment and installed-app verification remain pending.
