#!/usr/bin/env bash
# Extracted commands from 24-gateway-api.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
# 1. Install Gateway API standard CRDs (v1.1.0 stable as of 2025).
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# 2. Install Envoy Gateway as a conformant implementation (lightweight).
helm install eg oci://docker.io/envoyproxy/gateway-helm \

kubectl wait --namespace envoy-gateway-system \

# --- next block ---


kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

kubectl get gatewayclass
kubectl get gateway
kubectl get httproute

# Find the gateway's externally reachable address (in Kind it's a Service of type LoadBalancer with external <pending>; use NodePort or port-forward for the demo)
kubectl -n envoy-gateway-system get svc

# Port-forward for the demo
kubectl -n envoy-gateway-system port-forward svc/envoy-default-public-http-* 8081:80 &

curl -H 'Host: devops.local' http://127.0.0.1:8081/api/health
curl -H 'Host: devops.local' http://127.0.0.1:8081/web/

# Cleanup
kubectl delete -f httproute.yaml -f gateway.yaml
helm uninstall eg -n envoy-gateway-system