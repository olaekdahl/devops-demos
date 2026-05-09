#!/usr/bin/env bash
# Extracted commands from 21-kubernetes-deployments.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app

kubectl get deploy,rs,pods -l app=devops-app

# Tail logs from one pod
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD &
LOGS=$!

# Kill a pod, watch self-healing
kubectl delete pod $POD
kubectl get pods -l app=devops-app -w &
WATCH=$!

# ── Rolling update to v1.0.1 ────────────────────────────────────────
docker build -t devops-app:1.0.1 ../15-docker-build         # rebuild
kind load docker-image devops-app:1.0.1 --name devops

kubectl set image deployment/devops-app app=devops-app:1.0.1 --record
kubectl rollout status deployment/devops-app
kubectl get rs -l app=devops-app

# ── Roll back ───────────────────────────────────────────────────────
kubectl rollout history deployment/devops-app
kubectl rollout undo deployment/devops-app
kubectl rollout status deployment/devops-app

# ── Inspect events on failure (deploy a broken image) ──────────────
kubectl set image deployment/devops-app app=devops-app:does-not-exist
kubectl rollout status deployment/devops-app --timeout=30s    # times out
kubectl describe deploy devops-app | tail -20                 # see ImagePullBackOff
kubectl rollout undo deployment/devops-app

# Cleanup
kubectl delete -f deployment.yaml