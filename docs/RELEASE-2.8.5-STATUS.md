# NeClip 2.8.5 / build 51 — release evidence

## Source and publication

- Reviewed PR: [#63](https://github.com/AffPapa/neclip/pull/63), merged after all required CI, full-history secret scan, and CodeQL checks passed.
- Release source: `867558cfa0f7b1d4a1d00fc3fbc31c5ae5e8addc`.
- Public release: [v2.8.5](https://github.com/AffPapa/neclip/releases/tag/v2.8.5), published 2026-09-25.
- Public artifact: `NeClip-2.8.5.dmg`, 2,141,634 bytes.
- SHA-256: `b10cfee08397ab0ea063c25b97904a824c092452c4275eec099ae66da044c866`.
- An independent public download matched both the local file byte-for-byte and the published SHA-256.
- Version 2.8.4 remains available at [its release page](https://github.com/AffPapa/neclip/releases/tag/v2.8.4) for rollback.

## Build and release gates

- 366 XCTest passed, with six explicit opt-in skips; four Swift Testing checks passed.
- Strict optimized Swift 6 build with complete concurrency checking and warnings-as-errors passed.
- AddressSanitizer and ThreadSanitizer each passed 41 screenshot and snippet-renderer XCTest checks.
- Pull request Swift CI, full-history secret scan and all CodeQL jobs passed on the exact candidate commit before protected merge.
- Developer ID signature verified. Apple notarization accepted the app and DMG; tickets were stapled and validated.
- Gatekeeper accepted both app and DMG. The app mounted from the exact DMG also passed signature, stapling and Gatekeeper verification.
- The anonymous public DMG download matched the exact notarized local DMG byte-for-byte and by SHA-256. The release script had already verified its signature, stapled ticket and Gatekeeper result before the file entered the workspace. This host attaches `com.apple.provenance` to copied/downloaded bundles; subsequent local `codesign`/Gatekeeper checks fail on that host metadata, so post-download mounted-bundle equivalence could not be re-established here.

## Changes and measured behavior

- Screenshot Copy/Save delivery continues if asynchronous image encoding finishes after the editor window becomes hidden. A native AppKit regression test used a synthetic image and a unique named pasteboard.
- Snippet token candidates are indexed by the byte after `{`. In an opt-in local synthetic benchmark, a 60 KB brace-heavy string with 20,000 unknown `{x}` groups changed from 81.295 ms median / 83.439 ms p95 on 2.8.4 to 13.256 ms / 13.599 ms on 2.8.5. This is a microbenchmark for that input, not an overall app speed claim. Ordinary search measurements were similar before and after.
- Product workflow research and a risk-based QA matrix are available in [PRODUCT-RESEARCH-2.8.5.md](PRODUCT-RESEARCH-2.8.5.md) and [QA-2.8.5-RISK-MATRIX.md](QA-2.8.5-RISK-MATRIX.md).

## Verification boundaries

- The native regression test did not read user clipboard/history, invoke screen capture, or touch the general pasteboard.
- Installed `/Applications/NeClip.app` as 2.8.5 / build 51 from the mounted public DMG. In the install operation, the staged and installed app both passed `codesign`, stapled-ticket validation and Gatekeeper; the installed executable hash matched the release build. The previous app was preserved at `/Applications/NeClip-2.8.4.rollback.app`. The app was not launched, so user history and the general pasteboard were not accessed for a live smoke test.
- After the install operation returned, the host attached `com.apple.provenance` metadata to the app bundle. A later standalone `codesign` invocation then reported an invalid signature. This environment-specific post-operation result could not be reconciled with the successful checks made during installation, so installed-bundle signature state after host metadata handling remains a limitation. The public DMG itself remains byte-identical to the notarized release artifact.
- Physical VoiceOver, real display/Spaces/permission combinations, mixed keyboard and pointer operation in the running app, and third-party editor behavior remain unverified.
- The product comparison uses official vendor documentation and source inspection; competing apps were not installed or hands-on benchmarked.
- Local ASan/TSan coverage is scoped to screenshot and snippet-rendering tests, not the entire application.
