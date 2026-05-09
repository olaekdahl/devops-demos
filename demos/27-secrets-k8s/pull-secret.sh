#!/usr/bin/env bash
set -e
ARTIFACTORY_URL=${ARTIFACTORY_URL:?set me}
USER=${USER:?set me}
TOKEN=${TOKEN:?set me}

kubectl create secret docker-registry jfrog-pull-secret \
  --docker-server="$ARTIFACTORY_URL" \
  --docker-username="$USER" \
  --docker-password="$TOKEN" \
  --docker-email="lab@example.com" \
  --dry-run=client -o yaml | kubectl apply -f -
