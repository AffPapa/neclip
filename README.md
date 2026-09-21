# NeClip — local clipboard history and snippets for Mac

A local macOS menu-bar utility for clipboard history, snippet folders, EN/RU
layout correction and screenshots with markup. macOS 14+ on Apple Silicon.
No accounts, cloud sync, telemetry, advertising or AI processing of your content.
Update checks run only when you explicitly request them.

## Download

Current supported release: **2.8.3 (build 49)**,
released on 19 September 2026.

[Download NeClip 2.8.3](https://github.com/AffPapa/neclip/releases/download/v2.8.3/NeClip-2.8.3.dmg)
(2,134,466 bytes). Open the DMG, drag NeClip to Applications and launch it there.
Its icon appears in the menu bar, without a permanent Dock icon.

SHA-256: `89fd4661aebe93f75a3ed353a371192a53462633abaf98dbc289b94af7b9a523`.
Artifact source: `d210af5f6624a274909eb00de25f28ce1f9ca7b6`.

The app and DMG are Developer ID signed, notarized and stapled.
[Release evidence](docs/RELEASE-2.8.3-STATUS.md) records the verification boundary.
[Website](https://affpapa.github.io/neclip/) · [Changelog](CHANGELOG.md) ·
[Verification priorities](BACKLOG.md) · [Security](SECURITY.md).

## Guides and alternatives

The [20-app comparison](https://affpapa.github.io/neclip/compare.html) groups
Maccy, Paste, Alfred, Raycast and other related Mac tools by clipboard history,
text expansion, automation and screenshots. It is an official-source editorial
selection maintained by the NeClip project, not an independent ranking or a
performance/security benchmark. Sources were checked on 21 September 2026.

- [Find copied text, choose a paste mode and save snippets](https://affpapa.github.io/neclip/guides/clipboard-history.html).
- [Correct an EN/RU typing-layout mistake](https://affpapa.github.io/neclip/guides/keyboard-layout.html).
- [Cover data on screenshots and verify the exported PNG/JPEG](https://affpapa.github.io/neclip/guides/screenshot-redaction.html).

These Russian-language guides use synthetic examples, explain permissions and
limits, and link to the official descriptions of alternatives. Their source HTML,
navigation, metadata and structured data are versioned in this repository.

## Everyday use

Copy something, open history, select a record and press Return. With Accessibility
permission NeClip posts a paste to the original application; without it, the item
is copied for manual paste. Command-Return copies without pasting and Shift-Return
uses plain text. A changed target or clipboard generation prevents deferred automatic paste.

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
An optional standalone Option (Alt) release corrects selected text, or the last
entered word when nothing is selected; Option plus a letter, click or another
modifier remains untouched. Automatic correction analyzes the current word after
each eligible key and no longer waits for a space. The menu bar has direct toggles
for both this gesture and automatic correction. Recognition uses local dictionaries
from four characters onward. Live replacement supports multiline/rich editors with
writable selected-text Accessibility; brief bounded retries handle editor lag.
Secure input, excluded apps and ambiguous words remain guarded.
History shows a configurable number of items inline; the complete remaining history
is in one flat «Ещё из истории» submenu. Use Command-F in the history popup to
search locally by text, type, application and date. Snippet menus show up
to 200 entries, with the complete library available in the editor. Less frequent
commands are under **Ещё…**.

Snippet folders support creation, renaming and removal; removing a folder keeps
its snippets unfiled. The editor saves drafts before navigation and closing,
retains failed saves for retry, and can restore the last deleted snippet.
Templates support `{date}`, `{time}`, `{clipboard}`, `{date:iso}` and `{time:iso}`;
`{{date}}` inserts literal text. Expanded output is limited to 2 MB.

History actions include original-format paste, plain-text paste, copy-only, safe link
opening and one-step saving as a snippet. The menu status center explains capture,
pasteboard, Accessibility and Ignore Next Copy state, and offers timed or indefinite
pause. Screenshots capture the display under the pointer only after your command.
Escape cancels area selection. The editor offers opaque redaction, pen, arrow,
rectangle and text, five colours, undo/redo, copy and PNG/JPEG save. Exports contain
flattened pixels, without editable layers or original image metadata. Oversized
displays are proportionally downscaled to a 32 MP working-image limit, with a visible warning.
Optional light/dark backgrounds add bounded padding and a shadow without resizing
the source pixels. The editor shows actual export dimensions and centers small images.

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
  Input Monitoring and Accessibility only when enabled, analyzes after each
  eligible key, and rejects secure fields, terminals, IDEs, remote clients and
  uncertain focus. Typed tokens remain in bounded memory. Manual correction
  restores the previous clipboard only after replacement is verified and its
  generation is unchanged. An unacknowledged paste does not restore unrelated data;
  the application shows a separate status.
- Standalone Option (Alt) correction is separately opt-in because macOS does not
  represent a modifier-only press as a normal configurable global hotkey. It
  observes only Option flags and cancellation input, never suppresses or mutates
  events, and requires Input Monitoring plus Accessibility for the correction.
- Optional per-application input-source memory observes layout and app changes,
  without reading key events. Existing fixed rules remain resettable in Settings.
- History has count, age and byte limits; snippets have separate limits. Migration
  retires legacy pins, so they follow ordinary retention. Export important snippets
  and keep a database backup before upgrading; do not reopen migrated data in an
  older build. Failed database startup falls back to visibly temporary storage.
- Backup exports are private files, but are not encrypted. Keep them in a trusted
  location. Restore imports validated records into an app-created schema, never
  arbitrary source triggers/tables. Active SQLite sidecars and unknown schemas
  are rejected; use the app's self-contained backup export.
- Portable snippet JSON is merge-only: same-name folders are combined, exact
  duplicates skipped and empty folders omitted. Use a full database backup when
  the complete original library structure must be preserved.
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
