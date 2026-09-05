# Source delivery checkpoint

NeClip 1.8.0/build 14, local source only. The installed/public app and public
download manifest remain untouched. No commit or push in this pass.

## Product evidence

- 19 clipboard/history products + 11 layout tools + 3 adjacent tools reviewed
  through official documentation; 100 recommendations, 27 selected refinements.
- Implemented folder-first snippets, right-click access, direct editing,
  duplicate/undo, editor keys, reliable search/menu state and settings feedback.
- Security/correctness includes full-erasure ephemeral-state cleanup, normalized
  protected app identities, bounded template expansion, immutable paste target.
- Removed two unused menu-length aliases, avoided full-body preview counts.

## Programmatic checks

Logs are local temporary operational evidence, not release artifacts:

- `/private/tmp/neclip-discovery-tests-final.log`: 167 XCTest, 1 skipped,
  0 failures; 11 Swift Testing passed.
- `/private/tmp/neclip-discovery-release.log`: strict release complete, no warnings.
- `/private/tmp/neclip-discovery-asan.log`: same suite passed, exit 0.
- `/private/tmp/neclip-discovery-tsan.log`: same suite passed, exit 0, no race report.
- `/private/tmp/neclip-discovery-secrets-final.log`: detector canaries + tree +
  32 HEAD commits + 2 side-ref commits clean after remote-ref refresh.
- plist, all docs JSON, diff whitespace and exact matrix count validated.

## Sampled visual / interaction checks

Isolated QA bundle `org.affpapa.neclip.qa.discovery20260905`, separate temporary
database, capture paused, auto correction/layout memory disabled. Editor
duplicate/search/clear verified on synthetic starters by the QA agent; root
inspected live Keys screenshot and menu AX state. No new permissions granted.
This is sampled visual evidence, not every macOS/target-app/hotkey combination.

The QA app/database are left intact; do not delete them blindly if the owner
has entered additional snippets while examining the preview. QA is not an
installed release and its temporary data is separate from the real NeClip DB.

## Remaining release gate

Local code/normal/strict/sanitizer gates passed. Public binary delivery additionally
requires signing/notarization/stapling/Gatekeeper/mounted-DMG and target-app
verification; current local work does not claim those gates passed. No AI,
account, cloud, migration removal, history rewriting or installed-app replacement.
