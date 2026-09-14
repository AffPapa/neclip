# Live typing correction audit

Outcome: automatic EN/RU correction before a separator in supported native text fields and multiline editors, with bounded retry when AX trails keyboard delivery. Manual Option and source/undo behavior must remain coherent.

Roles: parent — macOS input engineer, integration and release; research agent — official competitor mechanisms; audit agent — manual correction and mapping regression review (read only).

P0: reproduce actual editor restrictions and event-delivery races; support bounded range replacement in multiline controls; coalesce live candidates and retry only while sequence, focus and source match; exercise deletion, continued typing, source changes, selection and undo. Preserve rich text outside the changed range, secure-input exclusions, and clipboard contents.

P1: describe supported behavior honestly and document researched tradeoffs. No network model, telemetry, persisted typed text, or expanded macro features.

Acceptance: behavioral tests cover editor readiness, stale cancellation and multiline range edits; real AppKit fixture or physical editor test verifies production replacement where system permissions permit; full release checks/signing/notarization; public artifact checksum and live site verification; rollback-safe installation. Distinguish any unverified host/editor coverage. No blanket reliability claims.

Delivery: one bounded correction-engine slice, research report and test evidence, then release/install under existing user authorization. Revisit failed checks only on concrete new evidence; do not bypass CI or macOS permissions.
