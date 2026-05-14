# Demo 38 — Logging and Monitoring

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
bash install.sh

# Make the FastAPI Service have a named port
kubectl patch svc devops-app-svc -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":8000}]}}'

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

## Prerequisites

- Demo 21 deployment running on Kind.
- `helm` 3.13+.

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

## Architecture

```
   Pods stdout  ──► Promtail (DaemonSet) ──► Loki ──► Grafana
   Node metrics ──► node-exporter        \
   K8s state    ──► kube-state-metrics    ─► Prometheus ──► Grafana
                                                        \
                                                         ──► Alertmanager ──► Slack
```

## Expected Output

- Prometheus targets page shows `devops-app` UP.
- Grafana Explore (Loki): live tail of structured JSON log lines.
- Grafana panel: request rate by status code.
- Alertmanager UI shows `HighErrorRate` firing if you push enough errors.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| ServiceMonitor not picked up | Wrong `release:` label | Use the chart release name (`kps`) |
| `/metrics` returns 404 | App not instrumented | Add `prometheus-fastapi-instrumentator` (Demo 37) |
| No logs in Loki | Promtail not running | `kubectl -n monitoring get pods -l app=promtail` |
| Alerts never fire | Expr returns no data | Test in Prometheus UI first |

## Best Practices

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


## Real-World Relevance

This is the most common open-source observability stack for Kubernetes
("LGTM stack": Loki, Grafana, Tempo, Mimir/Prometheus). Cloud equivalents:
CloudWatch / Datadog / New Relic.
