#!/usr/bin/env bash
# Rollback playbook — runnable in 30 seconds.
# Required for every prod service. If you can't write this, you can't deploy.

set -e
PREVIOUS=$(kubectl rollout history deploy/devops-app | tail -2 | head -1 | awk '{print $1}')
echo "Rolling back to revision $PREVIOUS"
kubectl rollout undo deploy/devops-app --to-revision="$PREVIOUS"
kubectl rollout status deploy/devops-app
echo "Smoke test:"
curl -fs http://devops-app.example.com/health || { echo "rollback failed"; exit 1; }
echo "Rollback OK"
