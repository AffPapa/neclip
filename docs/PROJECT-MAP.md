# NeClip project map

Current public release: **3.0.0 / build 55**. The exact signed artifacts,
source commit and release checks are recorded in
[RELEASE-3.0.0-STATUS.md](RELEASE-3.0.0-STATUS.md).

## Runtime ownership

- `StatusBarController` and `AppDelegate` own the menu-bar lifecycle.
- `ClipboardMonitor`, `Storage` and the privacy filters keep history local and
  fail closed when source attribution is unsafe.
- `Storage` and `SnippetsEditorModel` own folders, snippets and draft-safe
  writes.
- `HotKeyCoordinator` owns configurable global shortcuts and conflict handling.
- `PasteService` owns clipboard snapshots, generation guards and optional automatic paste.
- `SnippetTextEditor` and `SnippetRenderer` own native editing, document-scoped undo and local templates.
- `PreferencesWindow` exposes general, shortcuts, privacy, data and access settings.
- `Settings.removeRetiredPreferences` deletes only named obsolete preferences on upgrade; database schemas are unchanged.

## Release boundary

Only `v3.0.0` is supported publicly. Its immutable GitHub release contains both
the signed, notarized DMG and ZIP; `docs/version.json` records their URLs,
SHA-256 digests and sizes. The release tag points to the exact source commit in
`main`. Verify downloaded bytes before changing either public link.
