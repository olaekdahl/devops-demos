#!/usr/bin/env bash
# Extracted commands from 35-troubleshooting-kubernetes.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

kubectl create namespace broken
kubectl -n broken apply -f broken/

# Status overview
kubectl -n broken get pods,svc

# ── 01 ImagePullBackOff ──
kubectl -n broken describe pod -l app=ipb | tail -20
# Events: "Failed to pull image" + "ErrImagePull"
# Fix: kubectl set image deploy/ipb c=nginx:alpine

# ── 02 CrashLoopBackOff ──
kubectl -n broken logs crash --previous
# Output: "starting" then exit 9
# Fix: change command to a long-running process

# ── 03 OOMKilled ──
kubectl -n broken get pod oom
kubectl -n broken describe pod oom | grep -A3 Last
# State: Terminated  Reason: OOMKilled  Exit Code: 137
# Fix: bump limits.memory to 256Mi

# ── 04 Pending ──
kubectl -n broken describe pod pending | tail -10
# Events: "0/N nodes are available: <N> node(s) didn't match Pod's node affinity/selector"
# Fix: remove the bad nodeSelector

# ── 05 No Endpoints ──
kubectl -n broken get endpoints backend-svc
# ENDPOINTS: <none>
kubectl -n broken get pods --show-labels -l app=BACKEND
# Pods labeled BACKEND, Service selecting backend → mismatch.
# Fix: align case in deployment.spec.template.metadata.labels

# Cleanup
kubectl delete namespace broken

# --- next block ---

# Add a busybox sidecar to a running pod for tcpdump/curl/dig
# kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container-name>  # contains <placeholder> — edit before running

# --- next block ---

kubectl get events -A --sort-by=.lastTimestamp | tail