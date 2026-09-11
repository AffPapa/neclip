# NeClip

NeClip is a small, local-first macOS utility: copy, choose a recent item or a ready-made snippet, paste.
It has no account, cloud sync, telemetry, subscription, or background network
traffic. A network request is made only when the user explicitly chooses
**Check for Updates**.

NeClip is a menu-bar-only app: its icon stays in the macOS menu bar and no
application icon is added to the Dock.

Current public, signed and notarized version: **2.5.3 (build 32)**,
released on 10 September 2026. Snippet folders appear directly in the menu;
search, new pins and implicit top-item actions are removed.
Its [release evidence](docs/RELEASE-2.5.3-STATUS.md) and
[menu design decisions](docs/MENU-SIMPLIFICATION-2026-09-07.md) record the scope
and verification. Both the app and DMG passed notarization, stapling and
Gatekeeper. The independently downloaded public artifact matched the verified
checksum and complete app contents. Publishing did not replace the installed
application or modify its database.
See [CHANGELOG.md](CHANGELOG.md) for source changes and [BACKLOG.md](BACKLOG.md)
for the intentionally small public roadmap.

The current module ownership and invariants are in
[docs/PROJECT-MAP.md](docs/PROJECT-MAP.md). The latest scoped changes and Apple
design sources are in
[docs/MENU-SIMPLIFICATION-2026-09-07.md](docs/MENU-SIMPLIFICATION-2026-09-07.md).
The refreshed comparison of 19 clipboard products, 11 layout tools, 100
candidate improvements and 27 selected refinements is in
[docs/RESEARCH-2026-09-05.md](docs/RESEARCH-2026-09-05.md).

[Download the signed and notarized NeClip 2.5.3 DMG](https://github.com/AffPapa/neclip/releases/download/v2.5.3/NeClip-2.5.3.dmg)
(2,042,306 bytes).
SHA-256:
`b950b17a35d942a4eb8a34e375642d0ad86a6757a1b405b5d588464c528c5bcd`.
It is also published beside the DMG and in [`docs/version.json`](docs/version.json).

Artifact source is recorded in the exact release JSON beside the DMG. Required
CI and CodeQL are required before the tag is published. The release gate covers
debug, strict release, ASan, TSan, notarization, stapling, Gatekeeper and the
mounted-DMG check.

## Everyday workflow

NeClip is for immediate reuse, not managing a searchable archive.
The [optimization report](docs/OPTIMIZATION-2026-09-06.md) compares
eight products and records selective menu refresh, simpler retention settings,
distribution-symbol stripping and measured results. No new dependency is added.

- `Command-Shift-V` — open the native history menu at the pointer (customizable)
- `Command-Shift-B` — open snippet folders directly (customizable)
- right-click the menu-bar icon — open snippet folders without a keyboard
- `Up` / `Down`, `Left` / `Right` — select items and navigate folders
- `Return` — use the selected item; without Accessibility it is copied for manual paste
- `Option-Shift-L` — correct the selected text or the word left of the cursor; repeat to undo (customizable)
- `Control-Option-A` — turn automatic correction off immediately (customizable, off-only)
- `Control-Command-V` — paste the next recent value in sequence (customizable)
- `Command-1` … `Command-9` — use one of the first nine history items
- `Option-click` — inspect the chosen history item; its text can be saved as a snippet
- `Escape` — close the menu

The first ten recent items are inline; up to 100 are browsable in one compact
**More from History** hierarchy, grouped by tens. Up to 100 pinned items use the
same bounded hierarchy. The menu explicitly labels the 100-item window without
promising access through a removed search field. Existing stored values are not
deleted by this UI change. The snippet hotkey shows up to 200 snippets in folders
directly, without an outer folder submenu or a duplicate quick list. Folder
order matches the editor and no longer changes after pasting. For larger imported
libraries, an overflow hint points to the complete editor. Implicit top-item actions
and new pin creation are removed. Existing protected clips remain accessible in
**Previously Pinned**; Option-click opens their explicit Unpin button with a
retention warning. Unpinning alone never deletes a record.
Lower-frequency capture, cleanup, sequential-paste, layout and update controls
are grouped under **Management**, followed by snippet editing, Settings and Quit.

If macOS or another application already owns a NeClip global shortcut, the menu
explains which combination is unavailable and keeps the equivalent command
accessible from the menu bar. All five global shortcuts can be recorded locally
in the **Keys** Settings tab; a conflicting candidate never replaces the
previous working one.

In the snippet editor, `Command-N` creates a snippet in the active folder and
`Command-D` duplicates it. Only name, folder and text are editable; there is
no search field or search key. The visible **Restore Snippet** action undoes the last deletion. Explicit
full-data erasure clears undo and drafts too. Templates support `{date}`,
`{time}`, `{clipboard}`, `{date:iso}` and `{time:iso}`; `{{date}}` inserts the
literal `{date}`. Expanded output is capped at 2 MB and never silently truncated.

Menu labels use one system appearance whether opened from the status item or a
global shortcut. Long text is collapsed to one line and shortened after a
user-defined 16–96 character limit (64 by default) without cutting an emoji or
combined Unicode character.

Search fields, query parsing, filters, fuzzy ranking and background full-text
indexing have been removed. The v7 migration drops only derived search tables,
triggers and the keyword uniqueness index. Old database key values remain inert;
legacy JSON keys are ignored on import and omitted on export. Existing snippet
text, folders and pins remain intact. Do not open a migrated database with an
older NeClip build; keep a pre-upgrade database copy for rollback.

The selected-item inspector supports preview/edit/rename and safe URL or file
opening. Text-transform tools and implicit first-item deletion were removed.
NeClip never infers that a receiving application accepted an injected paste.
Sequential paste needs no collection mode: the first invocation
captures a stable list of the 50 latest database identifiers, each successful
invocation advances once, and the sequence resets after 30 seconds or a new
external copy. Clipboard content is not duplicated.

Settings are split into five compact sections: **General**, **Keys**, **Privacy**,
**Layout**, and **Data**. Permission recovery, capture exclusions, and local
data controls no longer compete with everyday history options in one long form.

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
logged, saved or sent over the network. Undoing a false automatic correction
adds only that normalized token to a bounded memory-only ignore list until the
app restarts.

An independent, default-off setting can remember the last selected input source
for up to 200 applications. It observes only application activation and the
system input-source notification; it does not read text or key events and does
not need Input Monitoring. Settings shows the local mapping count and provides
one reset button.
The menu can also pin the current system input source to the application that
was active before NeClip opened. A fixed rule wins over last-used memory on the
next application activation, still reads no text or key events, and can be
removed from the same menu or reset in Settings.

Automatic correction needs separate Input Monitoring and Accessibility access
from macOS. NeClip requests them only when the user turns the feature on;
disabling it removes the event tap. The dedicated safety shortcut only turns
this mode off; it can never enable monitoring or open a permission prompt.

The focused snippet editor shows every folder, empty folders and **Unfiled** in
one compact sidebar. It selects the top visible snippet on open; every complete
native list row selects the clearly labelled fields on the right and arrow keys
follow the same visible order. Snippets can be edited and moved; folders can be
created, renamed and removed. Removing a folder keeps its snippets in
**Unfiled**. Changes save automatically, pending edits are flushed before
navigation or close, and a failed save remains visible instead of discarding
the draft. Menus and the sidebar retain only bounded previews; the
complete text is loaded from SQLite only when one snippet is opened or pasted.

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
The explicit **Append Next Text** action joins the next accepted text value to
the latest unpinned text record with one newline. Images, files and rejected
sensitive or oversized text do not consume the one-shot action; incompatible
RTF is discarded and an over-limit combined value is safely stored separately.

Manual selection replacement uses a compare-and-swap pasteboard transaction:
NeClip proceeds only after every advertised representation has been captured,
then restores the previous multi-item pasteboard only if no other app copied
something in the meantime. Automatic correction never uses the pasteboard.

History is bounded by both an item limit and a hard 250 MB byte quota. Pinned
items and snippets are preserved when ordinary history is trimmed. If pinned
items alone fill the quota, NeClip stops accepting new history until space is
freed instead of silently deleting pins or growing without a limit.
An optional age limit removes only ordinary history. Image capture can be
disabled independently, and user-defined literal phrases can reject sensitive
text before any database write. These checks are local and do not use regexes,
telemetry, network services or AI.
The maximum captured text-record size is user-adjustable from 64 to 2048 KB.
History can be cleared for the last hour, for today, or completely while
retaining pins and snippets. An optional privacy toggle clears unpinned history
on quit and cancels termination if deletion cannot be confirmed.

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
publish any artifact produced outside that gate. It accepts either the
`NECLIP_NOTARY_PROFILE` Keychain profile or a non-persistent App Store Connect
API key through `NECLIP_NOTARY_KEY_PATH` and `NECLIP_NOTARY_KEY_ID`; Team keys
also provide `NECLIP_NOTARY_ISSUER`.

The sole source dependency is GRDB.swift 7.11.1, pinned exactly. Global
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
