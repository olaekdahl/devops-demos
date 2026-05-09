#!/usr/bin/env bash
# Extracted commands from 25-scaling-workloads.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
# Kind/self-signed kubelet certs require --kubelet-insecure-tls in dev.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
kubectl -n kube-system rollout status deploy metrics-server

# --- next block ---


# 1. Metrics server (needed for HPA)
kubectl top nodes
kubectl top pods

# 2. Manual scale first
kubectl scale deployment devops-app --replicas=2
kubectl get pods -l app=devops-app

# 3. Apply HPA
kubectl apply -f hpa.yaml
kubectl get hpa

# 4. Hammer the service
kubectl apply -f loadgen.yaml

# 5. Watch HPA scale up
kubectl get hpa -w &
WATCH=$!

# 6. After load stops, watch scale-down ~ 1 minute later
kubectl get hpa -w

# Cleanup
kubectl delete -f hpa.yaml -f loadgen.yaml