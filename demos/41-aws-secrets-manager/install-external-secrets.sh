#!/usr/bin/env bash
# Install External Secrets Operator (ESO) via Helm. Idempotent.
set -euo pipefail

ESO_NAMESPACE=${ESO_NAMESPACE:-external-secrets}
ESO_SERVICE_ACCOUNT=${ESO_SERVICE_ACCOUNT:-external-secrets-sa}

helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo update >/dev/null

# Reuse the IRSA service account created by setup-aws-secret.sh so the
# operator pod can read the AWS Secrets Manager secret.
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n "$ESO_NAMESPACE" --create-namespace \
  --set installCRDs=true \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$ESO_SERVICE_ACCOUNT"

kubectl -n "$ESO_NAMESPACE" rollout status deploy/external-secrets
echo "External Secrets Operator is ready."
