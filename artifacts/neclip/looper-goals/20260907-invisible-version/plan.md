# NeClip: invisible helper and version clarity

7 September 2026. Baseline source `0a5357e943bc7bb318bd0926d35746c6dcddc55b`;
public 1.10.0/build17. Installed production remains 1.9.1/build16.

## Goal and professional prompts

1. Product researcher: compare 10–20 relevant clipboard utilities through
   official docs/repositories and attributable reviews/issues. Separate facts,
   isolated reports and recommendations. Do not restore search, pins or cloud.
2. macOS performance engineer: measure baseline, remove demonstrated redundant
   work, preserve privacy/data/keyboard safeguards, verify equivalence and report
   microbenchmark limitations. No line-count target justifies losing behavior.
3. UX/update engineer: a persistent Version Settings pane, installed bundle
   identity, last checked GitHub release/date, explicit-only network checks,
   honest cached/error/development states, one request at a time, safe URLs.

All three independent read-only audits preceded implementation. Primary agent
read the Goal skill, skill-installer discovery instructions and OpenAI's
swiftui-performance-audit with its code-smell, profiling and reporting references.
The latter is read-only guidance, not an installed dependency or script runner.

## P0/P1 implementation gate

- Replace modal update results with a Version pane and a small observable state
  model. Preserve validated repository-owned download URLs and bounded responses;
  bound transport before complete download, avoid cookies and arbitrary redirects.
- Cache only a validated release plus successful check date; opening Settings
  or About never starts a network request. Failed checks retain dated old evidence.
- Distinguish newer/equal/older remote and unknown local identity. Repeated clicks
  cannot create overlapping checks or late modal windows.
- Share SHA256 hex encoding without per-byte formatters; regression vectors and
  isolated optimized-build microbenchmark. Preserve hashes and deduplication.
- Group editor rows once without tuple intermediates; retain sort semantics.
- Remove per-folder menu sorting only because SQL already supplies stable order
  before bounds and grouping preserves it; cover ties/unfiled rows in tests.

## Protected scope and deferred work

No production app replacement/database migration, credentials, cloud/telemetry,
new dependencies, automatic network checks or unrelated services. Do not change
privacy polling, pause expiry, pasteboard restoration or OCR completion semantics.
No public release or website update is claimed by a local implementation.

## Verification / done

Programmatic: targeted state/transport/cache/navigation/hash/order tests, full
debug and strict release tests/build, ASan/TSan, secret/tree/history checks,
JSON/plist consistency and clean diff. Compare size from equivalent stripped
builds; report new-feature costs separately from removal of redundant work.
Judge: 10–20 product comparison with sources and attributable review evidence;
bounded recommendations, explicit keep/defer/reject decisions; isolated native
light/dark Version pane, minimum window, close/About/menu flow, cached/unknown
and checking/error/success states where reproducible without production data.
Delivery: source implementation, updated map/backlog/audit and evidence; no
automatic deployment or installation without its own release/rollback gates.

## Local outcome

The three audit tracks and the implementation above are complete. Research
covers 15 products. The Version pane was checked in isolated native light/dark
QA, including manual GitHub check, cached relaunch, About navigation, Close and
Command-W. The installed app and public release remain unchanged.

A bounded compiler experiment selected release-only `-Osize` for the NeClip
target, leaving GRDB at `-O`: the stripped executable is 4,329,808 bytes,
1.22% below public 1.10.0 despite the new Version pane. Global `-Osize` was
rejected because repeated projected menu reads slowed down. The accepted
target-only variant had no sustained slowdown in the measured synthetic reads;
this is not an application startup or GUI latency claim. CI now also runs
strict release tests against the accepted target setting.

Detailed methods, exact test counts, skill/source links and limitations:
`docs/AUDIT-1.11.0-2026-09-07.md` and
`docs/RESEARCH-1.11.0-INVISIBLE-2026-09-07.md`.
