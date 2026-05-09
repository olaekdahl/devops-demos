#!/usr/bin/env bash
set -e
# 1. Install Gateway API standard CRDs (v1.1.0 stable as of 2025).
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# 2. Install Envoy Gateway as a conformant implementation (lightweight).
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.1.0 -n envoy-gateway-system --create-namespace

kubectl wait --namespace envoy-gateway-system \
  --for=condition=Available deployment --all --timeout=180s
