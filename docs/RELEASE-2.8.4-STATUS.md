# NeClip 2.8.4 / build 50 — release evidence

Verified 21 September 2026. This report separates executable provenance from
later documentation changes, and measured checks from remaining physical QA.

## Public artifact

- [Immutable GitHub Release](https://github.com/AffPapa/neclip/releases/tag/v2.8.4), published `2026-09-21T16:35:19Z`.
- [NeClip-2.8.4.dmg](https://github.com/AffPapa/neclip/releases/download/v2.8.4/NeClip-2.8.4.dmg): **2,140,099 bytes**.
- DMG SHA-256: `033b5d475e96a87d82f5dde6b4a698bcc9f9b618fe1b3d1e6880c1f37bfb29d1`.
- Executable SHA-256: `04635b4c6c839c87538d4b3d7c038334d43dce3b70fabe71f01d1b3442a7c0ee`.
- Artifact source/tag: `4bb2bc6e7b9b48b4e60d3adc8f375b1db0993ac6`, the normal merge of [PR #61](https://github.com/AffPapa/neclip/pull/61).
- macOS 14+, arm64; Developer ID team `H6VGU2M6JD`.

The app and DMG were signed, Apple-notarized and stapled. Both passed signature,
ticket and Gatekeeper verification. The anonymous public download was checked
against its SHA-256 sidecar, mounted read-only and checked again, including the
contained executable. It matches the tested release build. The installed app
was replaced gracefully with that same public binary; the previous 2.8.3 bundle
was retained separately for rollback. No user clipboard or history contents were
read for verification. No database schema migration is introduced by this release.

The download manifest is updated only after that public-artifact verification.
A later documentation-only merge is not the executable's source commit.

## Regression and release gates

- Strict Swift 6 debug and optimized tests: **363 XCTest**, five explicit opt-in
  skips, zero failures; **four Swift Testing** checks passed separately.
- Address Sanitizer: **56 XCTest + four Swift Testing**, zero failures.
- Thread Sanitizer: **56 XCTest + four Swift Testing**, zero failures.
- Website coherence: eight tests / 21 assertions; SEO regression suite:
  12 tests / 34 assertions. Canonical URLs, visible content, schema and links
  are checked without inventing ratings or keyword-density targets.
- Required PR checks, including strict Swift CodeQL and the aggregate CodeQL
  gate, completed successfully before the normal merge. Two alerts found in
  the initial SEO-validator implementation were fixed, not suppressed.
- Canary-tested secret scanning covered the publishable tree and 232 HEAD
  commits plus 26 side-ref-only commits at the executable-source checkpoint.

The two reported regressions have dedicated tests: Return is no longer a global
key equivalent on every history submenu, and a successful snippet copy explicitly
records its output with normal history recency, deduplication and privacy gates.
Other fixes cover Command-Return/click, repeated protected `{clipboard}` expansion,
source exclusions changed while work is queued, JSON file paths, stale snippet
draft metadata and screenshot cancellation/restart ownership.

Synthetic short-text, in-memory search samples (100 / 500 / 2,000 rows) measured
median 0.214 / 1.083 / 4.372 ms and p95 0.229 / 1.139 / 4.487 ms. These are local
microbenchmarks, not startup, whole-menu, large-payload or competitor benchmarks.
Streaming avoids materializing the entire search result set before limiting it.

## Native UI and risk coverage

An isolated preview app, with capture/correction disabled, used synthetic images.
The native Save dialog was exercised for PNG and JPEG, cancel/reopen, undo/redo
of an opaque annotation and remembered successful format after restart. Both
saved 720 × 420 images decoded and were visually inspected. The cancelled format
was not persisted. No actual screen capture or user clipboard was used.

The [100-risk matrix](QA-2.8.4-RISK-MATRIX.md) is an inventory: it is not a claim
of 100 discovered bugs or 100 completed physical tests. Original review-only and
unverified labels are retained, with follow-up evidence explicitly separated.

Still unverified: physical multi-monitor/scaling and Spaces combinations, actual
Screen Recording denial/recovery and capture cancellation, and every third-party
editor's physical keyboard/Option behavior. Synthetic AppKit/event tests do not
establish universal compatibility. Automatic correction remains opt-in and
conservative; secure or ambiguous contexts may intentionally decline correction.

## GitHub and secret-review boundary

No confirmed secret was found in the inspected source/history, available public
GitHub text, release text/assets and downloadable Actions logs. At the full
baseline, 920 log archives from 925 inventoried runs were covered; five old logs
were unavailable. The next incremental sweep scanned 19 more completed archives
and PR #61 text with no findings. New release resources and executable strings
also passed redacted scanning. Available security-alert inventories were empty
at the pre-merge checkpoint. Later workflow output remains a separate delta.

Twenty-eight expired Actions artifacts and unavailable logs cannot be certified.
Text scanning of executable strings/resources is not a proof about every binary
payload or steganography. A clean detector run is not a guarantee that no secret
has ever existed. There was **no confirmed deletion target**, so no repository
history, releases, user data or rollback assets were removed as speculative cleanup.

## Public documentation

The [20-app comparison](https://affpapa.github.io/neclip/compare.html) uses official
sources and groups adjacent workflows; it is not an independent top-20 ranking.
Three guides cover history/snippets, layout correction and screenshot redaction.
They disclose limitations, use synthetic examples and contain no unsupported
speed or security superiority claims. Static navigation, mobile layouts, metadata,
sitemap and structured data are versioned without a new JS framework or trackers.
