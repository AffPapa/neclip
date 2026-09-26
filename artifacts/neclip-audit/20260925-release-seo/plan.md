# Plan

## Evidence so far

- Supported public release: v2.8.5/build 51, source
  `867558cfa0f7b1d4a1d00fc3fbc31c5ae5e8addc`; release provides signed,
  notarized DMG plus checksum, but no installable app ZIP.
- Live GitHub Pages routes `/`, `/compare.html`, `/sitemap.xml`, `/robots.txt`,
  and `/version.json` returned HTTP 200. Live manifest matches v2.8.5/build 51,
  DMG size, and digest. The comparison hub has 20 products.
- All 20 comparison source URLs were checked against official product sources;
  no broken official links or unsupported claims were found.
- Implemented changes are staged on `codex/neclip-release-seo-20260925`:
  installable ZIP packaging/verification for future builds, current v2.8.5 ZIP
  candidate metadata, three sourced comparison pages, stronger homepage and
  comparison intent, refreshed sitemap/llms metadata, updated release map, and
  regression gates.
- Local ZIP candidate is 2,108,558 bytes, SHA-256
  `a68c3f2c1e13ab584a2ea891d17e8487667df273ad95c274276dff9780329eb5`. Extracted
  app is v2.8.5/build 51; executable hash matches installed app;
  codesign, stapled ticket, and Gatekeeper checks passed.
- Verification passed: site and SEO checks, 21 Ruby tests / 58 assertions,
  366 XCTest cases (6 expected skips) plus 4 Swift Testing tests, shell syntax,
  and `git diff --check`.
- Gitleaks staged-source scan found no leaks. Broad filesystem scan reported 11
  dependency-cache matches under ignored `.build/checkouts/GRDB.swift` only,
  including SQLite test fixtures and a temporary test certificate; these files
  are not tracked or included in staged source. Prior full reachable refs scan
  also found no leaks.
- Publication is blocked: `gh auth status` reports invalid stored tokens for
  both `AffPapa` and `mrdumay-source`; no authenticated GitHub browser session
  is available. The GitHub connector's branch-create request returned HTTP 403
  `Resource not accessible by integration`, so it cannot publish a source branch
  either. The candidate ZIP is not public.
- Fresh GitHub API check: `main` remains `105fe250dd9acc0fdc4427aa0327e22a52a8fb8c`,
  there are no open PRs, and its newest CodeQL, Secret Scan, Swift 6 CI, and
  Pages deployment runs all succeeded. The public release currently has only
  the DMG and its sidecar.
- GitHub marks v2.8.5 `immutable: true`; official policy prohibits changing its
  tag or adding/removing assets after publication. Public docs and manifest now
  advertise only the DMG; ZIP packaging is prepared for a future release with
  all assets attached before publication.
- Code review found that `scripts/verify-site.rb` validated local URLs/hash/size
  without confirming remote asset bytes. The published manifest now advertises
  only the DMG, matching the immutable v2.8.5 release; a regression test rejects
  references to its unavailable ZIP. The verifier now states its remote-check
  limitation, and all public assets still require independent live byte checks.
- Fresh live HTTP check: homepage, compare hub, version manifest, and sitemap
  returned 200. They still serve the old deployed page (old homepage title),
  and the live v2.8.5 manifest does not claim a ZIP.
- Housekeeping: no tracked loose log files or credential files were found.
  `.build` is a 1.2 GB ignored SwiftPM cache; broad scanning's 11 hits are
  SQLite test fixtures and a temporary vendor test certificate within GRDB.
  Keep that cache for build speed, and retain `dist/` release/rollback evidence
  and audit plans. No log or release evidence was deleted.
- Historical releases remain untouched. Ranking/query-volume impact is
  unverified without Search Console data.

## Order

1. Complete delegated and parent audits, enumerate live releases/assets, and fetch
   official product sources.
2. Fix factual release-map drift and improve homepage/comparison coverage only
   where source-backed information adds unique value.
3. Extend release packaging safely for an installable app ZIP, verify its exact
   source identity, checksum, signature, notarization, and Gatekeeper behavior.
4. Run content integrity, SEO, site, security, release checks, and source review.
5. Restore authorized GitHub access; publish corrected site/docs and future ZIP
   packaging through protected review/CI, then verify hosted pages and every
   advertised asset. Do not try to mutate immutable v2.8.5.

## Known constraints

- Search ranking and query volume cannot be asserted without Search Console or
  equivalent verified data.
- GitHub CLI credentials previously reported invalid; check whether the public
  read path works and keep publication blocked until authorized release access is
  available.
- Preserve historical releases/tags and unrelated worktree state.
