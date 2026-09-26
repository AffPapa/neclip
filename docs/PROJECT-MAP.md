# NeClip project map

Current public release: **2.8.5 / build 51**. The exact signed artifacts,
source commit and release checks are recorded in
[RELEASE-2.8.5-STATUS.md](RELEASE-2.8.5-STATUS.md).

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

Only `v2.8.5` is supported publicly. `docs/version.json` records its DMG and
supplemental ZIP URLs, SHA-256 digests and sizes. The original immutable GitHub
release contains the DMG; an explicitly labelled supplemental immutable release
contains the matching notarized app ZIP. The archive and release page are linked
from the download instructions. Verify downloaded bytes before changing either
public link.
