# NeClip project map

Current public release: **2.6.0 / build 38**. The exact signed artifact,
source commit and release checks are recorded in
[RELEASE-2.6.0-STATUS.md](RELEASE-2.6.0-STATUS.md).

## Runtime ownership

- `StatusBarController` and `AppDelegate` own the menu-bar lifecycle.
- `ClipboardMonitor`, `Storage` and the privacy filters keep history local and
  fail closed when source attribution is unsafe.
- `Storage` and `SnippetsEditorModel` own folders, snippets and draft-safe
  writes.
- `HotKeyCoordinator` owns configurable global shortcuts and conflict handling.
- `ScreenshotCoordinator`, `ScreenshotSelectionView` and
  `ScreenshotEditorWindow` own one-shot area/full-screen capture, annotation
  and export.

## Release boundary

Only `v2.6.0` is supported publicly. Its download URL, SHA-256 and build number
are in `docs/version.json`; GitHub Pages, the repository and GitHub Release must
all agree before publication.
