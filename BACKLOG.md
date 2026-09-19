# NeClip public roadmap

NeClip remains a small local macOS utility: clipboard history, snippet folders
and safe EN/RU layout correction. Accounts, cloud sync, subscriptions,
telemetry, advertising and AI processing are not planned.

## Current public release — 2.8.2 / build 48

Released 19 September 2026 after the normal Developer ID, notarization,
stapling, Gatekeeper, mounted-DMG, independent public-download and required-CI
gates. [Download NeClip 2.8.2](https://github.com/AffPapa/neclip/releases/download/v2.8.2/NeClip-2.8.2.dmg)
and read the [release evidence](docs/RELEASE-2.8.2-STATUS.md).

- Save any text history item as a raw-text snippet with folder selection and duplicate checks.
- Search local history with bounded text, type, application and date filters.
- Use explicit original/plain/copy-only paste actions and inspect capture status.
- Keep screenshot export format and safely back up or restore the local database.
- Preview snippet tokens and install/remove bilingual starter snippets.
- Choose how many recent buffers appear in the first list; older buffers stay
  available in one flat «Ещё из истории» submenu.
- Correct a selected text or last entered word with an optional standalone
  Option (Alt) release, and toggle both correction modes directly from the menu bar.
- Analyze live EN/RU input before Space using local dictionaries from four characters,
  verified multiline range replacement and bounded editor-readiness retries.
- Keep search cancellation, restore cleanup and screenshot editing predictable under
  delayed menu, database and accessibility events.

## Current verification priorities

- Confirm physical-keyboard live correction and standalone Option across supported
  editors; targeted synthetic UI input does not establish global-key behavior.
- Verify permissions and screen capture across additional supported macOS versions
  and physical display configurations.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

- Accounts, cloud sync, subscriptions, telemetry or advertising.
- AI processing of clipboard contents.
- A permanent Dock window, cloud search, tags or smart collections.
