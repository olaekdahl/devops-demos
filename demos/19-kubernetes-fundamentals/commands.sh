#!/usr/bin/env bash
# Extracted commands from 19-kubernetes-fundamentals.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# What's running?
kubectl get nodes
kubectl get pods -A                         # all namespaces — see control plane

# Where the API server lives
kubectl config view --minify

# A controller in action: create a deployment, kill a pod, watch it return.
kubectl create deployment web --image=nginx:alpine --replicas=3
kubectl get pods -l app=web
POD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD
kubectl get pods -l app=web -w              # a new pod appears within seconds

# Cleanup
kubectl delete deployment web