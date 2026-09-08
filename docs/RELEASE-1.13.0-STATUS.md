# NeClip 1.13.0 / build 20 — release status

## Product change

NeClip 1.13 keeps the menu-bar-first, local-only workflow and removes two
secondary modes that made the history menu harder to understand:

- no pin state, pinned-history section, unpin command or option-click inspector;
- one chronological history list with ordinary paste on every row;
- the snippet editor keeps only title, folder, text and automatic save. The
  secondary duplicate button was removed so the editing path is immediately
  obvious.

Existing databases receive migration `v8-retire-pins`. It clears legacy pin
flags without deleting clips or snippets. Imported snippets never recreate the
retired flag. Schema columns remain only so older databases and exports can be
read safely.

## Release gates

The final release record is generated from the exact signed commit and the
artifact checksum in `docs/version.json` after the build script completes.
The gate covers Swift 6 tests, strict warnings-as-errors build, Developer ID,
app and DMG notarization, stapling, Gatekeeper, mounted-DMG verification,
GitHub history secret scanning and public download checksum verification.

Rollback target: the immutable NeClip 1.12.0 release.
