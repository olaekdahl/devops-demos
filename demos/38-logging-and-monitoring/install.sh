#!/usr/bin/env bash
set -e

# 1. kube-prometheus-stack: Prometheus, Alertmanager, Grafana, exporters, CRDs
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30030

# 2. Loki + Promtail (logs)
helm upgrade --install loki grafana/loki-stack \
  -n monitoring \
  --set promtail.enabled=true \
  --set grafana.enabled=false

echo "Wait for pods..."
kubectl -n monitoring rollout status deploy/kps-grafana
echo "Grafana: http://localhost:30030  (admin / admin)"
