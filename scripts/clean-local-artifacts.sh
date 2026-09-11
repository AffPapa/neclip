#!/usr/bin/env bash
# Remove only reproducible local build and QA output. Release archives and user
# application data are intentionally outside this allowlist.
set -euo pipefail

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"

for path in .build .build-asan .build-tsan .build-strict .qa; do
  if [[ -e "$path" ]]; then
    rm -rf -- "$path"
  fi
done

find . -maxdepth 2 -type f -name .DS_Store -delete
