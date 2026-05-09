#!/usr/bin/env bash
# Extracted commands from 20-kind-local-clusters.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# 1. Single-node cluster (matches lab 4.2)
kind create cluster
kubectl get nodes

# 2. Multi-node cluster
kind delete cluster
kind create cluster --config kind-multi-node.yaml
kubectl get nodes -o wide

# 3. Verify the "nodes are Docker containers" claim
docker ps --format 'table {{.Names}}\t{{.Image}}' | grep devops

# 4. Build the FastAPI image and load it
cp ../sample-app/* . && cp ../15-docker-build/Dockerfile .
docker build -t devops-app:1.0.0 .
kind load docker-image devops-app:1.0.0 --name devops

# 5. Confirm image is on every node
for n in $(kind get nodes --name devops); do
  echo "==== $n ===="
  docker exec "$n" crictl images | grep devops-app

# 6. Switching contexts
kubectl config get-contexts
kubectl config use-context kind-devops

# 7. Cleanup
kind delete cluster --name devops
done