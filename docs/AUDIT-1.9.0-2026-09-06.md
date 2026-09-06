# NeClip 1.9.0 simplification audit

Date: 6 September 2026. The initial source-candidate audit below was followed by
the verified public 1.9.0/build 15 release; see `RELEASE-1.9.0-STATUS.md`. This report does
not represent an exhaustive proof that every possible defect is absent.

## Method and scope

Three independent read-only tracks covered architecture/dead code, hot paths
and UX before editing. Separate final storage/settings and menu/editor reviews
found no concrete regressions in the changed paths. The primary-source design
matrix is `RESEARCH-1.9.0-SIMPLIFICATION.md`.

No accounts, cloud, telemetry, external AI, new dependencies, privacy bypasses,
migration deletion or function removal. GRDB remains exactly 7.11.1. Tests use
synthetic data; user clipboard content is not a fixture or research input.

## Code size: honest result, not a cosmetic target

Baseline commit: `eaea2d59aeb595cf3ac51d1d04ca372f39373253`.
Count all physical lines in `Sources/NeClip/*.swift`, including comments,
blank lines and the new DEBUG-only minimum-window QA helper.

| Runtime source metric | Baseline | Candidate | Reduction |
| --- | ---: | ---: | ---: |
| Physical Swift lines | 11,669 | 11,570 | 99 (0.85%) |
| UTF-8 bytes | 468,693 | 465,121 | 3,572 (0.76%) |

The requested 30% means removing about 3,501 runtime lines. Independent audits
did not identify that much redundant behavior. We consolidated repeated SQL,
settings writes, shortcut dispatch, pagination and editor refresh. Tests grew
to protect these boundaries. We did not minify, move code into a dependency,
delete compatibility or weaken safety to manufacture a percentage.

## Performance evidence

The same opt-in `HotPathBenchmarks` fixture runs on the baseline and candidate
in release mode with GRDB 7.11.1 and Swift 6.4. Baseline is a separate Git export
with isolated build caches. Fixture SHA-256:
`a6d58fe583fb83652c5b06a981eb09c4c871843072e9b132817dcc05e22dbd2f`.
Payload construction and full-payload verification are outside timings.

| Synthetic operation | Baseline median, ms | Candidate median, ms |
| --- | ---: | ---: |
| OCR metadata, 1 MiB image | 3.419292 | 1.916333 |
| Pin, 1 MiB image | 2.882958 | 1.572000 |
| OCR metadata, 10 MiB image | 19.883458 | 13.301542 |
| Pin, 10 MiB image | 24.327625 | 15.294166 |
| Empty rules, 2,686,976-byte text | 65.092208 | 0.000167 |

These are single local runs, not controlled population estimates or a claim
about whole-app speed. SQLite timings vary with disk/cache/system load. The
fixture uses 12 metadata samples and 20 rule samples; its reported p95 is the
maximum at these sample counts. Earlier exploratory runs varied substantially.
The reliable structural improvement is avoiding payload materialization and
unnecessary normalization, not promising a fixed multiplier.

`ClipboardMetadataMutationTests` installs SQL triggers that reject updates to
text/image/RTF columns during metadata operations. It also verifies physical
UTF-8 accounting, FTS replacement, quota rollback and absent-row behavior.
`TextCapturePreflightTests` verifies exact Unicode byte boundaries and rejection
before expensive normalization. `MenuWorkRegressionTests` verifies cancelled
queued work and exact pagination. Running reads retain generation validation.

## Functional and visual QA

- Strict Swift 6 release tests with complete concurrency and warnings-as-errors:
  212 XCTest cases, one optional external-database skip, zero failures; 11 Swift
  Testing cases passed. Total: 222 passed, one skip. Benchmark explicitly enabled.
- Normal debug suite before the final preview-only sizing helper: 221 passed,
  two skips (external database and opt-in benchmark), zero failures.
- Full AddressSanitizer and ThreadSanitizer test executions: each 221 passed,
  two optional skips, zero failures, exit 0; no sanitizer error reported.
- Isolated DEBUG preview at exact 600x500: all five Settings tabs inspected;
  common numeric settings, all five hotkey recorders and Close remain visible.
  Expanded explanations scroll. No permission or capture settings were enabled.
- Isolated editor at exact 640x420: visible folder creation, title/folder/key/text
  fields, duplicate action and save status fit. Rename auto-saved; duplication
  preserved text/folder and cleared the key; folder creation and Command-F search
  worked. Results retained folder context. Command-Q ended the test processes.
- Command-W closed the preview Settings window. Dark appearance was not forced
  successfully by the launch argument; do not treat it as a fresh dark-mode
  visual pass. The common system-appearance wiring remains covered by tests.
- Synthetic preview libraries were used throughout. No real snippets were edited.

## Security and remaining release gates

Gitleaks 8.30.1 was downloaded from its official release and verified against its
published checksum. Detector self-tests, publishable tree, 39 HEAD commits and
two side-ref-only commits passed after fetching all PR refs. This is a scoped detector
result, not a guarantee about inaccessible third-party caches or all secrets.
No keys were printed, exported or added to the repository.

Reviewed-source CI/CodeQL, Developer ID signing/notarization/stapling, public
DMG verification and backup/installation passed after this audit. Website
metadata is published separately through its protected PR. Release evidence
and the limits of the post-install visual pass are in `RELEASE-1.9.0-STATUS.md`.

Local raw test/benchmark logs are retained under ignored `.qa/190/`; they are
not published because diagnostics can contain machine-specific paths.
