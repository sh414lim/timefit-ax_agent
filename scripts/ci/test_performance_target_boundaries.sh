#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gradle="$repository_root/android/gradlew"
approved_targets=(
  "integration_test/chat_performance_test.dart"
  "integration_test/chat_e2e_test.dart"
)
temporary="$(mktemp)"

cleanup() {
  rm -f "$temporary"
}
trap cleanup EXIT

run_case() {
  local expected="$1"
  local description="$2"
  local target="$3"
  shift 3
  local status=0
  (
    cd "$repository_root/android"
    "$gradle" "$@" "-Ptarget=$target" --dry-run --offline --console=plain
  ) >"$temporary" 2>&1 || status=$?

  if [[ "$expected" == "pass" && "$status" -ne 0 ]]; then
    cat "$temporary" >&2
    printf 'Expected Gradle boundary pass failed: %s\n' "$description" >&2
    exit 1
  fi
  if [[ "$expected" == "reject" && "$status" -eq 0 ]]; then
    cat "$temporary" >&2
    printf 'Expected Gradle boundary rejection did not occur: %s\n' "$description" >&2
    exit 1
  fi
  if [[ "$expected" == "reject" ]] &&
      ! grep -Fq 'does not allow the requested Flutter target' "$temporary" &&
      ! grep -Fq 'requires only assembleDevProfile' "$temporary"; then
    cat "$temporary" >&2
    printf 'Gradle boundary rejection lacked the fail-closed diagnostic: %s\n' \
      "$description" >&2
    exit 1
  fi
  printf 'Gradle performance target boundary %s: %s\n' "$expected" "$description"
}

for approved_target in "${approved_targets[@]}"; do
  run_case pass "single dev profile task for $approved_target" \
    "$approved_target" :app:assembleDevProfile
  run_case reject "dev debug task for $approved_target" \
    "$approved_target" :app:assembleDevDebug
  run_case reject "staging profile task for $approved_target" \
    "$approved_target" :app:assembleStagingProfile
  run_case reject "mixed dev debug and dev profile tasks for $approved_target" \
    "$approved_target" :app:assembleDevDebug :app:assembleDevProfile
  run_case reject "mixed dev and staging profile tasks for $approved_target" \
    "$approved_target" :app:assembleDevProfile :app:assembleStagingProfile
  run_case reject "aggregate profile task for $approved_target" \
    "$approved_target" :app:assembleProfile
done
run_case reject 'unapproved integration target' \
  'integration_test/unapproved.dart' :app:assembleDevProfile
