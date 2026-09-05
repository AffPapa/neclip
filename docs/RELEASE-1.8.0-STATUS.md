# NeClip 1.8.0 / build 14: publication status

Date: 2026-09-05. This page distinguishes verified source from downloadable apps.

The source candidate includes the settings/editor follow-up, capture cleanup
barrier, clearer keyboard commands, bounded search and snippet rendering.
The final pre-release refinement avoids a full grapheme count for oversized
privacy rules while editing. See `UX-SETTINGS-2026-09-05.md` for coverage and
known limits. No broad late-stage feature work was added to the release.

GitHub authentication and the NeClip Developer ID signing identity are
available. The required `notarytool` Keychain profile `neclip` is missing.
No credentials belonging to another application are used as a fallback.

A fresh, separate release build directory was used for a complete rebuild:
196 XCTest cases (one opt-in skip, zero failures) and 11 Swift Testing cases
passed with complete concurrency and warnings-as-errors: 206 passed, one skip.
The publishable tree and fetched Git history passed the secret scanner.

Until the reviewed source commit passes `build-app.sh` notarization, stapling,
Gatekeeper and exact-DMG verification, the signed public download and updater
manifest remain at **1.4.0**. Do not install or label a source candidate as a
notarized public release. Do not delete the working installation or its rollback
release before the replacement passes these gates.

To unblock distribution, configure the `neclip` profile locally using Apple's
`xcrun notarytool store-credentials neclip` interactive flow. Credentials must
stay in Keychain, never in Git, documentation, command transcripts or chat.
Then run the existing release pipeline against the exact reviewed commit,
verify the resulting app and DMG, publish, verify the downloaded artifact and
only then replace the local installed app and retire duplicate test copies.
