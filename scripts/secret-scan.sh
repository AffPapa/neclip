#!/bin/bash
# Scan publishable files and every fetched Git ref without printing secret values.
set -euo pipefail

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

GITLEAKS="${GITLEAKS_BIN:-$(command -v gitleaks || true)}"
if [[ -z "$GITLEAKS" || ! -x "$GITLEAKS" ]]; then
  echo "Gitleaks is required. Set GITLEAKS_BIN or install gitleaks." >&2
  exit 1
fi

SCAN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/neclip-secret-scan.XXXXXX")
cleanup() {
  rm -rf "$SCAN_DIR"
}
trap cleanup EXIT

# Export only tracked and non-ignored untracked files. This prevents vendored
# SwiftPM build checkouts from creating noise while still catching a secret
# before its first commit.
while IFS= read -r -d '' source_path; do
  # `git ls-files -c` also reports tracked paths deleted in the working tree.
  # Their committed contents are covered by the history scan below; skipping
  # missing paths keeps pre-commit scans valid during refactors and renames.
  [[ -e "$source_path" || -L "$source_path" ]] || continue
  target_path="$SCAN_DIR/$source_path"
  mkdir -p "$(dirname "$target_path")"
  cp -P "$source_path" "$target_path"
done < <(git ls-files -co --exclude-standard -z)

COMMON_ARGS=(
  --redact=100
  --no-banner
  --no-color
  --max-archive-depth=5
  --max-decode-depth=8
)

"$GITLEAKS" dir "${COMMON_ARGS[@]}" "$SCAN_DIR"
"$GITLEAKS" git "${COMMON_ARGS[@]}" --log-opts="--all --full-history" "$ROOT_DIR"

echo "OK: publishable tree and complete fetched Git history contain no detected secrets"
