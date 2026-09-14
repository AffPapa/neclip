# NeClip 2.8.1 / build 47

## Exact artifact

- Implementation source: `7efb0c25679a4c8f0e4cdd6d86ad560f06d5a63f`.
- DMG: `NeClip-2.8.1.dmg`, 2,104,770 bytes.
- SHA-256: `6dee89524f5349d1b92744f50862162f870ea86fc74060d9944907243246901b`.
- Code review: [PR #55](https://github.com/AffPapa/neclip/pull/55).
- Published: [v2.8.1](https://github.com/AffPapa/neclip/releases/tag/v2.8.1), 2026-09-14T14:05:41Z.
- PR #55 merged as `744c4d05161e8c982e800bf2aeb8a40af4e3d307`; all required CI, including Swift CodeQL, passed.
- Independently downloaded public DMG matches the exact SHA-256 and size above.
- Local installation: `/Applications/NeClip.app` is 2.8.1 / build 47, copied from the independently downloaded public DMG; strict signature, notarization ticket and Gatekeeper verification passed again after installation. A single running process was verified at the installed path.
- Rollback bundle: `/Applications/NeClip.app.backup-2.8.0-46-20260914` (verified version 2.8.0). Earlier rollback bundles and user data were retained.

## Verified locally

312 XCTest executed, 5 expected opt-in/environment skips, 0 failures; 3 Swift Testing tests passed. Strict Swift 6 release build passed. App and DMG are Developer ID signed, notarized, stapled and accepted by Gatekeeper; the mounted DMG app was independently verified. App notarization: `35cfdc83-be8a-43d0-a035-8c6a2713acec`; DMG notarization: `072d348f-e7be-4b6d-a6f7-bb014018bf72`.

Regression coverage includes production event-handler live candidates before a delimiter and after Backspace; pending first strokes and stale-context rejection; actual EN/RU system maps and dictionaries for `руддщ`, `ghbdtn`, `[jxe`; bounded editor-readiness retries; native NSTextView rich-text preservation; UTF-16 caret positions in long multiline documents; restoration of temporary selections; balanced manual suspension; overlapping Option gestures; and a real asynchronous scheduler test proving that a late recovered candidate cannot cancel a newer attempt.

The signed candidate's settings UI reports 2.8.1 / build 47, with automatic and Option correction enabled and the existing macOS permissions granted. A diagnostic signed copy reported a running session event tap. Diagnostic messages contain only states/counts, never typed text. Publishable-tree, Git-history, side-ref and app-bundle secret scans found no leaks.

## Actual UI coverage boundary

CUA operates TextEdit, but its targeted synthetic keystrokes did not reach NeClip's session event tap. Its API rejected modifier-only Alt. Those actions do not establish physical-keyboard automatic or standalone-Alt success. A physical-keyboard check was requested from the user; a pending response is not a pass. No universal editor compatibility or perfect recognition claim is made.

Automatic correction uses local dictionaries, starts evaluation at four characters, and attempts replacement before a separator. Multiline/rich editors require writable selected-text Accessibility support. Unsupported controls, secure input, protected/excluded apps, ambiguous tokens and stale targets remain guarded. Input-source selection no longer pumps a nested run loop under the typing lock; uncertain writes consume the operation rather than trigger a second conversion.

The [research and audit notes](https://github.com/AffPapa/neclip/blob/main/artifacts/neclip-audit/20260914-live-layout/research.md) distinguish verified competitor behavior, source-confirmed defects and host coverage limits. The user's clipboard contents/history database were not read or exported for these checks.
