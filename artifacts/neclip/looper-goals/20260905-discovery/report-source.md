# NeClip research synthesis

Audience: product owner and macOS maintainers. Date: 2026-09-05.

Scope: local macOS clipboard/snippet/layout workflows, compared against official macOS/Windows product documentation. No accounts, cloud, AI, telemetry, keyboard diaries or scripting. No installation/testing of competitors; no performance claims inferred from marketing.

Executive answer: complete folder-first retrieval and safe editing rather than expand the number of modes. Selected 27 improvements, including correctness and privacy defects, from 100 evaluated candidates. Evidence indicates most baseline clipboard features already exist in NeClip.

Primary evidence ledger and full product-by-product analysis: docs/RESEARCH-2026-09-05.md. Every product row records publisher via its official domain/repository, document title via link label, access date 2026-09-05; update dates unknown unless explicitly reported. Worker results reconciled with parent-visible primary sources for Alfred/Maccy/Clipy/RuSwitcher/Alt SwitchER. Actual retrieval used bounded official-page/README discovery followed by targeted contradiction verification.

Material correction: RuSwitcher and Alt SwitchER are not manual-only in currently visible documentation. Mahou historical fork supports manual claims only; modern upstream unavailable, so no inferred auto claim. Kawa switches input source, not typed text.

Implementation analysis: fixes to stale async-search activation, standard menu footer, exact-key ranking before LIMIT, clean-editor refresh, full-erasure undo state, case-insensitive protected app identities. Date rendering and line transformations remain local and deterministic.

Limitations: no measured comparative latency, no all-OS compatibility certification, no external binary publication proof. Acceptance is split into behavioral tests, local strict build/security checks, isolated UI sampling, and a separate signed/notarized public release gate.

Stop rationale: additional general competitor searches would duplicate covered mechanisms. Remaining material gaps concern runtime/permissions and require tests rather than more product pages.
