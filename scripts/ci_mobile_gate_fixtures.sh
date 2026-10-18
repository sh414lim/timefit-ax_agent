#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d)"

cleanup() {
  local safe_tmp_root="${TMPDIR:-/tmp}"
  safe_tmp_root="${safe_tmp_root%/}"
  case "$temporary_root" in
    /tmp/*|/private/tmp/*|"$safe_tmp_root"/*)
      rm -rf "$temporary_root"
      ;;
    *)
      printf 'Refusing to remove unexpected temporary path: %s\n' "$temporary_root" >&2
      ;;
  esac
}
trap cleanup EXIT

new_fixture() {
  local name="$1"
  local target="$temporary_root/$name"
  mkdir -p "$target"
  cp -R "$repository_root/." "$target/"
  printf '%s\n' "$target"
}

expect_failure() {
  local description="$1"
  local expected_pattern="$2"
  shift 2
  local output_file="$temporary_root/expected-failure-$RANDOM.log"
  local status=0
  "$@" >"$output_file" 2>&1 || status=$?
  cat "$output_file"
  if ((status == 0)); then
    printf 'Expected failure did not occur: %s\n' "$description" >&2
    exit 1
  fi
  if ! grep -Eq "$expected_pattern" "$output_file"; then
    printf 'Failure did not contain the expected diagnostic: %s\n' "$description" >&2
    exit 1
  fi
  printf 'Expected failure confirmed: %s\n' "$description"
}

lint_fixture="$(new_fixture lint)"
printf '%s\n' \
  'void chat005IntentionalLintFailure() {' \
  '  missingChat005Identifier;' \
  '}' > "$lint_fixture/lib/chat005_intentional_lint_failure.dart"
expect_failure \
  'analyzer rejects an intentional undefined identifier' \
  'undefined_identifier|Undefined name' \
  env CI_MOBILE_USE_SYSTEM_FLUTTER=1 bash "$lint_fixture/scripts/ci_mobile.sh"

lock_fixture="$(new_fixture lockfile)"
sed -i.bak 's/uuid: 4[.]5[.]2/uuid: 4.5.1/' "$lock_fixture/pubspec.yaml"
rm -f "$lock_fixture/pubspec.yaml.bak"
expect_failure \
  'locked resolution rejects a dependency change without a matching lockfile' \
  'lockfile|lock file|pubspec[.]lock' \
  env CI_MOBILE_USE_SYSTEM_FLUTTER=1 \
    bash "$lock_fixture/scripts/ci/verify_locked_dependencies.sh"

generated_fixture="$(new_fixture generated)"
printf '%s\n' \
  "import 'package:json_annotation/json_annotation.dart';" \
  '' \
  "part 'chat005_generated_fixture.g.dart';" \
  '' \
  '@JsonSerializable()' \
  'class Chat005GeneratedFixture {' \
  '  const Chat005GeneratedFixture({required this.value});' \
  '' \
  '  factory Chat005GeneratedFixture.fromJson(Map<String, dynamic> json) =>' \
  '      _$Chat005GeneratedFixtureFromJson(json);' \
  '' \
  '  final String value;' \
  '' \
  '  Map<String, dynamic> toJson() => _$Chat005GeneratedFixtureToJson(this);' \
  '}' > "$generated_fixture/lib/chat005_generated_fixture.dart"
expect_failure \
  'generated diff gate rejects an uncommitted generated file' \
  'Generated files are stale or missing' \
  env CI_MOBILE_USE_SYSTEM_FLUTTER=1 \
    bash "$generated_fixture/scripts/ci/check_generated_diff.sh"

printf '%s\n' 'Intentional CI gate failure fixtures passed without changing the source checkout.'
