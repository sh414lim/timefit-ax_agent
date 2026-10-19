#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

phase="${1:-quality-android}"
if [[ "$phase" != "quality-android" && "$phase" != "ios" ]]; then
  printf 'Usage: %s [quality-android|ios]\n' "$0" >&2
  exit 2
fi

if [[ "${CI_MOBILE_USE_SYSTEM_FLUTTER:-0}" == "1" ]]; then
  flutter_command=(flutter)
  dart_command=(dart)
else
  flutter_command=(fvm flutter)
  dart_command=(fvm dart)
fi

if ! grep -Eq '"flutter"[[:space:]]*:[[:space:]]*"3[.]38[.]5"' .fvmrc; then
  printf '%s\n' '.fvmrc must pin Flutter 3.38.5.' >&2
  exit 1
fi

toolchain_json="$("${flutter_command[@]}" --version --machine)"
grep -Eq '"frameworkVersion"[[:space:]]*:[[:space:]]*"3[.]38[.]5"' <<<"$toolchain_json"
grep -Eq '"dartSdkVersion"[[:space:]]*:[[:space:]]*"3[.]10[.]4"' <<<"$toolchain_json"

bash scripts/ci/verify_locked_dependencies.sh

if [[ "$phase" == "quality-android" ]]; then
  bash scripts/ci/check_generated_diff.sh

  format_targets=(lib test)
  if [[ -d integration_test ]]; then
    format_targets+=(integration_test)
  fi
  "${dart_command[@]}" format --output=none --set-exit-if-changed "${format_targets[@]}"
  "${flutter_command[@]}" analyze --fatal-infos --fatal-warnings
  "${flutter_command[@]}" test --coverage --reporter expanded
  test -s coverage/lcov.info

  "${flutter_command[@]}" build apk --debug --no-pub --flavor dev --target lib/main.dart
  "${flutter_command[@]}" build apk --debug --no-pub --flavor staging \
    --target lib/main_staging.dart
else
  "${flutter_command[@]}" build ios --debug --no-codesign --no-pub --flavor dev \
    --target lib/main.dart
  "${flutter_command[@]}" build ios --debug --no-codesign --no-pub --flavor staging \
    --target lib/main_staging.dart
fi

printf 'Mobile CI phase passed: %s\n' "$phase"
