#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
runner="$repository_root/scripts/security/run_secret_scan.sh"
scanner="${GITLEAKS_BIN:-gitleaks}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
printf -v canary '%s%s' 'TIMEFIT_SYNTHETIC_CREDENTIAL_' \
  '0123456789ABCDEF01234567'

git -C "$fixture" init -q
git -C "$fixture" config user.name 'TimeFit Security Fixture'
git -C "$fixture" config user.email 'security-fixture@invalid.example'
printf 'safe fixture\n' > "$fixture/fixture.txt"
git -C "$fixture" add fixture.txt
git -C "$fixture" commit -qm 'safe fixture'

GITLEAKS_BIN="$scanner" "$runner" current "$fixture" >/dev/null
GITLEAKS_BIN="$scanner" "$runner" history "$fixture" >/dev/null

# Inline comments, repository ignores, and environment config must not disable
# the pinned project policy.
printf '%s # gitleaks:allow\n' "$canary" > "$fixture/canary.txt"
printf 'canary.txt\n' > "$fixture/.gitleaksignore"
malicious_config="$fixture/empty.toml"
printf 'title = "empty"\n' > "$malicious_config"
set +e
finding_output="$(GITLEAKS_BIN="$scanner" GITLEAKS_CONFIG="$malicious_config" \
  GITLEAKS_CONFIG_TOML='title = "empty"' "$runner" current "$fixture" 2>&1)"
finding_status=$?
set -e
[[ "$finding_status" -eq 1 ]]
grep -Eq 'canary[.]txt:1:timefit-synthetic-canary' <<<"$finding_output"
if grep -Fq "$canary" <<<"$finding_output"; then
  printf 'Scanner output disclosed a finding value.\n' >&2
  exit 1
fi

git -C "$fixture" add canary.txt .gitleaksignore
git -C "$fixture" commit -qm 'synthetic historical fixture'
rm "$fixture/canary.txt" "$fixture/.gitleaksignore"
git -C "$fixture" add -u
git -C "$fixture" commit -qm 'remove synthetic historical fixture'
GITLEAKS_BIN="$scanner" "$runner" current "$fixture" >/dev/null
set +e
history_output="$(GITLEAKS_BIN="$scanner" "$runner" history "$fixture" 2>&1)"
history_status=$?
set -e
[[ "$history_status" -eq 1 ]]
grep -Eq 'canary[.]txt:1:timefit-synthetic-canary' <<<"$history_output"
if grep -Fq "$canary" <<<"$history_output"; then
  printf 'History output disclosed a finding value.\n' >&2
  exit 1
fi

shallow="$fixture-shallow"
git clone -q --depth=1 "file://$fixture" "$shallow"
set +e
shallow_output="$(GITLEAKS_BIN="$scanner" "$runner" history "$shallow" 2>&1)"
shallow_status=$?
set -e
[[ "$shallow_status" -eq 2 ]]
grep -Fq 'requires a complete checkout' <<<"$shallow_output"

set +e
error_output="$(GITLEAKS_BIN="$fixture/missing-scanner" "$runner" current "$fixture" 2>&1)"
error_status=$?
set -e
[[ "$error_status" -eq 2 ]]
grep -Fq 'Secret scanner unavailable' <<<"$error_output"

printf 'Secret scanner boundary fixtures passed.\n'
