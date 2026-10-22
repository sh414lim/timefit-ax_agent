#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

failures=0

fail() {
  printf '::error::%s\n' "$1"
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    fail "Required bootstrap file is missing: $path"
  fi
}

require_literal() {
  local path="$1"
  local literal="$2"
  local description="$3"
  if ! grep -Fq -- "$literal" "$path"; then
    fail "$description"
  fi
}

require_file lib/src/app_environment.dart
require_file lib/src/bootstrap_app.dart
require_file android/app/build.gradle.kts
require_file ios/Runner.xcodeproj/project.pbxproj
require_file .github/workflows/mobile-ci.yml
require_file scripts/ci_mobile.sh
require_file scripts/ci_mobile_gate_fixtures.sh
require_file scripts/ci/check_generated_diff.sh
require_file scripts/ci/test_performance_target_boundaries.sh
require_file scripts/ci/verify_locked_dependencies.sh
require_file scripts/ci/verify_workflow_triggers.rb

require_literal \
  lib/src/app_environment.dart \
  'production(' \
  'The production environment declaration is missing.'
require_literal \
  lib/src/app_environment.dart \
  'configurationKey: null' \
  'Production must not have a configuration key during bootstrap.'
require_literal \
  lib/src/app_environment.dart \
  'isRunnable: false' \
  'Production must remain non-runnable during bootstrap.'
require_literal \
  lib/src/bootstrap_app.dart \
  "throw StateError('production_configuration_unavailable')" \
  'Production bootstrap must fail closed.'
require_literal \
  android/app/build.gradle.kts \
  '"integration_test/chat_performance_test.dart"' \
  'The exact CHAT-073 dev profile harness target is missing.'
require_literal \
  android/app/build.gradle.kts \
  'requestedTasks.all { it.equals("assembleDevProfile", ignoreCase = true) }' \
  'The CHAT-073 harness must reject mixed and aggregate Gradle tasks.'

if [[ -e lib/main_production.dart ]]; then
  fail 'A production entrypoint must not exist before identity and signing approval.'
fi

if git grep -q -I -E \
  'com[.]leofit(Tech|tech)|com[.]timefit[.]app|6757376637|729TVX5977|dev-manager-bd0b4' \
  -- android ios lib; then
  fail 'Legacy or candidate production identity is present in implementation files.'
fi

if git grep -q -I -E \
  'DEVELOPMENT_TEAM[[:space:]]*=|PROVISIONING_PROFILE_SPECIFIER|CODE_SIGN_STYLE[[:space:]]*=[[:space:]]*Manual|signingConfig[[:space:]]*=|storeFile|storePassword|keyAlias|keyPassword' \
  -- android ios; then
  fail 'Release signing configuration is connected during the non-production bootstrap stage.'
fi

while IFS= read -r tracked_file; do
  case "$tracked_file" in
    *.jks|*.keystore|*.p8|*.p12|*.pem|*.cer|*.mobileprovision|*/key.properties|*/google-services.json|*/GoogleService-Info.plist|.env|.env.*|*/.env|*/.env.*)
      fail "Sensitive or provider-specific file is tracked: $tracked_file"
      ;;
  esac
done < <(git ls-files)

if git grep -q -I -E \
  'secrets[.]|id-token:[[:space:]]*write|contents:[[:space:]]*write|packages:[[:space:]]*write' \
  -- .github/workflows; then
  fail 'Workflow requests secrets or write-capable permissions.'
fi

if git grep -q -I -E \
  'pull_request_target|^[[:space:]]*push:|^[[:space:]]*schedule:|^[[:space:]]*release:|^[[:space:]]*workflow_run:' \
  -- .github/workflows; then
  fail 'Workflow has a trigger outside the read-only pull_request validation scope.'
fi

if git grep -q -I -E \
  'fastlane|firebase[[:space:]-]+app[[:space:]-]*distribution|google-github-actions/auth|upload-testflight|upload-google-play|play-publisher|xcrun[[:space:]]+(altool|notarytool)|flutter[[:space:]]+build[[:space:]]+(appbundle|ipa)|--release' \
  -- .github/workflows; then
  fail 'Workflow contains deployment, store upload, or release build behavior.'
fi

if ! ruby scripts/ci/verify_workflow_triggers.rb; then
  fail 'Mobile CI trigger structure is not an unfiltered pull_request trigger.'
fi

if git grep -q -I -E \
  'continue-on-error' \
  -- .github/workflows/mobile-ci.yml; then
  fail 'Mobile CI must gate every pull request path without continue-on-error.'
fi

require_literal \
  .github/workflows/mobile-ci.yml \
  'contents: read' \
  'Workflow permissions must remain contents: read.'
require_literal \
  .github/workflows/mobile-ci.yml \
  'persist-credentials: false' \
  'Checkout credentials must not persist after source checkout.'
require_literal \
  .github/workflows/mobile-ci.yml \
  "hashFiles('pubspec.lock')" \
  'Dependency cache keys must include the pubspec.lock hash.'
require_literal \
  .github/workflows/mobile-ci.yml \
  'bash scripts/ci_mobile.sh' \
  'The mobile CI workflow must run the repository CI script.'

if ((failures > 0)); then
  printf '%s\n' "Bootstrap boundary validation failed with $failures issue(s)."
  exit 1
fi

printf '%s\n' \
  'Bootstrap boundary validation passed: production identity, signing, secrets, and deployment remain disconnected.'
