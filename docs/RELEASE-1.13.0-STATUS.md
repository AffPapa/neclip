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

The exact source commit is `e133ed05544e58b2c686192b2662f67afd221d54`.
The signed DMG is 1,963,971 bytes with SHA-256
`5212d82fffae0ef7ba9d744fd7bdc29961ad7419d92ef00a7fc695f0ff17de2a`.
The gate covers 247 XCTest cases, 4 opt-in skips, 3 Swift Testing checks,
strict warnings-as-errors build, Developer ID, app and DMG notarization,
stapling, Gatekeeper, mounted-DMG verification, GitHub history secret
scanning and public download checksum verification.

Rollback target: the immutable NeClip 1.12.0 release.
