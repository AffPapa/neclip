# NeClip project map

Current public release: **2.8.6 / build 52**. The exact signed artifacts,
source commit and release checks are recorded in
[RELEASE-2.8.6-STATUS.md](RELEASE-2.8.6-STATUS.md).

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

Only `v2.8.6` is supported publicly. Its immutable GitHub release contains both
the signed, notarized DMG and ZIP; `docs/version.json` records their URLs,
SHA-256 digests and sizes. The release tag points to the exact source commit in
`main`. Verify downloaded bytes before changing either public link.
