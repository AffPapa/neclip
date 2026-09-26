# NeClip release and search visibility loop

## User request and working prompt

Act as a native macOS Direct Distribution release lead, technical SEO architect,
and evidence-based product comparison editor. Recheck the current NeClip source,
GitHub releases, app packages, GitHub Pages, and alternative-comparison content.
Improve the homepage and comparison search intent without unsupported claims or
thin doorway pages. Produce DMG and installable ZIP artifacts where appropriate,
publish only after source, signature, notarization, security, SEO, and rollback
gates pass, then verify the public files and pages again.

## Included / excluded

- Included: current supported release, app ZIP availability and future release
  packaging, version/source/download coherence, homepage and comparison hub,
  live release/site verification, secrets and artifact checks.
- Excluded: App Store distribution, deleting historical releases/tags, claiming
  rankings or search volume without evidence, benchmarking competitors not
  installed, or using unverified credentials.
- Historical releases: add ZIPs only when the exact tagged app can be retrieved
  and its signature/notarization can be independently validated; never rebuild a
  different binary under an old release tag.

## Roles and ownership

- Direct Distribution release engineer: read-only release/provenance audit.
- Technical SEO architect: read-only route, crawl, metadata, and intent audit.
- Search-intent analyst/editor: read-only official-source alternative research.
- Parent: synthesis, code/content edits, checks, build/package, publication, and
  live re-audit.

## Acceptance gates

1. Current source commit, current release, app artifacts, and version metadata agree.
2. Every package advertised for a release exists under its immutable GitHub tag
   and has an independently verified digest, valid Developer ID signature,
   notarization, stapled ticket, and Gatekeeper acceptance after extraction or
   mount. v2.8.5 is immutable and DMG-only; the ZIP pipeline is for a future
   release published with all assets attached from the start.
3. Homepage owns the NeClip/product intent; comparison hub owns alternatives and
   competitor queries; every claim links to current official sources. No fake
   ratings, fabricated search demand, keyword stuffing, or duplicate doorway pages.
4. Unique metadata, canonicals, schema, internal links, sitemap, and local tests
   pass; stale release facts are corrected.
5. Protected CI/security checks pass; exact public assets and live HTML/manifest
   are checked after publication. Retain the previous signed app and rollback.
6. Report verified, partial, blocked, and unverified items separately. If live
   GitHub or Apple verification is unavailable, do not claim a completed release.

## Stop conditions

Stop publishing if exact source/artifact provenance, signing, notarization,
Gatekeeper, required CI, or rollback cannot be established. Preserve existing
releases and tags; use additive artifacts only when their evidence is complete.
