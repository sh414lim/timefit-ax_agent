#!/usr/bin/env bash

set -euo pipefail

version="8.30.1"
destination="${1:?destination directory required}"
os="$(uname -s)"
architecture="$(uname -m)"

case "$os/$architecture" in
  Linux/x86_64)
    archive="gitleaks_${version}_linux_x64.tar.gz"
    expected="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
    ;;
  Darwin/arm64)
    archive="gitleaks_${version}_darwin_arm64.tar.gz"
    expected="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"
    ;;
  *)
    printf 'Unsupported Gitleaks platform: %s/%s\n' "$os" "$architecture" >&2
    exit 2
    ;;
esac

mkdir -p "$destination"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/${archive}"
curl --fail --silent --show-error --location "$url" --output "$temporary/$archive"
actual="$(env LC_ALL=C LANG=C shasum -a 256 "$temporary/$archive" | cut -d ' ' -f 1)"
if [[ "$actual" != "$expected" ]]; then
  printf 'Gitleaks archive checksum mismatch.\n' >&2
  exit 2
fi
tar -xzf "$temporary/$archive" -C "$temporary" gitleaks
install -m 0755 "$temporary/gitleaks" "$destination/gitleaks"
"$destination/gitleaks" version | grep -Fxq "$version"
