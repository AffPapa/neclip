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

# Old versions created compatibility links through releases/current. Once the
# current release changes those links are dangling; unlink only that exact form.
for path in dist/NeClip-*.dmg dist/NeClip-*.dmg.sha256 dist/NeClip-*.release.json; do
  if [[ -L "$path" && ! -e "$path" ]]; then
    target="$(readlink "$path")"
    if [[ "$target" == "releases/current/$(basename "$path")" ]]; then
      rm -- "$path"
    fi
  fi
done

find . -maxdepth 2 -type f -name .DS_Store -delete
