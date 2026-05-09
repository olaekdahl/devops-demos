#!/usr/bin/env bash
# Extracted commands from 27-secrets-k8s.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

kubectl apply -f secret-opaque.yaml

# (For Capstone) create an image-pull secret too
ARTIFACTORY_URL=... USER=... TOKEN=... bash pull-secret.sh

kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')

# Env var injection
kubectl exec $POD -- printenv SECRET_KEY

# File mount
kubectl exec $POD -- ls -l /etc/creds/
kubectl exec $POD -- cat /etc/creds/db.password

# Inspect the stored Secret (base64 — show the lack of encryption)
kubectl get secret app-creds -o yaml
echo c3VwZXItc2VjcmV0LWRvLW5vdC1wcmludA== | base64 -d

# --- next block ---

kubectl apply -f secret-opaque.yaml

# (For Capstone) create an image-pull secret too
ARTIFACTORY_URL=... USER=... TOKEN=... bash pull-secret.sh

kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')

# Env var injection
kubectl exec $POD -- printenv SECRET_KEY

# File mount
kubectl exec $POD -- ls -l /etc/creds/
kubectl exec $POD -- cat /etc/creds/db.password

# Inspect the stored Secret (base64 — show the lack of encryption)
kubectl get secret app-creds -o yaml
echo c3VwZXItc2VjcmV0LWRvLW5vdC1wcmludA== | base64 -d