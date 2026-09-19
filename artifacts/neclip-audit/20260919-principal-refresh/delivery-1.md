# Audit synthesis: confirmed delivery slice

## Shipped candidates

- Search coalesces text changes for 120 ms and rejects stale queued work before
  it enters SQLite. The panel now honours Return, Shift-Return,
  Command-Return, arrows and Escape, and reuses table cells.
- Clip action menus defer folder-target materialization until that one submenu
  opens. This preserves the flat history model while avoiding per-row folder
  menus during ordinary history presentation.
- Automatic AX access configures the focused object's timeout before reading
  its role/selection. A failed manual fallback restores a caret only if NeClip
  still owns both the temporary selection and unchanged token.
- Restore preflights a chosen backup as a non-symlink regular file no larger
  than 500 MiB before SQLite opens it.

## Evidence

- Synthetic search p95: 2.6 ms / 100, 9.5 ms / 500, 33.1 ms / 2,000 rows on
  this host. The debounce avoids scheduling this work for every keystroke.
- Menu read p95: 6.1 ms at the existing 200 clip/200 snippet fixture. Lazy
  action menus remove folder-target construction from the eager path.
- Targeted checks cover search command mapping/request invalidation, backup
  symlink/oversize rejection, menu policy, selection restoration, layout and
  Option correction paths.

## Deferred deliberately

- Full-text index/FTS: would persist another searchable representation of
  clipboard text and changes the product privacy boundary.
- Large virtual history window, snippet editor background projection and
  screenshot memory changes: need Instruments/real workload evidence, not
  speculative rewrites.
- Signed update manifest and user-selected downloaded-DMG verification: useful
  future hardening, but a public-key/update-UX design decision rather than a
  safe patch to the current manual browser-download flow.
- Physical global-key testing: synthetic UI events do not reach the session
  event tap, so no universal keyboard/editor claim is made.

## Independent findings resolved or rejected

The release reviewer reported a prior installed-app signature failure. A fresh
independent check on 2026-09-19 passed strict codesign, stapler and Gatekeeper
for `/Applications/NeClip.app` 2.8.1/47 and the public DMG. No reinstall was
performed because the claimed fault was not reproducible.
