# NeClip UX and interaction review — 2026-09-25

## Scope and evidence labels

The repository review used commit `7b229718414694520a9ba8ab96d728e2a41ca148` as the released baseline. NeClip behaviors below are **source/test verified** where named. Competitor flows are **manufacturer-documented**; the apps were not installed or exercised on this Mac. Recommendations are **inferences** from those flows and Apple's current Human Interface Guidelines, not user-study findings.

## Platform guidance applied

- Keep keyboard focus stable unless the user moves it; show focus using familiar system selection/focus treatments. [Apple HIG: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/)
- Preserve standard keyboard shortcuts and support Full Keyboard Access. [Apple HIG: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- Use the menu bar for commands and support keyboard and pointing-device flows. On large Mac displays, prefer fewer menu levels when the information remains readable. [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- Check accessibility with Accessibility Inspector and expose information through more than color alone. [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## Concrete task comparison

| Product | Documented common task path | Input and state cues documented | Product scope / evidence |
|---|---|---|---|
| NeClip | Open history; move to the specific row; Return pastes, Shift-Return pastes plain text, Command-Return copies. Older history has a flat submenu with search. | Native selected-row routing, concrete snippet IDs, and paste/copy distinctions are source/test verified; physical mixed-input behavior is still a UI check. | Compact menu-bar history, snippets, layout repair, screenshots; local-only by product design. |
| Maccy | Open with the configured shortcut or menu-bar item, type to filter, Return to paste. | Its guide documents keyboard shortcuts, menu-bar access, and a full-text hover tooltip for truncated rows. | Clipboard-focused, smaller flow than a launcher. [User guide](https://maccymanager.com/documentation) |
| Paste | Open Paste, type to search; Command-F focuses search; arrows move through results and Tab switches between search and results. Rename or keep an item on a Pinboard. | Search-field/list focus and keyboard operation are explicitly documented; item titles and Pinboard colors help distinguish saved items. | Multi-device history and Pinboards add organization and sync concepts. [Mac guide](https://pasteapp.io/help/paste-on-mac), [shortcuts](https://pasteapp.io/help/keyboard-shortcuts) |
| Raycast Clipboard History | Open from Root Search or a configured hotkey, type a query, Return pastes; Command-Return copies; Shift-Return can paste plain text. | The highlighted entry is the current action target; Command-K opens secondary actions. | Clipboard is one command among many; some functionality is Pro. [Clipboard History manual](https://manual.raycast.com/clipboard-history) |
| Alfred | Open the Clipboard Viewer, type to filter, Return pastes by default; Command-S saves the selected item as a snippet. | Configurable hotkey; selected clip is the source for save and paste. Docs describe ignore-apps and concealed-content privacy behavior. | Clipboard history/snippets are Powerpack features; workflow breadth increases setup choices. [Clipboard help](https://www.alfredapp.com/help/features/clipboard/), [snippets](https://www.alfredapp.com/help/features/snippets/) |
| Shottr | Use a capture hotkey or its menu-bar icon, choose Capture Area and drag a region. | Capture commands and Settings are exposed from the icon menu. | Screenshot workflow, not a unified clipboard-history tool. [Start guide](https://shottr.cc/kb/startguide) |
| CleanShot X | Capture, use the corner pop-up, then continue through Quick Access Overlay. | A post-capture pop-up and overlay provide next-step feedback and actions. | Broad screenshot/recording/share surface includes optional cloud workflows. [Features](https://cleanshot.com/features) |
| Punto Switcher | Select text or type the last word, invoke its correction hotkey; invoke again within the undo window to reverse. | Docs name selection/last-word priority and explicit undo/toggle shortcuts. | Layout repair, requiring Accessibility; vendor-described behavior. [Project guide](https://github.com/rshagiev/punto-switcher) |
| UASwitcher | Type a word or select it, tap configured Option (or another trigger); tap again to reverse. | Trigger can be configured; auto-correction is separately described as beta. | Layout repair, no clipboard-history workflow. [Project guide](https://github.com/deimoc/UASwitcher) |

## Findings and decisions

1. **Protect action identity across input methods.** NeClip's Return handler now follows the selected menu item, while mouse activation and Command-Return have distinct routes. The current source has regression tests for IDs and copy/paste mode; AppKit menu behavior still needs physical interaction coverage.
2. **Keep search local to the older-history interface.** NeClip places Command-F there, avoiding a shortcut that unexpectedly steals focus in unrelated NeClip windows. The dedicated search panel supports keyboard selection and explicit paste/copy variants.
3. **Make overflow explicit.** The first history list is configurable; older history stays in a flat “Ещё из истории” menu. More than 200 snippets are disclosed as available in the editor. The menu cap is a deliberate performance boundary, but discoverability for very large libraries merits a VoiceOver and first-use check.
4. **Keep screenshot work compact and finish requested operations.** A capture/edit/export surface is narrower than CleanShot's suite. Once Copy or Save begins, hiding the app must not silently cancel it; that confirmed defect is fixed in this candidate.
5. **Keep layout correction conservative.** Dedicated tools describe undo and selection-first correction as clear recovery patterns. Automatic correction stays optional and cautious; this review does not recommend a more aggressive classifier or additional permission scope.

No feature was added to imitate a competitor. No account, cloud, telemetry, AI, macro language, or third-party runtime dependency is introduced.

## Inspection boundary

This is a source and manufacturer-document comparison, not a hands-on competitive usability study. NeClip's physical menu traversal, secondary-click parity, VoiceOver announcement of selected snippet rows, and behavior in third-party editors require runtime checks before making universal compatibility claims.
