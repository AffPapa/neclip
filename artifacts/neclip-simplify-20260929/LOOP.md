# NeClip simplification and reliability, 2026-09-29

Goal: simplify everyday settings and explanations, reduce confirmed wasted work,
fix reproducible defects, publish the next immutable Direct release and install
the verified public application while preserving user data.

Base: clean active checkout at a13efd058d7776f8ca0ca4090049652064883156;
GitHub latest 3.0.1/build56 verified. Separate Dependabot PR80 is not part of this
product slice. Three independent read-only agents covered UX/accessibility,
Swift/SQLite performance/code size, and correctness/privacy. Parent owns edits,
tests, GitHub publication and local installation.

Plan gate: no confirmed P0. Accepted P1/P2: three settings destinations with
progressive disclosure and visible active restrictions; single exact history
limit; predictable About-to-settings navigation; clear backup replacement
confirmation and Russian feedback; readable file paths in plain-text paste;
remove unused trim aggregation and dead helpers; preserve unchanged search
application choices. No schema change, preference reset, new dependency or
clipboard/snippet feature removal. Retired screenshot/layout features stay absent.

Verification: actual before/after synthetic trim measurement, named pasteboard
regressions, settings navigation and search identity checks; strict debug and
release, relevant sanitizers; isolated native UI at minimum window size; site,
SEO and secret scans. No synthetic metric represents total application latency.

Release gate: checkpoint after local checks; protected PR and required CI;
build exact merged source, Developer ID/notarize/staple/Gatekeeper; both archives
and checksum files attached before immutable publication; independently download
and verify; metadata PR/Pages plus live byte checks; private local data backup,
public ZIP installation and preservation checks. Do not bypass protections or
alter previous immutable releases.

Stop after this coherent verified slice. Reconsider only for a failed check or
concrete new evidence. Preserve rollback material and report unverified physical
cross-app, VoiceOver speech and other macOS scenarios honestly.

## Local gate passed

Strict debug/release, ASan/TSan:291XCTest,10expected skips,0failures,+4SwiftTesting. Benchmark-enabled release291/1skip/0failures. Site14tests45assertions,SEO18tests52assertions pass. Gitleaks canaries/tree/275HEADcommits+26side-ref-only clean; GitHub open CodeQL/secret alerts0. Native isolated UI validated3sections,350persisted,Escape,Aboutreturn,600x500,full-label disclosures,backupCancel. Source review preserved transactional shortcut reset after independent reviewers caught swapped-key recovery. Scope complete; source PR and requiredCI next.
