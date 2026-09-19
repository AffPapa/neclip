# NeClip project map

Current public release: **2.8.3 / build 49**. The exact signed artifact,
source commit and release checks are recorded in
[RELEASE-2.8.3-STATUS.md](RELEASE-2.8.3-STATUS.md).

## Runtime ownership

- `StatusBarController` and `AppDelegate` own the menu-bar lifecycle.
- `ClipboardMonitor`, `Storage` and the privacy filters keep history local and
  fail closed when source attribution is unsafe.
- `Storage` and `SnippetsEditorModel` own folders, snippets and draft-safe
  writes.
- `HotKeyCoordinator` owns configurable global shortcuts and conflict handling.
- `OptionKeyCorrectionMonitor` owns the explicit standalone Option gesture;
  `StatusBarController` and `PreferencesWindow` expose its opt-in state.
- `ScreenshotCoordinator`, `ScreenshotSelectionView` and
  `ScreenshotEditorWindow` own one-shot area/full-screen capture, annotation
  and export.
- `ScreenshotRenderer` and `ScreenshotPresentation` share the bounded pixel
  composition used by preview, copy and file export.

## Release boundary

Only `v2.8.3` is supported publicly. Its download URL, SHA-256 and build number
are in `docs/version.json`; GitHub Pages, the repository and GitHub Release must
all agree before publication.
