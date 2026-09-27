# NeClip minimal-product depth audit

Goal: independently verify removal of screenshot and keyboard-layout functionality; remove confirmed residual work or confusing settings; fix reproducible clipboard/snippet defects; publish the next immutable Direct release and install verified public bytes without data loss.

Base: clean main 664ec284e646162a0a9c29937e84461923474fc4, public 3.0.0/build55 confirmed live. Three read-only tracks cover architecture/privacy, performance/state/QA, and settings/UX/current documentation. Parent owns changes, tests and release.

Scope: retained clipboard/history/snippets, settings, permissions, background processing, dependencies, current public copy. Historical release evidence and rollback artifacts remain. No database redesign, additional product features, arbitrary preference resets or unmeasured speed claims.

Gates: reproduce -> smallest coherent fix -> strict debug/release and relevant sanitizers, migration/privacy regressions, site/SEO/secrets, isolated native UI -> checkpoint -> protected PR and required CI -> exact merged commit build/sign/notarize/staple/Gatekeeper -> immutable draft-assets-before-publication -> fresh public-byte checks -> metadata PR/Pages/live -> installed bundle/data verification.

Stop: complete verified release/install; if external access blocks a stage, retain evidence and report the exact unresolved gate. Do not bypass branch protections. Prioritize data/privacy/correctness, then measured waste and clear UX defects. Agent recommendations require parent synthesis before changes.

## Local checkpoint

Independent reviewers confirmed full retired subsystem removal and exact 14-key selective migration. Fixed sequential attempt ownership, exact history-limit presentation, truthful permission/update state and off-main SQL counts; removed dead menu helpers/state and duplicate controls. No schema or user-data mutation.

Strict debug/release + ASan/TSan: each 286 XCTest, 9 expected skips, zero failures; 4 Swift Testing checks. Native isolated five-section/three-shortcut/settings/history menu smoke passed. Synthetic 2,000-snippet count p50 4.747625 -> 0.017708 ms, p95 5.453875 -> 0.026875 ms, 100 warmed release iterations. Site14/45, SEO18/52 pass. Full release and public installation remain pending.
