# NeClip 2.8.8 continuation audit

## Scope and provenance

User requested completion of remaining verified defects, another Direct release and fresh verification. Baseline: clean main `303756966463339d9ccf9e0cce48ee2eb04b4c66`, public immutable 2.8.7/build 53 from `2cad4383bcc6d1a7c8c28c6e60bbfe67a3b11be6`, no open PRs, Pages built at main. Active checkout `.work-neclip-283`; installed app, user database and prior releases retained.

## Evidence -> cause -> change

- Token insertion appended regardless of caret/selection. Dedicated native plain-text editor inserts through NSTextInputClient, scopes undo per snippet and guards late callbacks by document ID. Physical UI caught disabled menu Undo despite passing direct-manager tests; explicit responder actions fixed it. Emoji selection, multiline paste, insertion after title focus, Cmd+Z/Shift+Cmd+Z, autosave and relaunch persistence verified in an isolated preview database.
- Screenshot history used original dimensions although background export adds padding. Ingestion now reads final encoded dimensions; regression covers 400x300 -> 448x348, unpadded original and malformed data.
- Screenshot copy cleared the clipboard before a potentially failing write. Bounded snapshot and generation-guarded rollback now retain old representations and never replace an intervening external copy. Failure injection verifies the error path; native write failure itself was not observed. Refuse before mutation when full snapshot exceeds existing 16 MiB/32-item bounds; file export remains available. Rollback still depends on the native service accepting restoration.
- Snippet preparation eagerly read clipboard text on main even without an active token. Fetch first, read only on the data queue when the renderer needs it, reject generation changes before/after the read. Deterministic direct rendering read counts: literal/date/escaped templates 1 -> 0; active token 1 main -> 1 worker. The separate PasteService rollback snapshot still runs on main; no total paste latency claim.
- Explicit AX labels distinguish type/application/date filters and preview clipboard input. VoiceOver speech is not certified.

## Acceptance gates

Strict debug/release Swift tests, changed regression tests, ASan/TSan, site and SEO tests, source/history/artifact secret scans, protected GitHub CI/CodeQL, exact merged-source Developer ID/notary/stapling/Gatekeeper, fresh public download hashes and Pages/README parity. Final public evidence will be recorded in docs/RELEASE-2.8.8-STATUS.md after publication.

## Limits

Physical QA used synthetic fixtures and an isolated preview bundle, not the installed app or user history. Real cross-app automatic paste, ScreenCaptureKit permission transitions, VoiceOver audio and every macOS/multi-monitor configuration remain outside this bounded verification. No broad redesign or additional features.
