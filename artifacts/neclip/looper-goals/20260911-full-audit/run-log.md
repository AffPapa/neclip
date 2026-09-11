# Run log

## 2026-09-11 baseline

- Clean worktree at `270096bd86055628339bb38fc12ae7f443f6d885`.
- Branch is two commits ahead of its remote tracking branch.
- Source and installed app both report 2.5.6/build 35.
- Production data directory is about 118 MB and was inventoried by path/size only; contents were not copied into the repository.
- Existing release evidence records signed/notarized 2.5.6 from older source commit `71c6716a...`; current HEAD therefore requires fresh provenance and release checks before publication.

## Delivery 1

- Synced current branch with `origin/main` using a normal merge; no history rewrite.
- Passed debug, strict release, AddressSanitizer and ThreadSanitizer suites.
- Passed opt-in hot-path measurements and migration on a disposable copy of the production SQLite database; the copy was removed immediately.
- Inspected Aqua/Dark Aqua synthetic editor renders.
- Found and fixed fallback display-ID inconsistency; added four regression cases.
- Public GitHub Release and Pages still report 2.5.5; 2.5.6 remains a candidate.
