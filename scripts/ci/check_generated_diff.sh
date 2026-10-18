#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

if [[ "${CI_MOBILE_USE_SYSTEM_FLUTTER:-0}" == "1" ]]; then
  dart_command=(dart)
else
  dart_command=(fvm dart)
fi

temporary_directory="$(mktemp -d)"
cleanup() {
  local safe_tmp_root="${TMPDIR:-/tmp}"
  safe_tmp_root="${safe_tmp_root%/}"
  case "$temporary_directory" in
    /tmp/*|/private/tmp/*|"$safe_tmp_root"/*)
      rm -rf "$temporary_directory"
      ;;
    *)
      printf 'Refusing to remove unexpected temporary path: %s\n' "$temporary_directory" >&2
      ;;
  esac
}
trap cleanup EXIT

capture_repository_state() {
  git status --porcelain=v1 --untracked-files=all
  git diff --binary --no-ext-diff
  git diff --cached --binary --no-ext-diff
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

capture_target_tree() {
  local target_root
  local path
  for target_root in lib test integration_test; do
    [[ -d "$target_root" ]] || continue
    while IFS= read -r path; do
      printf '%s  %s\n' "$(sha256_file "$path")" "$path"
    done < <(find "$target_root" -type f -print | LC_ALL=C sort)
  done
}

before_state="$temporary_directory/before"
after_state="$temporary_directory/after"
before_tree="$temporary_directory/before-tree"
after_tree="$temporary_directory/after-tree"
capture_repository_state > "$before_state"
capture_target_tree > "$before_tree"

"${dart_command[@]}" run build_runner build --delete-conflicting-outputs

capture_repository_state > "$after_state"
capture_target_tree > "$after_tree"
if ! cmp -s "$before_state" "$after_state" || ! cmp -s "$before_tree" "$after_tree"; then
  printf '%s\n' 'Generated files are stale or missing. Commit the generated output.' >&2
  git status --short >&2
  git diff --stat >&2
  diff -u "$before_tree" "$after_tree" >&2 || true
  exit 1
fi

printf '%s\n' 'Generated file diff gate passed.'
