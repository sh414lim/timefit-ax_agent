#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

if [[ "${CI_MOBILE_USE_SYSTEM_FLUTTER:-0}" == "1" ]]; then
  flutter_command=(flutter)
else
  flutter_command=(fvm flutter)
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

if [[ ! -f pubspec.lock ]]; then
  printf '%s\n' 'pubspec.lock is required for reproducible dependency resolution.' >&2
  exit 1
fi

lock_hash_before="$(sha256_file pubspec.lock)"
"${flutter_command[@]}" pub get --enforce-lockfile
lock_hash_after="$(sha256_file pubspec.lock)"

if [[ "$lock_hash_before" != "$lock_hash_after" ]]; then
  printf '%s\n' 'pubspec.lock changed during locked dependency resolution.' >&2
  exit 1
fi

printf 'Locked dependency resolution passed: pubspec.lock sha256=%s\n' "$lock_hash_after"
