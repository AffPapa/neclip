# NeClip 2.8.6 release evidence

Published: 2026-09-26. Immutable GitHub Release: [v2.8.6](https://github.com/AffPapa/neclip/releases/tag/v2.8.6).

## Source and review

- Release source commit and tag target: `4e5b827e5f54b1e6b8d0710a74c33467ddc15b5a`.
- PR [#69](https://github.com/AffPapa/neclip/pull/69) merged as `1b835c39e27919afbf6e7eae63555eccfebf5db6`; the release commit is included in `main`.
- Required Swift CI, full-history Secret Scan, and CodeQL for Swift, Ruby and Actions passed.
- Local `scripts/secret-scan.sh` reported no leaks in the publishable tree, 253 commits and 26 side-ref-only commits.

## Product changes and verification

- History entries beyond the configured first list are constructed only when “Ещё из истории” opens. Full history, chronological order, absolute numbering, search and per-entry actions are preserved.
- “Проект Иванова” → `https://affpapa.org/` is present in all eight editorial page footers and the repository README.
- `swift test --disable-sandbox`: 367 XCTest (7 expected skips), 0 failures; 4 Swift Testing checks passed.
- Strict optimized release tests with complete Swift concurrency checks and warnings as errors: 367 XCTest (7 expected skips), 0 failures; 4 Swift Testing checks passed.
- `scripts/verify-site.rb`, `scripts/test-site.rb` (14 runs, 45 assertions), `scripts/verify-seo.rb`, and `scripts/test-seo.rb` (13 runs, 37 assertions) passed.
- Product binary sizes measured after the same strict release build and symbol stripping: 2.8.5 = 4,655,848 bytes; 2.8.6 = 4,655,864 bytes (16-byte difference).
- Synthetic AppKit item-construction benchmark, 40 iterations: 1,000 rows, eager p50 0.839 ms / p95 0.887 ms; initial lazy p50 0.012 ms / p95 0.015 ms. It measures item construction, not end-to-end application latency.

## Signed artifacts and public bytes

- Apple notarization and stapling passed for the app, ZIP and DMG.
- Developer ID signature is valid; the app from the ZIP and the app mounted from the DMG pass Gatekeeper assessment.
- `xcrun stapler validate` passed for the app and DMG; the mounted DMG was safely ejected after verification.
- Public GitHub downloads were fetched independently and compared byte-for-byte with the locally verified build; the sidecar SHA-256 files also passed.

| Artifact | Size | SHA-256 | Public URL |
| --- | ---: | --- | --- |
| DMG | 2,142,659 bytes | `59e14e6a7ca8a534cfcb0e1cd273216460717fbd84b35795b1e0adc0226bc810` | [NeClip-2.8.6.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.6/NeClip-2.8.6.dmg) |
| ZIP | 2,109,029 bytes | `7d267fbd686ac45ecb7e18f5e5be865c385b44a545bfbf5e21a4e42706622de1` | [NeClip-2.8.6.zip](https://github.com/AffPapa/neclip/releases/download/v2.8.6/NeClip-2.8.6.zip) |

Both artifacts and checksum sidecars were present before publishing the immutable release. [Проект Иванова](https://affpapa.org/).
