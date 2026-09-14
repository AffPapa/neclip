# Layout switchers: source review, 14 September 2026

This is a documentation/source comparison, not a runtime benchmark of competitors.

| Product | Verified approach | Consequence for NeClip |
| --- | --- | --- |
| [Punto for Mac](https://yandex.ru/soft/punto/mac/) | Automatic wrong-layout correction, examples ghbdtn → привет, configurable shortcuts. Exact triggering key and proprietary recognition internals are not documented on the accessible page. | Do not claim we replicated a proprietary per-key algorithm. Verify our own timing in an editor. |
| [Caramba for Mac](https://apps.apple.com/us/app/caramba-switcher-autocorrect/id1565826179) | RU/EN automation, double Shift manual correction, Backspace/retyping exceptions and coding/game exclusions. Exact per-key timing is unverified. | Keep manual override and exclusions; dictionary confidence is not a universal correctness guarantee. |
| [UASwitcher](https://github.com/deimoc/UASwitcher) | README explicitly checks when a word ends with Space; system dictionaries, ambiguity exclusions, always/never-convert lists. | Per-key NeClip needs additional editor-readiness and continuation tests beyond word-boundary tests. |
| [LangPilot](https://github.com/SC1882/LangPilot) | Documents learning from manual corrections/undo and excluded applications. Exact timing/threshold unverified here. | Authoritative undo is more useful than repeatedly applying the same disputed correction. |
| [PolterType](https://github.com/Just-Code-NET/PolterType) | Documents end-of-word correction and optional buffering/replaying keys during replacement; macOS delay tradeoff. | Treat key delivery and text replacement as separate problems. Do not silently discard queued keys. |

[Caramba Secure Input documentation](https://caramba-switcher.com/help/secure-input/) confirms that macOS Secure Input restricts monitoring. NeClip must respect it.

## Reproduced NeClip defects

- Installed 2.8.0 had automatic and standalone Option correction enabled. Physical H E L L O in Russian input produced unchanged `руддщ` in a new TextEdit document without Space.
- The automatic AX writer excluded AXTextArea and values over 512 characters. Callback generation alone did not prove editor correction.
- No retry existed if AX text lagged the last key.
- Manual canonical maps combined Shift and Caps Lock variants, removing punctuation-position mappings such as `[` → `х`.
- Manual undo stored inferred text source instead of the input source active before correction, and rejected an accepted selected-replacement state.
- Overlapping Option observations could rearm a cancelled chord.
- Input-source selection pumped a run loop while automatic correction held a non-recursive lock; the source observer could acquire that same lock.

## Implemented acceptance checks

Live range replacement preserves surrounding multiline/rich text and UTF-16 caret positions. Only an untouched not-ready attempt may retry (12 ms initial coalescing plus at most 20/40/80 ms); later key/focus/source state cancels it. Failed or ambiguous writes are terminal. Backspace emits an updated candidate. Manual operations suspend automatic context until completion. Tests exercise production event handling, the real system dictionaries/maps, native NSTextView formatting, stale edits and bounded retries.

Remaining product limits: recognition needs installed system dictionaries, secure/protected/excluded fields stay untouched, ambiguous words and punctuation cannot always establish intent. Physical editor coverage is recorded separately, not inferred from unit tests.
