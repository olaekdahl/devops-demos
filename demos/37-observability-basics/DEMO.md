# Demo 37 — Observability Basics

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
docker compose up -d --build

# Generate traffic
for i in $(seq 1 50); do curl -s localhost:8000/work > /dev/null; done

# Logs (structured)
docker compose logs app | tail
# {"event":"http_request","level":"info","method":"GET","path":"/work","status":200,"duration_ms":214,...}

# Metrics
curl -s localhost:8000/metrics | grep http_requests_total | head

# Prometheus UI
open http://localhost:9090     # query: rate(http_requests_total[1m])

# Grafana UI (anonymous admin)
open http://localhost:3000     # add Prometheus DS http://prometheus:9090; build a graph

# Traces in Jaeger
open http://localhost:16686    # service: 'unknown_service:python' or your OTEL_SERVICE_NAME
```

## Prerequisites

- Sample app from `demos/sample-app/`.
- `docker compose` for the local stack.

## Learning Objectives

- Distinguish **monitoring** from **observability**.
- Explain the three pillars: **logs, metrics, traces** (and their evolution).
- Add minimal observability to the FastAPI app and view it.

## Concepts Covered

- Logs: discrete events
- Metrics: aggregated time-series
- Traces: request paths across services
- OpenTelemetry as the unifying standard
- SLI/SLO/SLA mental model

## Architecture

```
   FastAPI app
   ├── /metrics    (Prometheus exposition)         ◄ scraped by Prometheus
   ├── stdout logs (structured JSON)               ◄ tailed by Loki / CloudWatch
   └── OTLP traces (OpenTelemetry)                 ◄ sent to Jaeger / Tempo
```

## Expected Output

- `Prometheus` shows `http_requests_total{path="/work",status="200"}` rising.
- `Grafana` graph of request rate per path.
- `Jaeger` shows trace `GET /work` with child span `expensive-work`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/metrics` 404 | Forgot `Instrumentator().expose(app)` | Add it |
| No traces in Jaeger | OTLP endpoint wrong | `OTEL_EXPORTER_OTLP_ENDPOINT` should target the collector |
| Logs not JSON | structlog not configured | Re-init structlog before first log call |
| High cardinality alerts | Labels include user IDs | Use bounded labels; aggregate before storing |

## Best Practices

- **Structured** logs (JSON), one event per line.
- **RED metrics**: Rate, Errors, Duration per endpoint.
- **USE metrics** for resources: Utilization, Saturation, Errors.
- Trace **every** request; sample at the collector if volume is high.
- Define **SLOs** before adding alerts.

## Production Considerations

- Centralize via OpenTelemetry Collector — swap backends (Jaeger → Tempo,
  Prometheus → Mimir, Loki → CloudWatch) without changing apps.
- Use **exemplars** to link metrics → traces.
- Keep cardinality under control; cost grows with unique label combos.
- Alert on **SLO burn rate**, not raw thresholds.

## Optional Advanced Enhancements

- Add **logs → traces correlation** via trace IDs in log records.
- Auto-instrument with `opentelemetry-instrument` (no code changes).
- Capture **profiles** with Pyroscope / Parca.

## Instructor Notes

- Many students think observability == logs. Spend time on the three-pillars
  framing.
- Show a metric, a structured log, and a trace span on the same request to
  drive the point home.

## Real-World Relevance

Modern distributed systems can't be debugged with logs alone. Observability is
the difference between "the system is down" and "request 7c3f failed at the
payments service due to a 2-second DB stall."
