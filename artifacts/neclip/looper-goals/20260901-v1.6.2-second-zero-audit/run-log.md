# Run log

- 2026-09-01: Baseline worktree clean at `48cd28b` on
  `codex/neclip-product-reset`; public and installed NeClip remain 1.4.0.
- 2026-09-01: Three read-only tracks covered all retained research/promises,
  source reachability and hot paths, and Git/secrets/dependencies/releases.
- 2026-09-01: Found stale 1.6.0/build 10 test assertions against the actual
  1.6.1/build 11 plist, so the previous 130-test result cannot prove HEAD.
- 2026-09-01: Found full snippet bodies retained by menus/editor lists, stale
  RTF surviving a newer plain-text copy, and incomplete-ref secret scanning.
- 2026-09-01: Reproduced that an invalid 40-character GitHub canary is ignored,
  then verified the documented 36-character GitHub PAT pattern plus AWS and
  Slack canaries are detected by the pinned Gitleaks binary. The release gate
  will generate valid canaries and require non-zero detector exits.
- 2026-09-01: Full XCTest remains externally blocked by the incomplete Apple
  Command Line Tools installation; strict application compilation remains
  available through the previously verified temporary SDK projection.
- 2026-09-01: Implemented bounded snippet summaries/on-demand bodies, local
  write limits, latest-copy RTF semantics, lossless pasteboard snapshots,
  reduced redundant automatic AX reads and repaired version/audit contracts.
- 2026-09-01: Debug, strict complete-concurrency release, ASan and TSan
  application builds passed after the final source changes. All source/test
  files parse; plist, JSON and diff checks pass.
- 2026-09-01: Gitleaks canaries passed; publishable tree, 30 HEAD-reachable and
  two side-ref-only commits are clean. Local dangling histories are clean. The
  sole fsck garbage item was an empty worktree metadata directory and was
  removed safely; fsck now reports only the retained dangling commits.
