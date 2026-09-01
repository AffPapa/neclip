# NeClip GitHub publication contract

GitHub is the only source of truth for NeClip product and release information.
External websites should not infer versions from filenames or copy values from
an unrelated host.

## Entry points

- `project.json` — stable product metadata and links to every canonical feed.
- `version.json` — latest public, signed and notarized release only.
- `changelog.json` — machine-readable release history.
- `CHANGELOG.md` — detailed human-readable changes and verification status.
- `BACKLOG.md` — public completed, next and explicitly rejected work.
- `docs/PROJECT-MAP.md` — current runtime ownership, data flows and invariants.
- `docs/AUDIT-2026-09-01.md` — current engineering evidence, decisions and
  quality/release gates.
- `docs/COMPETITOR-UX-2026-09-01.md` — current 20-product UX decision matrix.
- GitHub Releases — binary files and checksum assets.

## Release rule

Do not change `version.json` to a new version until its exact DMG has passed
Developer ID signing, Apple notarization, stapling, Gatekeeper verification and
an independent SHA-256 re-download check. The `release` field must use this
exact shape:

`https://github.com/AffPapa/neclip/releases/download/vVERSION/NeClip-VERSION.dmg`

Consumers may cache product copy, but should read `version.json` before showing
a version number or download button. Preserve the statements that NeClip has no
account, cloud sync or telemetry.

Required application fields in `version.json` are `version`, `build`, `release`
and `sha256`. Website consumers may also use `releasePage`, `checksum`,
`sizeBytes`, `publishedAt`, `platform` and `source`. Unknown fields must be
ignored so the contract can grow without breaking older clients.
