# NeClip

A local macOS menu-bar utility for clipboard history, snippet folders, EN/RU
layout correction and screenshots with markup. macOS 14+ on Apple Silicon.
No accounts, cloud sync, telemetry, advertising or AI processing of your content.
Update checks run only when you explicitly request them.

## Download

Current supported release: **2.5.8 (build 37)**,
released on 12 September 2026.

[Download NeClip 2.5.8](https://github.com/AffPapa/neclip/releases/download/v2.5.8/NeClip-2.5.8.dmg)
(2,044,866 bytes). Open the DMG, drag NeClip to Applications and launch it there.
Its icon appears in the menu bar, without a permanent Dock icon.

SHA-256: `05aec85af50286de2b4051041775e48b14d8d33b74a484cb7706531b6ebaec21`.
Artifact source: `b66c7e55d267e7a159bb951798ddc34ead97abed`.

The app and DMG are Developer ID signed, notarized and stapled.
[Release evidence](docs/RELEASE-2.5.8-STATUS.md) records the verification boundary.
[Website](https://affpapa.github.io/neclip/) · [Changelog](CHANGELOG.md) ·
[Verification priorities](BACKLOG.md) · [Security](SECURITY.md).

## Everyday use

Copy something, open history, select a record and press Return. With Accessibility
permission NeClip posts a paste to the original application; without it, the item
is copied for manual paste. Command-Return copies without pasting and Shift-Return
uses plain text. A changed target prevents automatic paste.

| Default shortcut | Action |
|---|---|
| Command-Shift-V | History |
| Command-Shift-B | Snippet folders |
| Command-Shift-2 | Area screenshot |
| Command-Option-3 | Full-screen screenshot |
| Control-Command-V | Next recent item in sequence |
| Option-Shift-L | Manual EN/RU correction; repeat to undo |
| Control-Option-A | Turn automatic correction off |

All seven global shortcuts are configurable. Conflicts keep the previous working
registration and show a menu fallback. Right-click the menu-bar icon for snippets.
History shows ten items inline and up to 100 in total; snippet menus show up to
200 entries, with the complete library available in the editor. There is no search
or pin interface. Less frequent commands are under **Ещё…**.

Snippet folders support creation, renaming and removal; removing a folder keeps
its snippets unfiled. The editor saves drafts before navigation and closing,
retains failed saves for retry, and can restore the last deleted snippet.
Templates support `{date}`, `{time}`, `{clipboard}`, `{date:iso}` and `{time:iso}`;
`{{date}}` inserts literal text. Expanded output is limited to 2 MB.

Screenshots capture the display under the pointer only after your command.
Escape cancels area selection. The editor offers opaque redaction, pen, arrow,
rectangle and text, five colours, undo/redo, copy and PNG/JPEG save. Exports contain
flattened pixels, without editable layers or original image metadata. Oversized
displays are proportionally downscaled to a 32 MP working-image limit.

## Privacy and recovery

Images are stored without automatic OCR or other content recognition. Existing
image bytes and legacy metadata remain intact; normal retention rules still apply.

- History stays in `~/Library/Application Support/NeClip/neclip.sqlite`.
  Removing the app bundle does not delete your data.
- Concealed/transient clipboard types and protected password-manager sources
  are excluded. Unknown source attribution fails closed. Pause capture or use
  Ignore Next Copy for other sensitive content; not every source marks it safely.
- On macOS 15.4+, denied pasteboard access stops background reads. Permission
  recovery is available in Settings. Accessibility is optional for ordinary use.
- Automatic EN/RU correction is experimental and off by default. It requests
  Input Monitoring and Accessibility only when enabled, acts conservatively after
  Space, and rejects secure fields, terminals, IDEs, remote clients and uncertain
  focus. Typed tokens remain in bounded memory. Manual correction preserves the
  previous clipboard only while its generation is unchanged.
- Optional per-application input-source memory observes layout and app changes,
  without reading key events. Existing fixed rules remain resettable in Settings.
- History has count, age and byte limits; snippets have separate limits. Migration
  retires legacy pins, so they follow ordinary retention. Export important snippets
  and keep a database backup before upgrading; do not reopen migrated data in an
  older build. Failed database startup falls back to visibly temporary storage.
- Screen Recording is requested only for screenshots. Saving asks for a destination;
  cancelling capture does not publish an image. Update checks fetch only the exact
  GitHub Pages manifest, reject redirects and oversized/non-JSON replies, and allow
  download links only to this repository's GitHub Releases.

## Development and release

Full Xcode and Swift 6.2+ are required. The sole source dependency is GRDB.swift
7.11.1, pinned exactly. See [third-party notices](THIRD_PARTY_NOTICES.md) and the
[project map](docs/PROJECT-MAP.md).

```sh
scripts/secret-scan.sh
swift test --disable-sandbox
swift test --disable-sandbox -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
ruby scripts/verify-site.rb
ruby scripts/test-site.rb
```

Runtime releases additionally require ASan/TSan, a reviewed PR and every required
GitHub check before merge. `build-app.sh` builds the exact commit specified by
`NECLIP_RELEASE_COMMIT`, signs arm64, notarizes and staples both app and DMG, checks
Gatekeeper and the mounted image, then stages the checksum and provenance JSON.
Use the configured notarization credentials without putting them in the repository.
Publish only through GitHub Releases, then update GitHub Pages after independently
downloading and verifying the public artifact. There is no Mac App Store channel.

[`docs/version.json`](docs/version.json) identifies the supported artifact;
[`docs/project.json`](docs/project.json) links the public metadata. Run
`scripts/clean-local-artifacts.sh` to remove reproducible build/QA caches and obsolete
release links. It preserves the current release archive and application data.

MIT. See [LICENSE](LICENSE).
