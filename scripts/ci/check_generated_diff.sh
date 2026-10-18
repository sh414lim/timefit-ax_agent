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

before_state="$temporary_directory/before"
after_state="$temporary_directory/after"
capture_repository_state > "$before_state"

"${dart_command[@]}" run build_runner build --delete-conflicting-outputs

capture_repository_state > "$after_state"
if ! cmp -s "$before_state" "$after_state"; then
  printf '%s\n' 'Generated files are stale or missing. Commit the generated output.' >&2
  git status --short >&2
  git diff --stat >&2
  exit 1
fi

printf '%s\n' 'Generated file diff gate passed.'
