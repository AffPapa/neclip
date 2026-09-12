# NeClip 2.5.7 / build 36 — release evidence

## Fix and provenance

AppKit transfers first responder from NSTextField to its shared field editor
when editing starts. The former resignFirstResponder handler treated this as a
finished edit and removed the empty input. Native field-editor delegate callbacks
now commit the live draft exactly once or cancel it on Escape. Export and the
unsaved-changes close check commit active text before inspecting annotations.

- Reviewed runtime PR: [#38](https://github.com/AffPapa/neclip/pull/38).
- Source and runtime merge commit: `3b0adfcf87230081501674f989185b5521c08983`.
- GitHub Release: [v2.5.7](https://github.com/AffPapa/neclip/releases/tag/v2.5.7), published 12 September 2026.
- DMG: `NeClip-2.5.7.dmg`, 2,047,427 bytes.
- SHA-256: `f013fef2f6f86cbdbd2d54e9200d0b462b20816e10d8c910830813fa2e8bda9c`.

## Verification

- The native-focus and active-text export regressions failed before their fixes.
- Debug, strict Swift 6 release, ASan and TSan each passed 279 XCTest
  (four expected opt-in/platform skips) and three Swift Testing tests.
- The screenshot suite includes 26 tests. Storage, migrations, privacy,
  hotkey conflicts, fail-closed layout correction and bounded update transport
  passed their regression suites.
- Required Swift CI, Secret Scan and CodeQL checks passed before normal merge.
- The exact merged commit passed the release script: Developer ID signing,
  notarization, app and DMG stapling, strict codesign, Gatekeeper and mounted-DMG
  validation. An independent anonymous download matched the checksum and size.
- The installed app was verified against the mounted public DMG. User application
  data was preserved.
- Native synthetic-image QA verified text entry, Enter, focus loss, Escape,
  redaction and undo/redo. An isolated product QA run verified snippet folder
  creation, editing, deletion/restore, settings draft cancellation/application,
  hotkey conflict rejection and the copy-only explanation without Accessibility.
- Full-history and side-ref secret scanning and the public metadata/link gate
  passed. The gate has seven regression tests including a future candidate
  retaining the verified public download.

## Verification boundary

Native automation lost access to the system screenshot Save dialog; completing
that dialog interactively is not claimed. Flattened PNG/JPEG output, write failure
handling and clipboard generation protection passed automated tests. This audit
does not claim a complete hardware matrix of supported macOS versions, physical
mixed-scale displays, Space switching or permission prompts.

Only the current release is supported. Older release evidence is retired with
its download links; Git history retains the development record.
