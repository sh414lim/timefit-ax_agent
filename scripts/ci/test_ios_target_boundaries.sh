#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
guard="$repository_root/scripts/ci/validate_ios_environment.sh"
sandbox="$(mktemp -d)"
project="$sandbox/project"
ios_project="$project/ios"
output="$sandbox/output"
listener_template="$repository_root/scripts/ci/fixtures/flutter_3_38_5_integration_listener.dart.template"

cleanup() {
  rm -rf "$sandbox"
}
trap cleanup EXIT

mkdir -p "$ios_project/Flutter" "$project/integration_test"
touch "$project/integration_test/chat_e2e_test.dart"
project="$(cd "$project" && pwd -P)"
ios_project="$project/ios"

run_case() {
  local expected="$1"
  local description="$2"
  local environment="$3"
  local expected_target="$4"
  local actual_target="$5"
  local configuration="$6"
  local platform="$7"
  local sdk="$8"
  local status=0

  case "$actual_target" in
    CHAT_E2E_LISTENER)
      actual_target="$sandbox/flutter_test_listener.allowed/listener.dart"
      mkdir -p "$(dirname "$actual_target")"
      sed "s|__REPOSITORY_URI__|file://${project}|g" \
        "$listener_template" >"$actual_target"
      ;;
    CHAT_E2E_LISTENER_EXTRA_IMPORT)
      actual_target="$sandbox/flutter_test_listener.extra_import/listener.dart"
      mkdir -p "$(dirname "$actual_target")"
      sed "s|__REPOSITORY_URI__|file://${project}|g" \
        "$listener_template" >"$actual_target"
      printf "%s\n" "import 'file://${project}/integration_test/unapproved.dart';" \
        >>"$actual_target"
      ;;
    CHAT_E2E_LISTENER_EXTRA_CODE)
      actual_target="$sandbox/flutter_test_listener.extra_code/listener.dart"
      mkdir -p "$(dirname "$actual_target")"
      sed "s|__REPOSITORY_URI__|file://${project}|g" \
        "$listener_template" >"$actual_target"
      printf '%s\n' 'void unexpectedMain() {}' >>"$actual_target"
      ;;
    OTHER_TEST_LISTENER)
      actual_target="$sandbox/flutter_test_listener.other/listener.dart"
      mkdir -p "$(dirname "$actual_target")"
      printf "import 'file://%s/integration_test/unapproved.dart';\n" \
        "$project" >"$actual_target"
      ;;
    SPOOFED_TEST_LISTENER)
      actual_target="$sandbox/flutter_test_listener.spoofed/listener.dart"
      mkdir -p "$(dirname "$actual_target")"
      printf "// file://%s/integration_test/chat_e2e_test.dart\nimport 'file://%s/integration_test/unapproved.dart' as test;\n" \
        "$project" "$project" >"$actual_target"
      ;;
  esac
  printf 'FLUTTER_TARGET=%s\n' \
    "$actual_target" >"$ios_project/Flutter/Generated.xcconfig"
  PROJECT_DIR="$ios_project" \
    TIMEFIT_ENVIRONMENT="$environment" \
    TIMEFIT_EXPECTED_FLUTTER_TARGET="$expected_target" \
    CONFIGURATION="$configuration" \
    PLATFORM_NAME="$platform" \
    SDK_NAME="$sdk" \
    "$guard" >"$output" 2>&1 || status=$?

  if [[ "$expected" == pass && "$status" -ne 0 ]]; then
    cat "$output" >&2
    printf 'Expected iOS boundary pass failed: %s\n' "$description" >&2
    exit 1
  fi
  if [[ "$expected" == reject && "$status" -eq 0 ]]; then
    printf 'Expected iOS boundary rejection did not occur: %s\n' \
      "$description" >&2
    exit 1
  fi
  if [[ "$expected" == reject ]] &&
      ! grep -Fq 'does not allow the requested Flutter target' "$output"; then
    cat "$output" >&2
    printf 'iOS boundary rejection lacked fail-closed diagnostic: %s\n' \
      "$description" >&2
    exit 1
  fi
  printf 'iOS target boundary %s: %s\n' "$expected" "$description"
}

run_case pass 'normal dev entrypoint' \
  dev lib/main.dart lib/main.dart Release-dev iphoneos iphoneos18.1
run_case pass 'normal staging entrypoint' \
  staging lib/main_staging.dart lib/main_staging.dart Release-staging \
  iphoneos iphoneos18.1
run_case pass 'CHAT-074 dev debug simulator target' \
  dev lib/main.dart CHAT_E2E_LISTENER Debug-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'CHAT-074 staging target' \
  staging lib/main_staging.dart CHAT_E2E_LISTENER \
  Debug-staging iphonesimulator iphonesimulator18.1
run_case reject 'CHAT-074 production target' \
  production lib/main.dart CHAT_E2E_LISTENER Debug-production \
  iphonesimulator iphonesimulator18.1
run_case reject 'CHAT-074 physical device target' \
  dev lib/main.dart CHAT_E2E_LISTENER Debug-dev \
  iphoneos iphoneos18.1
run_case reject 'CHAT-074 release simulator target' \
  dev lib/main.dart CHAT_E2E_LISTENER Release-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'CHAT-074 profile simulator target' \
  dev lib/main.dart CHAT_E2E_LISTENER Profile-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'CHAT-074 mixed simulator and device SDK' \
  dev lib/main.dart CHAT_E2E_LISTENER Debug-dev \
  iphonesimulator iphoneos18.1
run_case reject 'unapproved integration target' \
  dev lib/main.dart OTHER_TEST_LISTENER Debug-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'direct integration target without Flutter test listener' \
  dev lib/main.dart integration_test/chat_e2e_test.dart Debug-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'listener comment cannot spoof CHAT-074 target' \
  dev lib/main.dart SPOOFED_TEST_LISTENER Debug-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'listener with additional import' \
  dev lib/main.dart CHAT_E2E_LISTENER_EXTRA_IMPORT Debug-dev \
  iphonesimulator iphonesimulator18.1
run_case reject 'listener with additional code' \
  dev lib/main.dart CHAT_E2E_LISTENER_EXTRA_CODE Debug-dev \
  iphonesimulator iphonesimulator18.1
