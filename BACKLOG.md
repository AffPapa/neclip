# NeClip public roadmap

NeClip remains a small local macOS utility: clipboard history, snippet folders
and safe EN/RU layout correction. Accounts, cloud sync, subscriptions,
telemetry, advertising and AI processing are not planned.

## Current public release — 2.8.7 / build 53

Released 26 September 2026 after required Swift CI, CodeQL and secret scan; Developer ID signing, Apple notarization, stapling, Gatekeeper, mounted-DMG and independent public-download checks passed. Download the [NeClip 2.8.7 DMG](https://github.com/AffPapa/neclip/releases/download/v2.8.7/NeClip-2.8.7.dmg) or [ZIP archive](https://github.com/AffPapa/neclip/releases/download/v2.8.7/NeClip-2.8.7.zip). See [release evidence](docs/RELEASE-2.8.7-STATUS.md).

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
- Recheck deferred paste generations, import only validated backup records and
  atomically publish private backup files without changing existing folder permissions.
- Keep screenshot crop/format/text consistent and add optional light/dark
  backgrounds with unchanged source pixels and a compact two-row toolbar.

- Complete screenshot export even if the editor window hides during encoding.
- Reduce candidate scanning for large brace-heavy snippets.

## Current verification priorities

- Fixed native Return routing, explicit snippet history, protected clipboard
  provenance, queued exclusions, file-path search and draft merge races in 2.8.4.
- Verified the native Save dialog with synthetic PNG/JPEG, cancel/reopen,
  undo/redo and successful-format persistence. This does not prove screen capture.

Remaining:

- Confirm physical-keyboard live correction and standalone Option across supported
  editors; targeted synthetic UI input does not establish global-key behavior.
- Verify permissions and screen capture across additional supported macOS versions
  and physical display configurations.
- Complete multi-monitor/Spaces and real ScreenCaptureKit permission/cancellation
  checks; synthetic images do not establish these hardware/user scenarios.
- Measure menu latency before changing storage or browse limits.

These are verification priorities, not promises of new features.

## Not planned

- Accounts, cloud sync, subscriptions, telemetry or advertising.
- AI processing of clipboard contents.
- A permanent Dock window, cloud search, tags or smart collections.
