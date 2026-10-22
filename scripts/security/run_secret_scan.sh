#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:-}"
target="${2:-$repository_root}"
scanner="${GITLEAKS_BIN:-gitleaks}"

if [[ "$mode" != "current" && "$mode" != "history" ]]; then
  printf 'Usage: secret scan current|history [repository]\n' >&2
  exit 2
fi
if ! command -v "$scanner" >/dev/null 2>&1; then
  printf 'Secret scanner unavailable.\n' >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  printf 'Secret report summarizer unavailable.\n' >&2
  exit 2
fi
if [[ "$mode" == "history" ]]; then
  if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Full-history scan requires a Git worktree.\n' >&2
    exit 2
  fi
  if [[ "$(git -C "$target" rev-parse --is-shallow-repository)" == "true" ]]; then
    printf 'Full-history scan requires a complete checkout.\n' >&2
    exit 2
  fi
fi

report="$(mktemp)"
trap 'rm -f "$report"' EXIT
chmod 600 "$report"
common=(
  --config "$repository_root/.gitleaks.toml"
  --gitleaks-ignore-path "$repository_root/scripts/security/empty.gitleaksignore"
  --ignore-gitleaks-allow
  --redact=100
  --no-banner
  --no-color
  --report-format json
  --report-path "$report"
  --timeout 120
)

set +e
if [[ "$mode" == "current" ]]; then
  env -u GITLEAKS_CONFIG -u GITLEAKS_CONFIG_TOML \
    "$scanner" dir "${common[@]}" "$target" >/dev/null 2>&1
else
  env -u GITLEAKS_CONFIG -u GITLEAKS_CONFIG_TOML \
    "$scanner" git "${common[@]}" --log-opts=--all "$target" >/dev/null 2>&1
fi
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  printf 'Secret scan passed: %s.\n' "$mode"
  exit 0
fi
if [[ "$status" -eq 1 && -s "$report" ]] && jq -e '
  type == "array" and all(.[ ];
    (.StartLine | type == "number") and
    (.StartLine >= 1) and
    (.StartLine <= 2147483647) and
    (.StartLine == (.StartLine | floor)) and
    (.RuleID | type == "string") and
    (.RuleID | test("^[a-z0-9][a-z0-9_-]{0,127}$"))
  )
' "$report" >/dev/null 2>&1; then
  printf 'Secret scan findings (%s):\n' "$mode" >&2
  # File paths are untrusted data and may themselves contain credentials or
  # terminal control characters. Public output deliberately omits them.
  jq -r '.[] | "line=\(.StartLine | floor) type=\(.RuleID)"' \
    "$report" >&2
  exit 1
fi
printf 'Secret scanner failed without a valid findings report.\n' >&2
exit 2
