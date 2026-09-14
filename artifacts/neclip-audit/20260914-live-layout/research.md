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

- Installed 2.8.0 had automatic and standalone Option correction enabled. CUA H E L L O actions in Russian input produced unchanged `руддщ` in a new TextEdit document without Space. Later diagnostics established that these targeted synthetic events bypass NeClip's session event tap: this observation is NOT a physical-keyboard end-to-end reproduction. The AXTextArea exclusion below is independently confirmed from production code.
- The automatic AX writer excluded AXTextArea and values over 512 characters. Callback generation alone did not prove editor correction.
- No retry existed if AX text lagged the last key.
- Manual canonical maps combined Shift and Caps Lock variants, removing punctuation-position mappings such as `[` → `х`.
- Manual undo stored inferred text source instead of the input source active before correction, and rejected an accepted selected-replacement state.
- Overlapping Option observations could rearm a cancelled chord.
- Input-source selection pumped a run loop while automatic correction held a non-recursive lock; the source observer could acquire that same lock.

## Implemented acceptance checks

Live range replacement preserves surrounding multiline/rich text and UTF-16 caret positions. Only an untouched not-ready attempt may retry (12 ms initial coalescing plus at most 20/40/80 ms); later key/focus/source state cancels it. Failed or ambiguous writes are terminal. Backspace emits an updated candidate. Manual operations suspend automatic context until completion. Tests exercise production event handling, the real system dictionaries/maps, native NSTextView formatting, stale edits and bounded retries.

Independent second review additionally found and closed: a temporary selection left behind after an intervening formatter edit; automatic undo falling through to a second conversion after an uncertain write; overlapping manual commands releasing suspension too early; and loss of first strokes during focus recovery. Pending first strokes are retained for at most 250 ms, adopted only against matching AX text/sequence, and cleared on invalidation or secure input. Context refresh is scheduled once after 12 ms rather than postponed by every key. A nil context is periodically reacquired. Recovered complete words can be evaluated without a separator.

Remaining product limits: recognition needs installed system dictionaries, secure/protected/excluded fields stay untouched, ambiguous words and punctuation cannot always establish intent. Physical editor coverage is recorded separately, not inferred from unit tests.

## Host diagnostic boundary

Final queue review found that a recovered candidate could be delivered after a newer event-thread candidate. The scheduler now rejects a stale sequence before cancelling scheduled work. A deterministic asynchronous test delivers the newer candidate first and verifies that it still executes after an older recovery callback arrives.

The signed local diagnostic candidate reported AX=true, listen=true, post=true and a running event tap. Actual incoming keyboard activity produced candidate diagnostics; CUA's targeted TextEdit key actions produced no event-tap callbacks. The CUA API also rejected modifier-only Alt with `keyPressIncludedNoNonModifierKeys`. Neither targeted text injection nor a modifier API rejection is evidence of the app's physical key behavior. A user-assisted physical-key check was requested separately.
