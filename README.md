# NeClip

NeClip is a small, local-first clipboard history and snippet manager for macOS.
It has no account, cloud sync, telemetry, subscription, or background network
traffic. A network request is made only when the user explicitly chooses
**Check for Updates**.

NeClip is a menu-bar-only app: its icon stays in the macOS menu bar and no
application icon is added to the Dock.

Current source version: **1.3.2 (build 7)**. See [CHANGELOG.md](CHANGELOG.md)
for shipped changes and [BACKLOG.md](BACKLOG.md) for the intentionally small
public roadmap.

The reproducible three-track audit, decisions and release gates for this cycle
are published in [docs/AUDIT-2026-08-31.md](docs/AUDIT-2026-08-31.md).

[Download the signed and notarized NeClip 1.3.1 DMG](https://github.com/AffPapa/neclip/releases/download/v1.3.1/NeClip-1.3.1.dmg).
SHA-256: `da63b10ed6a538f5608e0dc7af898a3b5604493a76157fc8ed4dbcaf00fffdf6`.

## Keyboard workflow

- `Command-Shift-V` — open the native history menu at the pointer
- `Command-Shift-B` — open snippet folders directly
- type immediately — search inside the menu (digits and punctuation work)
- `Up` / `Down` — leave search; continue with arrows through native menu items
- `Return` — use the first visible result, or copy when Accessibility is unavailable
- `Shift-Return` — paste as plain text
- `Command-Return` — copy without pasting
- `Control-Return` — correct EN/RU layout and paste a text history item
- `Option-Shift-L` — correct the selected text or the word left of the cursor; repeat to undo
- `Command-1` … `Command-9` — select a visible result
- `Command-P` — pin or unpin the first visible result
- `Command-S` — save the first visible text result as a snippet
- `Command-Delete` — delete the first visible result
- `Command-Z` — restore the last individually deleted item
- `Escape` — clear search, then close

The first ten recent items are inline; items 11–40 are grouped by tens. Up to
20 pinned items have their own submenu. The snippet hotkey shows nine quick
items first and then the full folder hierarchy. The history menu also contains
an explicit **Actions for First Result** submenu, pause, ignore-next-copy,
clear, preferences, snippet
editing, the manual update check, and quit.

If macOS or another application already owns one of NeClip's three global
shortcuts, the menu explains which combination is unavailable and keeps the
equivalent command accessible from the menu bar.

## Keyboard layout correction

NeClip builds its EN/RU mapping from the enabled macOS keyboard layouts instead
of assuming fixed keys. Manual correction works in editable fields that expose
a safe text range through macOS Accessibility; corrected history paste remains
available everywhere NeClip can paste. Automatic
correction is an experimental, explicit opt-in: it listens only while enabled,
acts only after Space and only for a high-confidence dictionary decision, and
does not intercept Enter. Password managers, secure fields, terminals, IDEs,
remote-desktop clients, unknown focus, input methods, dead keys, and ambiguous
tokens fail closed. Typed tokens stay in a bounded RAM buffer and are never
logged, saved, learned, or sent over the network.

Automatic correction needs separate Input Monitoring and Accessibility access
from macOS. NeClip requests them only when the user turns the feature on;
disabling it removes the event tap.

## Local data and privacy

Data is stored in `~/Library/Application Support/NeClip/neclip.sqlite`.
Uninstalling the app bundle does not remove that database; use the in-app clear
actions or remove the Application Support folder deliberately.

On macOS 15.4 and later, the system controls background access to the General
pasteboard. NeClip explains this before monitoring starts, recommends **Always
Allow** for continuous history, checks `NSPasteboard.accessBehavior` before
reading representations, and fails closed when macOS reports **Always Deny**.
The menu-bar icon and Settings show how to recover without reinstalling the app.

NeClip ignores pasteboard items marked concealed or transient, blocks common
password-manager bundle identifiers by default, and fails closed while source
application attribution is uncertain. Because not every app marks sensitive
clipboard content correctly, pause capture or use **Ignore Next Copy** when
handling data that must not enter history.

Manual selection replacement uses a compare-and-swap pasteboard transaction:
the previous multi-item pasteboard is restored only if no other app copied
something in the meantime. Automatic correction never uses the pasteboard.

History is bounded by both an item limit and a hard 250 MB byte quota. Pinned
items and snippets are preserved when ordinary history is trimmed. If pinned
items alone fill the quota, NeClip stops accepting new history until space is
freed instead of silently deleting pins or growing without a limit.

## Build and test

Requirements: macOS 14+, Swift 6.2+, and full Xcode.

```sh
swift build
swift test
```

`build-app.sh` is the release-only Developer ID/notarization workflow. It
preflights credentials before touching `dist`, runs tests and a strict Swift 6
release build, signs inside-out, notarizes and staples both the app and DMG,
verifies Gatekeeper against the exact mounted image, and writes SHA-256. Do not
publish any artifact produced outside that gate.

The sole source dependency is GRDB.swift 7.10.0, pinned exactly. Global
shortcuts use the native Carbon registration API. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Website

The standalone, account-free project landing is in [`docs/`](docs/) and is
ready for GitHub Pages. It contains versions, release checks, the public backlog,
privacy behavior, shortcuts and stable source/release links.

## GitHub source of truth

GitHub is the only NeClip release and update source. The app checks for updates
only when the user asks, using
[`docs/version.json`](https://affpapa.github.io/neclip/version.json), and accepts
downloads only from this repository's GitHub Releases.

Website and integration consumers should start with
[`docs/project.json`](https://affpapa.github.io/neclip/project.json). It links to
the canonical version manifest, changelog, backlog, security policy, source and
release feed plus the current engineering audit. See
[`docs/INTEGRATION.md`](docs/INTEGRATION.md) for the publication
contract. Files under `landing/` are no longer part of NeClip.

## License

MIT. See [LICENSE](LICENSE).
