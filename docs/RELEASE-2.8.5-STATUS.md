# NeClip 2.8.5 / build 51 — candidate status

This is a pre-release record. It does not certify a signed artifact, public
release, installation, or live website. Those fields will be completed in a
documentation-only change after the exact merged source commit has been built,
signed, notarized, published and independently downloaded.

## Candidate changes

- Screenshot Copy/Save delivery no longer depends on the editor window being
  visible after image encoding. A hidden editor no longer silently loses the
  result or remains stuck in its exporting state.
- Snippet template matching now selects candidate token patterns from the byte
  after `{`. In an opt-in synthetic benchmark, a 60 KB brace-heavy input with
  20,000 unknown `{x}` groups changed from 81.295 ms median / 83.439 ms p95 on
  baseline 2.8.4 to 13.256 ms / 13.599 ms on this candidate. This is a local
  debug microbenchmark, not a whole-app speed claim.

## Local verification

- Full Swift suite: 366 XCTest, six explicit opt-in skips, zero failures; four
  Swift Testing checks passed.
- Strict optimized Swift 6 build with complete concurrency checking and
  warnings-as-errors passed.
- ASan and TSan each passed 41 screenshot and snippet-renderer XCTest checks.
- Site coherence and site mutation tests passed (8 tests / 21 assertions);
  SEO checks passed (12 tests / 34 assertions); five canonical-page/schema/link
  verification groups passed.
- Redacted Gitleaks scan passed detector canaries, current publishable tree,
  235 local HEAD commits, and 26 side-ref-only commits. This is local-ref
  coverage; GitHub's required full-history workflow remains a release gate.
- The native AppKit export test used a synthetic image and unique named
  pasteboard. It did not read user history, invoke screen capture, or touch the
  general pasteboard.

## Still required

Required checks on the candidate PR, normal protected merge, exact merged-commit
Developer ID signing, notarization and stapling, Gatekeeper, DMG contents and
checksum, public release and anonymous re-download, site coherence, retained
rollback, and installed-bundle equivalence remain pending. Physical VoiceOver,
real display/Spaces/permission combinations, and third-party editor behavior
remain explicit hardware/runtime coverage limits.
