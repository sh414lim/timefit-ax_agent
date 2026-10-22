#!/usr/bin/env bash

set -euo pipefail

generated_xcconfig="${PROJECT_DIR}/Flutter/Generated.xcconfig"
if [[ ! -f "$generated_xcconfig" ]]; then
  printf '%s\n' 'error: Missing Flutter/Generated.xcconfig.' >&2
  exit 1
fi

xcconfig_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$generated_xcconfig" | tail -n 1
}

actual_target="$(xcconfig_value FLUTTER_TARGET)"
if [[ "$actual_target" == "${TIMEFIT_EXPECTED_FLUTTER_TARGET}" ]]; then
  exit 0
fi

chat_e2e_target='integration_test/chat_e2e_test.dart'
repository_root="$(cd "${PROJECT_DIR}/.." && pwd -P)"
expected_test_uri="file://${repository_root}/${chat_e2e_target}"
is_chat_e2e_listener=false
case "$actual_target" in
  */flutter_test_listener.*/listener.dart)
    if [[ -f "$actual_target" ]] &&
        [[ "$(grep -Fxc "import '${expected_test_uri}' as test;" "$actual_target")" -eq 1 ]]; then
      is_chat_e2e_listener=true
    fi
    ;;
esac

if [[ "$is_chat_e2e_listener" == true ]] &&
    [[ "${TIMEFIT_ENVIRONMENT}" == 'dev' ]] &&
    [[ "${TIMEFIT_EXPECTED_FLUTTER_TARGET}" == 'lib/main.dart' ]] &&
    [[ "${CONFIGURATION}" == 'Debug-dev' ]] &&
    [[ "${PLATFORM_NAME}" == 'iphonesimulator' ]] &&
    [[ "${SDK_NAME}" == iphonesimulator* ]]; then
  exit 0
fi

printf 'error: %s does not allow the requested Flutter target and build boundary.\n' \
  "${TIMEFIT_ENVIRONMENT}" >&2
exit 1
