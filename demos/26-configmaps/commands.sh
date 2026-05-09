#!/usr/bin/env bash
# Extracted commands from 26-configmaps.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

kubectl apply -f configmap.yaml -f deployment.yaml
kubectl rollout status deployment/devops-app

# Inspect injected env
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- env | grep -E 'APP_NAME|ENVIRONMENT'

# Inspect mounted file
kubectl exec $POD -- cat /etc/motd

# Hit the app's /env endpoint — values flow through to FastAPI
kubectl port-forward $POD 8000:8000 &
curl localhost:8000/env

# Update the file-style config; mounted file updates within ~60s,
# but env vars don't.
kubectl create configmap devops-app-config \
  --from-file=motd.txt=<(echo "PRODUCTION MOTD") \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl exec $POD -- cat /etc/motd                       # updated
kubectl exec $POD -- env | grep ENVIRONMENT              # still 'staging'

# To pick up env var change: bump config-hash annotation, then
sed -i 's/config-hash: "v1"/config-hash: "v2"/' deployment.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app