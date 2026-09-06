# NeClip native settings and local cleanup

## Goal and professional prompts

Release engineer: identify generated/test copies by version, identity and use;
clean exact verified targets while retaining production data, source Git
ownership and one tested rollback. Prefer recoverable removal for archives.

Apple UX designer: group persistent settings by task, use native macOS controls
and concise Russian labels, preserve discoverability and keyboard navigation.
Avoid feature proliferation and copying the whole System Settings application.

Swift QA/security engineer: verify button/lifecycle behavior, data preservation,
hotkeys, error states, release provenance and secret-scanning coverage.

## Read-only plan gate

Three independent audits completed before implementation: local artifact
inventory, Apple UI review, and code/QA/security review. Root read project map,
current owners and Apple HIG Settings. Baseline is public1.9.0/build15.
Important finding: historical ~/neclip owns the Git worktree, not disposable.

## Ordered work

1. P0: protect unsaved history-inspector changes on close/replace/quit;
   invalidate stale asynchronous loads and erased-data previews.
2. P0: native Edit menu responder actions; preserve text editing shortcuts.
3. P1: native noncustomizable settings toolbar with active section; reorganize
   History vs Menu/Paste; remove duplicated one-shot actions from Settings only.
4. P1: numeric drafts commit on tab/close, not every keystroke; consistent app
   exclusion feedback and retention-trim errors.
5. P1: compact first-run UI with core shortcuts and reachable permission/close
   choices at supported sizes; preserve explicit optional permission grants.
6. Verify local UI and full strict tests/sanitizers. Checkpoint before publish.
7. Exact cleanup manifest; protect installed app, Git, DB/preferences and one
   rollback. No unrelated app removal, broad home deletion or credential reads.
8. Version1.9.1/build16: immutable signed/notarized artifact, protected GitHub
   publication, public-download hash/Gatekeeper verification, website/feed sync.
9. Transactional installation and data verification, final cleanup of own QA
   copies, independent re-audit and public/live completion evidence.

## Acceptance

Programmatic: focused regression tests, full Swift6/concurrency/warnings gate,
ASan/TSan, JSON/source contracts, Gitleaks tree/history/refs and release signing.
Judge: each settings section reachable, labels/controls fit minimum dimensions,
native appearance, close/cancel/save and core snippet flows behave coherently.
Operational: source Git intact, only current app launchable in Applications,
retained rollback validated, private snippet/folder content unchanged.
No percentage-deletion or feature-count target. No bypassed release gates.
Stop only at verified delivery or a genuine authority/external blocker; keep
remaining requirements explicit rather than claiming local edits are release.
