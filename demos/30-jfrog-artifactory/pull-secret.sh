#!/usr/bin/env bash
set -euo pipefail

# Lab values supplied by your instructor:
ARTIFACTORY_URL=${ARTIFACTORY_URL:-mycompany.jfrog.io}
ARTIFACTORY_USER=${ARTIFACTORY_USER:?missing}
ARTIFACTORY_TOKEN=${ARTIFACTORY_TOKEN:?missing}

kubectl create secret docker-registry jfrog-pull-secret \
  --docker-server="$ARTIFACTORY_URL" \
  --docker-username="$ARTIFACTORY_USER" \
  --docker-password="$ARTIFACTORY_TOKEN" \
  --docker-email="lab@example.com" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated K8s secret jfrog-pull-secret"
