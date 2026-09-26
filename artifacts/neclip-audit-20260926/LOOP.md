# NeClip fresh audit 2026-09-26

Source: `.work-neclip-283`, origin AffPapa/neclip, clean baseline ca99eec0be22ee1b9a16a609ee8a34ce21cd9bf5.
Live baseline: immutable v2.8.6 / build 52; both DMG/ZIP + checksum sidecars, Pages built; no open PR.
Scope: confirmed data/privacy/keyboard defects and measured small performance fix. No redesign, external AI, user DB mutations or old release changes.
Gates: regression reproduction -> minimal fixes -> debug/strict release/site/SEO/ASan/TSan/secrets -> required CI/CodeQL -> protected PR merge -> exact merged-source Developer ID/notary/stapler/Gatekeeper -> immutable DMG+ZIP -> fresh public byte and Pages checks.
Three read-only audit agents completed. Parent owns every edit and publication.
P0: none confirmed in examined paths.
P1: search window steals modified/native control keyboard events; image capture setting not rechecked for queued explicit screenshots; title matches unnecessarily normalize full bodies.
P2 deferred: snippet token insertion ignores caret; screenshot title ignores background export dimensions; literal snippets eagerly read unrelated clipboard; unnamed AX filters require physical review. Screenshot clipboard failure rollback remains unconfirmed.
Baseline: 367 XCTest, 7 expected skips, 0 failures + 4 Swift Testing; site 14/45 and SEO 13/37; publishable tree + all fetched history secret scans clean.
Before regression: keyboard modifiers test failed 18 assertions. Synthetic release search benchmark: 64 x 512 KiB ASCII bodies, in-memory SQLite, 30 warmed iterations; p50 164.964791 ms, p95 229.571209 ms. macOS 27.0 26A5416b, Swift 6.4.0.27.1, arm64. Not an end-to-end UI measurement.

After: synthetic search p50 3.7405 ms, p95 4.187333 ms with identical fixture/toolchain/configuration. Debug and strict release: 371 XCTest, 8 expected opt-in skips, 0 failures; 4 Swift Testing. Queued screenshot regression reproduced before fix (1 stored vs expected 0) and passes after.
Physical UI: separate debug bundle and database under /private/tmp/neclip-audit-20260926, screenshot QA forces paused capture. Synthetic editor AX exposes named tools and region actions. Following window close the native automation service repeatedly returned timeoutReached; search physical behavior and VoiceOver audio are not verified. AppKit responder/IME integration tests pass.

Release checkpoint: ASan and TSan full suites passed (371 XCTest, 8 opt-in skips, plus 4 Swift Testing); site/SEO gates passed. Developer ID identity and existing neclip notary profile available. GitHub main requires test/full-history/CodeQL actions, ruby, swift, with strict up-to-date checks; no required approval count. No protection bypass is authorized or needed. Next release candidate 2.8.7 / build 53, old public metadata stays 2.8.6 until downloaded bytes are verified.

Physical follow-up recovered: isolated native search returned expected fixture; Down selected the next row, Ctrl+Option+Up preserved it and filter Return did not paste. Default-size search screenshot reviewed. Screenshot keyboard markup, Undo/Redo and native Save produced a visually checked 720×420 PNG. VoiceOver audio and multi-monitor testing remain unverified.
PR #71 passed all required CI (Swift CodeQL 17m59s), merged as 2cad4383bcc6d1a7c8c28c6e60bbfe67a3b11be6. Stable release toolchain Swift 6.4.0.34.1 passed strict tests. Exact merged-source release is signed/notarized/stapled/Gatekeeper accepted. Immutable v2.8.7 published 2026-09-26T15:55:01Z with DMG+ZIP and both checksums. Fresh public downloads match local bytes and sidecars. Artifact secret scan clean; source/history scanner reports 258 HEAD commits and 26 side-ref-only commits.
