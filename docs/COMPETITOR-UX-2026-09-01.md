# Clipboard and layout UX review — 1 September 2026

Twenty current products and primary project pages were checked again. The goal
was not feature parity: it was to find small, local, keyboard-first improvements
that fit NeClip's menu-bar-only boundary.

| Product | Useful pattern | NeClip decision |
|---|---|---|
| [Apple Clipboard History](https://support.apple.com/en-mide/guide/mac-help/mchl40d5b86b/26/mac/26) | Searchable system history in Spotlight | Keep NeClip differentiated by direct paste, longer local history, snippets and layout correction |
| [Windows Clipboard](https://support.microsoft.com/en-au/windows/using-the-clipboard-30375039-ce71-9fe4-5b30-21b7aab6b13f) | Simple shortcut, pins and explicit clear | Already covered; retain visible clear and pins |
| [Maccy](https://github.com/p0deje/Maccy) | Tiny native keyboard-first popup | Preserve native menu and immediate typing |
| [Raycast Clipboard History](https://manual.raycast.com/clipboard-history) | Discoverable content-type filters | Added a native magnifier filter menu without a toolbar |
| [Alfred Clipboard and Snippets](https://www.alfredapp.com/help/features/clipboard/) | Fast search, previous-app paste, [collections and keywords](https://www.alfredapp.com/help/features/snippets/) | Keep explicit folders/keywords; reject background text expansion for privacy and permission simplicity |
| [Paste](https://pasteapp.io/help/paste-on-mac) | Rich preview and visual grouping | Keep focused inspector; reject a permanent card workspace |
| [CleanClip](https://www.cleanclip.cc/docs/manual) | Keyboard help and sequential paste | Existing direct sequential paste is simpler; filters now discoverable in the native search control |
| [PastePal](https://apps.apple.com/us/app/clipboard-manager-pastepal/id1503446680?platform=mac) | Type collections and exclusions | Existing type-aware search and app exclusions cover the useful subset |
| [PasteBar](https://github.com/PasteBar/PasteBarApp) | Boards, transforms and collections | Keep deterministic transforms; reject boards and large workspace UI |
| [CopyQ](https://github.com/hluk/copyq) | Rules, scripting and deep customization | Reject scripting/plugin complexity; keep safe built-in actions |
| [PowerToys Advanced Paste](https://learn.microsoft.com/en-us/windows/powertoys/advanced-paste) | Plain-text conversion and advanced transforms | Keep local plain-text/transforms; reject network AI processing |
| [Ditto](https://ditto-cp.sourceforge.io/) | Mature search and hotkey navigation | Already covered by native shortcuts and bounded search |
| [ClipboardFusion](https://www.clipboardfusion.com/Features/) | Text scrubbing and per-app behavior | Keep local transforms/exclusions; reject sync and macro surface |
| [Clipy](https://github.com/Clipy/Clipy) | Classic ClipMenu-like sections and snippets | This remains NeClip's primary interaction model |
| [Jumpcut](https://github.com/snark/jumpcut) | Minimal menu-bar history | Preserve compactness and no Dock icon |
| [Flycut](https://github.com/TermiT/flycut) | Developer-oriented lightweight history | Type/code search covers the useful path without a separate mode |
| [Pastebot](https://tapbots.com/pastebot/) | Queues and filters | Direct sequential paste and built-in transforms cover the small useful subset |
| [ClipClip](https://www.clipclip.com/features) | Saved clips and folders | Snippet folders provide the local native equivalent |
| [Caramba Switcher](https://caramba-switcher.com/mac) | Automatic correction with a simple off path | Keep automatic mode optional, conservative and instantly disabled by a dedicated shortcut |
| [EveryLang](https://everylang.net/help) | Broad layout, transform and translation toolbox | Keep only offline correction and transforms; reject translation/network breadth |

Layout architecture was also cross-checked against open implementations and
documentation from [Mahou](https://github.com/iamkarlson/Mahou) and
[langSwitcher](https://github.com/reg2005/langSwitcher). Their breadth does not
justify weakening NeClip's protected-context and confidence gates.

## Selected changes

1. Expose structured history filters through the standard search magnifier.
2. Bound the menu's snippet snapshot to 200 records and load only their folders;
   full search and editing remain complete.
3. Show a human application name in the item inspector instead of a bundle ID.
4. Delete all clips, snippets and folders atomically.
5. Document module ownership and fail-closed invariants in `PROJECT-MAP.md`.

## Deliberately not added

- Accounts, cloud or cross-device transport.
- AI transforms or semantic processing of private clipboard data.
- A permanent Dock icon, card board or large main window.
- Background snippet expansion, scripting or plugin execution.
- Unlimited native menu rows.
- PIN vaults or a second secrets database.
- Aggressive multi-language autocorrection or learned-word telemetry.
- A caret-position popup that would add fragile Accessibility geometry.

The rejection list is part of the product contract: simplicity and predictable
privacy are features, not missing implementation.
