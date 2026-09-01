# NeClip 1.5.0: deep clipboard and keyboard-layout research

Date: 1 September 2026. Scope: 18 clipboard products, 19 keyboard-layout
products and the actual unreleased NeClip source. This is a product decision
record, not a claim that every competitor feature belongs in NeClip.

## Product boundary used for every decision

NeClip remains a fast native macOS menu-bar utility. It has no account, cloud
sync, collaboration, subscription, telemetry, advertising or AI processing.
History and snippets stay local. The interface remains one compact native menu
plus focused Settings, snippet editor and item inspector windows. New behavior
must be discoverable, bounded and reversible.

## Track A — 18 clipboard products

| Product | Strongest useful patterns | Cost or mismatch | NeClip decision |
|---|---|---|---|
| [Apple Clipboard History](https://support.apple.com/en-mide/guide/mac-help/mchl40d5b86b/26/mac/26) | Familiar system search and zero setup | Short system-owned history, no NeClip snippets/layout workflow | Keep NeClip's longer local history and direct paste |
| [Windows Clipboard](https://support.microsoft.com/en-us/windows/apps/using-the-clipboard) | Pins, explicit clear and one memorable shortcut | Small cross-device-oriented surface | Keep pins and simple clear; add partial clear |
| [PowerToys Advanced Paste](https://learn.microsoft.com/en-us/windows/powertoys/advanced-paste) | Plain-text and explicit transforms | AI/network path and large command surface | Keep only deterministic local transforms |
| [Maccy](https://github.com/p0deje/Maccy) | Native popup, immediate typing, numbers, pin/delete, pause | Intentionally narrow snippets/organization | Preserve menu speed and keyboard-first behavior |
| [Raycast Clipboard History](https://manual.raycast.com/clipboard-history) | Type filters, rename/edit, bulk time cleanup, QR extraction | Host-app and paid-retention coupling; AI features | Add time cleanup; keep local search/inspector |
| [Alfred Clipboard](https://www.alfredapp.com/help/features/clipboard/) | Max clip size, app exclusions, clear 5/15 minutes, append-copy | Requires Alfred workflow mental model | Add bounded record size and partial clear |
| [Paste](https://pasteapp.io/help/paste-on-mac) | Source/time metadata, Quick Look, stack, multi-select, pause | Visual timeline, pinboards, sync and larger workspace | Keep inspector and sequential paste; reject board |
| [CleanClip](https://www.cleanclip.cc/docs/manual) | Cursor quick menu, collections, formats, paste queue/form fill | Feature breadth and multiple modes | Keep direct sequential paste; defer form mode |
| [PastePal](https://apps.apple.com/us/app/clipboard-manager-pastepal/id1503446680?platform=mac) | Popup at cursor, queue, screen-share option, granular exclusions | Large configuration surface and iCloud | Keep exclusions; do not promise unreliable share detection |
| [PasteBar](https://github.com/PasteBar/PasteBarApp) | Boards, transformations and saved collections | Board-first workspace and high UI weight | Keep safe transforms only |
| [CopyQ](https://github.com/hluk/copyq) | Tabs, tags, editing, rules and scripting | Scripts/plugins increase attack and learning surface | Reject scripting; keep built-in actions |
| [Ditto](https://ditto-cp.sourceforge.io/) | Mature quick search and keyboard navigation | Windows-oriented UI and networking options | Existing search/hotkeys cover the useful core |
| [ClipboardFusion](https://www.clipboardfusion.com/Features/) | Scrubbing, triggers, preview and app behavior | Macros and sync are out of scope | Keep deterministic local transforms |
| [Clipy](https://github.com/Clipy/Clipy) | Classic ClipMenu sections and snippets | Aging implementation | Preserve this understandable hierarchy |
| [Jumpcut](https://github.com/snark/jumpcut) | Extremely small menu-bar history | Text-only and few management tools | Use as the minimalism ceiling |
| [Flycut](https://github.com/TermiT/Flycut) | Lightweight developer-oriented keyboard history | Narrow text workflow | Existing code search/type filters are enough |
| [Pastebot 3](https://tapbots.com/pastebot/) | Quick menu, stacked filters, smart pastebins, queue and app/type blacklists | macOS 26 floor, sync and broader workspace | Add paste-and-delete; retain simpler queue |
| [ClipClip](https://www.clipclip.com/features) | Local editors, pinned clips, quick menu, transforms | Cloud/folder breadth and Windows UX | Snippet folders already provide saved collections |

### Clipboard findings

The repeated winning pattern is not a board. It is a tiny popup with immediate
search, stable keyboard navigation, explicit privacy controls and a few safe
actions. The most credible gaps in NeClip are: a user-adjustable maximum for a
single text record, cleanup by recent period, an optional session-clean exit and
paste-and-delete for one-time sensitive values. Multi-board UI, background
macros, scripting, collaboration, sync and AI make the product slower to learn
and harder to trust.

## Track B — 19 keyboard-layout products

| Product | Architecture and useful feature | Main risk/cost | NeClip decision |
|---|---|---|---|
| [Punto Switcher open converter](https://github.com/rshagiev/punto-switcher) | Automatic wrong-layout correction heritage | Continuous input monitoring and false positives | Keep a conservative optional subset |
| [Caramba Switcher](https://caramba-switcher.com/) | Automatic correction with a small tray/menu surface | Opaque detection and broad keyboard access | Copy the obvious off path, not opacity |
| [EveryLang](https://everylang.net/help) | 20+ languages, learned rules, confirmation, indicator/sound | Large toolbox and Windows-only breadth | Defer extra languages; confirmation ideas only |
| [Mahou](https://github.com/iamkarlson/Mahou) | Last word/selection/line conversion, undo, snippets, indicators | Many modes and Windows hooks | Keep one manual command and one undo |
| [RuSwitcher](https://github.com/rashn/RuSwitcher) | System layout maps, `NSSpellChecker`, direct Unicode, protected contexts, per-app memory | Automatic mode still needs keyboard monitoring | Reuse system-derived/local principles |
| [Q*Й keyswitcher](https://github.com/graninilya/keyswitcher) | Contextual short words, undo, proposed rules, terminal quiet mode, local statistics | Very broad rule engine; optional cloud AI | Adopt undo-as-negative-feedback only |
| [RSwitcher](https://github.com/andrewchuev/rswitcher) | Boundary/mid-word detection, n-grams, dictionary guards, adaptive ignore, atomic config | Complex models and invasive hooks | Adopt bounded session ignore, not complexity |
| [dotSwitcher](https://github.com/kurumpa/dotSwitcher) | One-key last-word conversion | Selection/backspace timing can be fragile | NeClip's AX-verified manual path is safer |
| [LangOver](https://langover.com/) | Manual selection conversion and case/text utilities | Extra toolbox and simulated-key workflows | Keep one explicit manual correction |
| [Arum Switcher](https://www.ixbt.com/soft/arum-switcher.shtml) | User-triggered conversion; "does not act on its own" | Old Windows implementation | Treat manual correction as dependable default |
| [Alt SwitchER](https://altswitcher.ru/) | Manual current-word/selection switching | Windows hook behavior | Existing configurable command covers it |
| [langSwitcher](https://github.com/reg2005/langSwitcher) | Double-Shift, five layouts, greedy line detection, menu bar | Greedy conversion can surprise | Defer lines/more layouts until tests prove safety |
| [Lang Switcher](https://lang-switcher.com/) | Minimal dedicated macOS distribution | Sparse public behavior documentation | No feature adopted without evidence |
| [Input Source Pro](https://github.com/runjuu/InputSourcePro) | Per-app/per-site input source, indicator and app-aware behavior | Per-site detection expands scope | Adopt per-app memory only |
| [TypeSwitch](https://github.com/ygsgdbd/typeSwitch) | Per-app Default/Last/Specific/Ignore rules, local state | Full rule editor adds settings weight | Start with one Last-used toggle and reset |
| [InputSwitcher](https://www.inputswitcher.com/) | Fixed per-app input-source rules | Rule management and Accessibility dependency | Defer fixed rules; prefer last-used memory |
| [Keyboard Pilot](https://apps.apple.com/us/app/keyboard-pilot/id402670023?mt=12) | Application-specific layouts and input modes | Dedicated app configuration surface | Same safe per-app direction |
| [KeyMinder](https://github.com/alextuby/KeyMinder) | Per-app/per-window last layout, all-local native menu | AX focus edge cases in floating windows | Use app activation only; avoid window tracking |
| [Switchr](https://github.com/yeelok/Switchr) | Fast MRU source switch and hold overlay | Solves a different Tahoe switching problem | Defer; system shortcut already exists |

### Three architectures must remain separate

1. **Manual conversion** acts only after a hotkey. It needs Accessibility for
   selected-text replacement but no permanent key reading. This is the reliable
   default.
2. **Automatic word correction** listens to keyboard events, buffers a bounded
   token, classifies at a boundary and replaces only in verified fields. It
   needs Input Monitoring plus Accessibility and must be default-off, easy to
   disable, conservative, reversible and blocked in sensitive/code/remote
   contexts.
3. **Per-application layout memory** observes only the active application and
   selected system input source. It does not inspect text or individual keys.
   It offers high daily value with far less privacy and false-positive risk.

NeClip 1.5.0 adds the third architecture as a separate opt-in switch. It does
not silently enable automatic correction or ask for Input Monitoring.

## Catalogue — 100 possible improvements

Legend: **Есть** already exists; **1.5** selected now; **Позже** credible but
not needed for this version; **Нет** intentionally rejected.

### Capture, storage and lifecycle

1. Local persistent text history — **Есть**.
2. RTF retention — **Есть**.
3. Image history — **Есть**.
4. File-list history — **Есть**.
5. Generation-based pasteboard polling — **Есть**.
6. Deduplication that moves a repeat to the top — **Есть**.
7. Per-kind hard decode limits — **Есть**.
8. Total 250 MB hard quota — **Есть**.
9. User history-count limit — **Есть**.
10. Age retention excluding pins — **Есть**.
11. User maximum size for one text record — **1.5**.
12. Separate maximum image size — **Позже**, only if skip feedback proves need.
13. Manual capture-current command — **Нет**, normal copy is clearer.
14. Session-only history mode — **Позже**, privacy value but duplicates pause.
15. Pause for 15 minutes or indefinitely — **Есть**.
16. Clear recent hour/today/all unpinned — **1.5**.
17. Clear unpinned history on quit — **1.5**.
18. Automatic database VACUUM after every delete — **Нет**, adds stalls.
19. Periodic bounded WAL checkpoint — **Позже**, only with measured growth.
20. Backup/restore entire history database — **Нет**, raises secret-handling risk.

### Search, browse and preview

21. Immediate local search — **Есть**.
22. FTS5 exact/prefix search — **Есть**.
23. Bounded fuzzy fallback — **Есть**.
24. Type filters — **Есть**.
25. Smart link/email/color/code categories — **Есть**.
26. Source-application filter — **Есть**.
27. Date-window filter — **Есть**.
28. Pin-state filter — **Есть**.
29. Native discoverable search-filter menu — **Есть**.
30. Search OCR text — **Есть**.
31. Search snippets together with history — **Есть**.
32. Human source-application name — **Есть**.
33. Source-app icon in every row — **Нет**, visual noise in a native menu.
34. Relative age in every row — **Нет**, consumes scarce row width.
35. Focused full-item inspector — **Есть**.
36. Quick Look with Space — **Позже**, useful but not required with inspector.
37. QR extraction from images — **Позже**, local and bounded but secondary.
38. Color swatch preview — **Позже**, only in inspector.
39. Notes/tags on history — **Нет**, turns transient history into a database UI.
40. Permanent visual timeline — **Нет**, violates compact menu-first boundary.

### Paste and item actions

41. Direct paste into previous app — **Есть**.
42. Safe copy-only fallback — **Есть**.
43. Default plain-text preference — **Есть**.
44. One-shot plain-text modifier — **Есть**.
45. Copy-only modifier — **Есть**.
46. Paste and delete after successful direct-paste dispatch — **1.5**.
47. Open explicit HTTP(S) links/files — **Есть**.
48. Rename/edit history item — **Есть**.
49. Pin/unpin, delete and exact undo — **Есть**.
50. Save history as a snippet — **Есть**.
51. Paste OCR instead of image — **Есть**.
52. Sequential paste from a stable recent snapshot — **Есть**.
53. Reverse sequential order — **Позже**, if requested after real use.
54. Multi-select join and paste — **Нет**, requires a selection workspace.
55. Append next copy to previous item — **Позже**, compact but needs a clear mode.
56. Paste–Tab form filling — **Позже**, can build on sequential paste.
57. Temporary-file paste — **Нет**, surprising filesystem side effects.
58. Per-app paste shortcuts — **Нет**, configuration cost is too high.
59. Deterministic local text transforms — **Есть**.
60. User scripts/macros/plugins — **Нет**, security and support surface.

### Snippets and organization

61. Snippet folders, including empty and unfiled — **Есть**.
62. Discoverable two-column editor — **Есть**.
63. Draft-safe autosave and termination flush — **Есть**.
64. Folder create/rename/delete and snippet move — **Есть**.
65. Keywords — **Есть**.
66. Date/time/clipboard placeholders — **Есть**.
67. Versioned merge-only JSON transfer — **Есть**.
68. Manual drag sorting — **Позже**, only if libraries become large.
69. One global hotkey per snippet — **Нет**, shortcut conflicts and clutter.
70. Background typed abbreviation expansion — **Нет**, another global key reader.

### Privacy and trust

71. Concealed/transient pasteboard filtering — **Есть**.
72. Password-manager exclusions by default — **Есть**.
73. User app exclusions — **Есть**.
74. Literal sensitive-phrase rules — **Есть**.
75. Ignore next copy — **Есть**.
76. No accounts/cloud/telemetry/AI — **Есть** as a product invariant.
77. Screen-sharing auto-hide — **Нет**, no reliable universal detector.
78. Website/domain exclusions — **Нет**, would require browser inspection.
79. Allow-list-only capture mode — **Позже**, valuable for high-security users.
80. Automatic correction undo adds session ignore — **1.5**.

### Keyboard layouts

81. Manual selected-text/last-token conversion — **Есть**.
82. System-derived EN/RU mapping including Shift — **Есть**.
83. Configurable manual shortcut — **Есть**.
84. Five-second undo — **Есть**.
85. Default-off automatic correction — **Есть**.
86. High-confidence dictionary gate and protected contexts — **Есть**.
87. Dedicated off-only safety shortcut — **Есть**.
88. Remember last input source per application — **1.5**.
89. No Input Monitoring for per-app memory — **1.5** invariant.
90. Visible reset/count for remembered applications — **1.5**.
91. Fixed input source per application — **Позже**, after last-used proves useful.
92. Per-window layout memory — **Нет**, AX/floating-window edge cases.
93. Per-website layout memory — **Нет**, requires browser/tab observation.
94. Persistent learned auto-correction dictionary — **Позже**, requires editor/export.
95. Multi-language automatic correction — **Позже**, only with locale tests.
96. Mid-word aggressive correction — **Нет**, too surprising.

### Interface and engineering

97. Menu-bar only, no Dock icon — **Есть**.
98. Same system appearance for status click/hotkey — **Есть**.
99. Grapheme-safe configurable row length — **Есть**.
100. Bounded menu snapshots, strict Swift 6, sanitizers and secret gates — **Есть**.

## Scored top 20

Scores are usefulness / simplicity / privacy-confidence, each out of 5.

| Priority | Candidate | Score | Version decision |
|---:|---|---:|---|
| 1 | Per-app last-used layout memory | 15 | 1.5 |
| 2 | Session ignore after automatic undo | 15 | 1.5 |
| 3 | Configurable maximum text record | 14 | 1.5 |
| 4 | Partial history cleanup | 14 | 1.5 |
| 5 | Paste-and-delete after direct-paste dispatch | 14 | 1.5 |
| 6 | Clear unpinned history on quit | 13 | 1.5 |
| 7 | Reset/count remembered app layouts | 13 | 1.5 |
| 8 | Allow-list capture mode | 12 | Later |
| 9 | Quick Look by Space | 12 | Later |
| 10 | QR extraction | 12 | Later |
| 11 | Fixed layout per app | 12 | Later |
| 12 | Append-copy mode | 11 | Later |
| 13 | Reverse sequential order | 11 | Later |
| 14 | Form-fill mode | 11 | Later |
| 15 | Color preview | 11 | Later |
| 16 | Separate image-size preference | 10 | Later |
| 17 | Manual snippet ordering | 10 | Later |
| 18 | Persistent correction dictionary | 10 | Later |
| 19 | Extra language pair | 9 | Later with tests |
| 20 | Session-only history | 9 | Later |

## 1.5.0 implementation contract

The source version changes to 1.5.0/build 9. Public `docs/version.json`, GitHub
Release assets and `/Applications/NeClip.app` remain at signed/notarized 1.4.0.
The selected source slice is intentionally small:

1. A 64–2048 KB maximum for captured text, applied before persistence.
2. Clear recent hour, today or all unpinned history; pins/snippets survive.
3. Optional fail-closed clearing of unpinned history when the app quits.
4. Paste-and-delete only after macOS accepts the direct-paste event dispatch
   and the record is not pinned; copy-only fallback never deletes it.
5. Per-app last-used input-source memory, default off, local and bounded to 200
   app mappings, using app activation and TIS notifications only.
6. Undoing an automatic correction adds its original token to a bounded
   memory-only ignore list until NeClip restarts.

This gives NeClip more control and fewer surprises without adding a second
workspace, another account model or broader background observation.
