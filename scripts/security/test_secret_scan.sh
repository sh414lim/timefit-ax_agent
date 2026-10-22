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
grep -Fxq 'line=1 type=timefit-synthetic-canary' <<<"$finding_output"
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
grep -Fxq 'line=1 type=timefit-synthetic-canary' <<<"$history_output"
if grep -Fq "$canary" <<<"$history_output"; then
  printf 'History output disclosed a finding value.\n' >&2
  exit 1
fi

# Finding paths are attacker-controlled too. Neither credential-shaped names
# nor terminal-control content may be copied into public scanner output.
malicious_name="${canary}"$'\nINJECTED_OUTPUT.txt'
printf '%s\n' "$canary" > "$fixture/$malicious_name"
set +e
path_output="$(GITLEAKS_BIN="$scanner" "$runner" current "$fixture" 2>&1)"
path_status=$?
set -e
[[ "$path_status" -eq 1 ]]
grep -Fxq 'line=1 type=timefit-synthetic-canary' <<<"$path_output"
if grep -Fq "$canary" <<<"$path_output" ||
  grep -Fq 'INJECTED_OUTPUT' <<<"$path_output"; then
  printf 'Scanner output disclosed an untrusted finding path.\n' >&2
  exit 1
fi
rm "$fixture/$malicious_name"

# A malformed or injected report is a scanner error, never a printable
# finding. This also fences rule and line fields before the summary jq pass.
fake_scanner="$fixture/fake-scanner"
cat > "$fake_scanner" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
report=''
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '--report-path' ]]; then
    shift
    report="$1"
  fi
  shift
done
printf '%s' '[{"File":"private-path","StartLine":"1","RuleID":"bad\\nINJECTED_RULE"}]' > "$report"
exit 1
SCRIPT
chmod 700 "$fake_scanner"
set +e
malformed_output="$(GITLEAKS_BIN="$fake_scanner" "$runner" current "$fixture" 2>&1)"
malformed_status=$?
set -e
[[ "$malformed_status" -eq 2 ]]
grep -Fxq 'Secret scanner failed without a valid findings report.' \
  <<<"$malformed_output"
if grep -Fq 'private-path' <<<"$malformed_output" ||
  grep -Fq 'INJECTED_RULE' <<<"$malformed_output"; then
  printf 'Scanner output disclosed an invalid report field.\n' >&2
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
