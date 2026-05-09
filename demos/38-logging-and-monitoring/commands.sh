#!/usr/bin/env bash
# Extracted commands from 38-logging-and-monitoring.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail


# Make the FastAPI Service have a named port
kubectl patch svc devops-app-svc -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":8000}]}}'
# (Or update Demo 22 service-clusterip.yaml to name it 'http' originally.)

kubectl apply -f servicemonitor.yaml
kubectl apply -f alertrule.yaml

# UI access
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
kubectl -n monitoring port-forward svc/loki 3100:3100 &

# Generate traffic
for i in $(seq 1 200); do curl -s http://devops.local:8080/api/health > /dev/null; done
# Generate errors:
for i in $(seq 1 50); do curl -s http://devops.local:8080/api/this-does-not-exist > /dev/null; done

# Grafana → Explore (Loki):  {namespace="default", app="devops-app"} | json
# Grafana → Explore (Prom):  rate(http_requests_total{job="devops-app"}[1m])
# Alerting → confirm HighErrorRate appears (after 2 min of 5%+)

# --- next block ---


# Make the FastAPI Service have a named port
kubectl patch svc devops-app-svc -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":8000}]}}'
# (Or update Demo 22 service-clusterip.yaml to name it 'http' originally.)

kubectl apply -f servicemonitor.yaml
kubectl apply -f alertrule.yaml

# UI access
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
kubectl -n monitoring port-forward svc/loki 3100:3100 &

# Generate traffic
for i in $(seq 1 200); do curl -s http://devops.local:8080/api/health > /dev/null; done
# Generate errors:
for i in $(seq 1 50); do curl -s http://devops.local:8080/api/this-does-not-exist > /dev/null; done

# Grafana → Explore (Loki):  {namespace="default", app="devops-app"} | json
# Grafana → Explore (Prom):  rate(http_requests_total{job="devops-app"}[1m])
# Alerting → confirm HighErrorRate appears (after 2 min of 5%+)