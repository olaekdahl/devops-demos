#!/usr/bin/env bash
# Generate an SPDX SBOM locally for an image (or for source).
set -euo pipefail
TARGET="${1:?usage: generate-sbom.sh <image|dir>}"
OUT="${2:-sbom.spdx.json}"

if ! command -v syft >/dev/null; then
  echo "Installing syft..."
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b /usr/local/bin
fi

syft "$TARGET" -o spdx-json > "$OUT"
echo "SBOM written to $OUT ($(jq '.packages | length' "$OUT") packages)"
