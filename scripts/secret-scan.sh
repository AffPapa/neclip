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

verify_detector() {
  local label=$1
  local payload=$2
  local detector_exit
  set +e
  printf '%s\n' "$payload" | "$GITLEAKS" stdin "${COMMON_ARGS[@]}" >/dev/null 2>&1
  detector_exit=$?
  set -e
  if [[ $detector_exit -ne 1 ]]; then
    echo "Gitleaks detector self-test failed for ${label} (exit ${detector_exit})." >&2
    exit 1
  fi
}

# Construct realistic canaries at runtime so the scanner proves its embedded
# rules work without making the scanner script itself look like a credential.
github_canary="ghp_${GITHUB_CANARY_LEFT:-a1B2c3D4e5F6g7H8i9}${GITHUB_CANARY_RIGHT:-J0k1L2m3N4p5Q6r7S8}"
aws_canary=$(printf '%s\n%s' \
  "aws_access_key_id = \"AK${AWS_CANARY_MIDDLE:-IA}${AWS_CANARY_BODY:-7ZLEWQ1B2C3D4E5F}\"" \
  "aws_secret_access_key = \"${AWS_SECRET_LEFT:-m7J8vK9xT2pQ4rS6uV8w}${AWS_SECRET_RIGHT:-Y0zA1bC3dE5fG7hI9jK0}\"")
slack_canary="slack_token = \"xo${SLACK_CANARY_KIND:-xb-}${SLACK_CANARY_BODY:-12345678901-123456789012-a1B2c3D4e5F6g7H8i9J0k1L2}\""
verify_detector "GitHub PAT" "$github_canary"
verify_detector "AWS access key" "$aws_canary"
verify_detector "Slack bot token" "$slack_canary"
unset github_canary aws_canary slack_canary

"$GITLEAKS" dir "${COMMON_ARGS[@]}" "$SCAN_DIR"
"$GITLEAKS" git "${COMMON_ARGS[@]}" --log-opts="--full-history HEAD" "$ROOT_DIR"
"$GITLEAKS" git "${COMMON_ARGS[@]}" --log-opts="--all --not HEAD" "$ROOT_DIR"

head_commit_count=$(git rev-list --count HEAD)
side_ref_commit_count=$(git rev-list --count --all --not HEAD)
echo "OK: detector self-tests, publishable tree, ${head_commit_count} HEAD commits and ${side_ref_commit_count} side-ref-only commits are clean"
