# Security and privacy

Please report a vulnerability through
[GitHub Private Vulnerability Reporting](https://github.com/AffPapa/neclip/security/advisories/new).
Do not include real clipboard contents in a public issue.

NeClip stores history locally in Application Support, performs OCR and layout
decisions on-device, makes no automatic network requests, and uses the network
only when the user explicitly chooses “Check for Updates”.

Release binaries are accepted only after Developer ID signing, Apple
notarization, stapling, Gatekeeper assessment and published SHA-256 verification.
The only supported public release is `v2.5.7`, with immutable assets and tag.
Older releases and tags have been removed. GitHub also checks Swift
and workflow source with CodeQL, allows only GitHub-owned Actions referenced by
full SHA and monitors the exact SwiftPM dependency for vulnerabilities. Branch
and repository rules are verified through an authenticated GitHub release gate;
this document does not infer their current state from an unauthenticated API.

Every push, pull request and weekly scheduled run also executes a fully
redacted Gitleaks scan over both the publishable working tree and every fetched
Git ref. The workflow downloads a fixed Gitleaks version and verifies the exact
archive SHA-256 before execution. It receives read-only repository permission,
does not use repository secrets and never runs through `pull_request_target`.

To run the same gate locally, install Gitleaks and execute:

```sh
scripts/secret-scan.sh
```

The repository ignores local environment files, signing keys, Keychains,
provisioning profiles, clipboard databases, logs and release archives. These
rules are defense in depth, not a substitute for revoking a credential: if a
real secret is ever committed, revoke it at the provider first, then remove it
from Git history and public artifacts.
