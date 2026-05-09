# Demo 38 — Logging and Monitoring

## Learning Objectives
- Stand up a minimal logging + monitoring stack for Kubernetes.
- Tail aggregated logs with Loki.
- Build a Grafana dashboard with one panel of pod CPU and one of error rate.
- Wire a basic alert.

## Concepts Covered
- Per-node log shipping (Promtail / Fluent Bit / Vector)
- Metrics scraping (Prometheus + Node Exporter + kube-state-metrics)
- Log–metric–trace navigation in Grafana
- Alertmanager → notification (Slack / email)

## Real-World Relevance
This is the most common open-source observability stack for Kubernetes
("LGTM stack": Loki, Grafana, Tempo, Mimir/Prometheus). Cloud equivalents:
CloudWatch / Datadog / New Relic.

## Demo Architecture
```
   Pods stdout  ──► Promtail (DaemonSet) ──► Loki ──► Grafana
   Node metrics ──► node-exporter        \
   K8s state    ──► kube-state-metrics    ─► Prometheus ──► Grafana
                                                        \
                                                         ──► Alertmanager ──► Slack
```

## Instructor Notes
- Use the official `kube-prometheus-stack` Helm chart; it ships everything wired.
- Kind clusters need extra port mappings or `kubectl port-forward` to view UIs.
- Show that the FastAPI app's `/metrics` endpoint (Demo 37) is auto-scraped
  via a `ServiceMonitor`.

## Prerequisites
- Demo 21 deployment running on Kind.
- `helm` 3.13+.

## Folder Structure
```
demos/38-logging-and-monitoring/
  install.sh
  servicemonitor.yaml
  alertrule.yaml
  dashboard.json          (placeholder — built in Grafana UI)
```

## Complete Code

`install.sh`
```bash
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
```

`servicemonitor.yaml` — tell Prometheus to scrape the FastAPI app
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: devops-app
  namespace: monitoring
  labels:
    release: kps                    # required selector for kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames: [default]
  selector:
    matchLabels: { app: devops-app }
  endpoints:
    - port: http                    # service port name
      path: /metrics
      interval: 15s
```

`alertrule.yaml`
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: devops-app-alerts
  namespace: monitoring
  labels: { release: kps }
spec:
  groups:
    - name: devops-app
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{job="devops-app",status=~"5.."}[2m]))
            / sum(rate(http_requests_total{job="devops-app"}[2m])) > 0.05
          for: 2m
          labels: { severity: page }
          annotations:
            summary: ">5% 5xx errors on devops-app"
            runbook: "https://wiki/runbooks/devops-app-5xx"

        - alert: PodCrashLooping
          expr: increase(kube_pod_container_status_restarts_total{namespace="default"}[5m]) > 3
          for: 5m
          labels: { severity: page }
          annotations:
            summary: "{{ $labels.pod }} restarting frequently"
```

## Step-by-Step Walkthrough
```bash
cd demos/38-logging-and-monitoring
bash install.sh

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
```

## Expected Output
- Prometheus targets page shows `devops-app` UP.
- Grafana Explore (Loki): live tail of structured JSON log lines.
- Grafana panel: request rate by status code.
- Alertmanager UI shows `HighErrorRate` firing if you push enough errors.

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| ServiceMonitor not picked up | Wrong `release:` label | Use the chart release name (`kps`) |
| `/metrics` returns 404 | App not instrumented | Add `prometheus-fastapi-instrumentator` (Demo 37) |
| No logs in Loki | Promtail not running | `kubectl -n monitoring get pods -l app=promtail` |
| Alerts never fire | Expr returns no data | Test in Prometheus UI first |

## DevOps Best Practices
- **One stack** per cluster; don't run 5 monitoring tools.
- **SLO-based alerts** (burn-rate), not raw threshold spam.
- **Runbook URL** in every alert annotation.
- Dashboard hierarchy: org-wide → service → request flow.

## Production Considerations
- Long-term storage: Mimir/Thanos for Prometheus, S3 for Loki chunks.
- Multi-tenant isolation by namespace / org.
- Use **OpenTelemetry Collector** to fan out to multiple backends.
- Page only the on-call; everything else → Slack.

## Optional Advanced Enhancements
- Add **Tempo** for traces and the LGTM trio of `Logs → Traces → Metrics` correlation.
- Add **synthetic checks** with Grafana k6 or Blackbox Exporter.
- Route alerts via Alertmanager to **PagerDuty/OpsGenie**.
- Adopt **OpenTelemetry semantic conventions** so dashboards are reusable across services.

---

## Course Wrap-Up
Students have now built every layer of a modern DevOps stack:

```
Plan → Code (Git/GitHub)
     → Build (Docker)
     → Test (pytest, matrix)
     → Deliver (GitHub Actions, JFrog)
     → Deploy (Kubernetes, EKS)
     → Operate (Services, Ingress, scaling)
     → Observe (Prometheus, Loki, Grafana)
     → Improve (DORA metrics, anti-pattern recognition)
```

Encourage them to take the sample app, fork the demos, and apply the patterns
to a project from their own work.
