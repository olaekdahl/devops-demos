#!/usr/bin/env bash
# Consumer-side verification. Run this on a client laptop or in a deploy pipeline
# BEFORE pulling/running any image from us.
set -euo pipefail

IMAGE="${1:?usage: verify-release.sh ghcr.io/firm/app@sha256:...}"
REPO="${IMAGE%@*}"
EXPECTED_REPO_REGEX="${EXPECTED_REPO_REGEX:-^https://github\.com/firm/}"

echo "==> 1/4 Verify Cosign keyless signature"
cosign verify "$IMAGE" \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com | jq .

echo "==> 2/4 Verify SBOM attestation exists and is SPDX"
cosign verify-attestation "$IMAGE" \
  --type spdxjson \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload' | base64 -d | jq '.predicate.name'

echo "==> 3/4 Verify SLSA build provenance (level 3)"
cosign verify-attestation "$IMAGE" \
  --type slsaprovenance1 \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload' | base64 -d | jq '.predicate.buildDefinition.buildType'

echo "==> 4/4 Optional: scan for new CVEs since release"
trivy image --severity HIGH,CRITICAL --exit-code 0 "$IMAGE"

echo "✅ Image $IMAGE is verified."
