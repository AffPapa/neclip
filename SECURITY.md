# Security and privacy

Please report a vulnerability privately through GitHub Security Advisories in
the NeClip repository. Do not include real clipboard contents in a public issue.

NeClip stores history locally in Application Support, performs OCR and layout
decisions on-device, makes no automatic network requests, and uses the network
only when the user explicitly chooses “Check for Updates”.

Release binaries are accepted only after Developer ID signing, Apple
notarization, stapling, Gatekeeper assessment and published SHA-256 verification.
