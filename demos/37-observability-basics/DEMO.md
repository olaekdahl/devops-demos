# Demo 37 — Observability Basics

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

## Quick Start
Run the demo end-to-end:

```bash
cd demos/37-observability-basics
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

## Real-World Relevance
Modern distributed systems can't be debugged with logs alone. Observability is
the difference between "the system is down" and "request 7c3f failed at the
payments service due to a 2-second DB stall."

## Demo Architecture
```
   FastAPI app
   ├── /metrics    (Prometheus exposition)         ◄ scraped by Prometheus
   ├── stdout logs (structured JSON)               ◄ tailed by Loki / CloudWatch
   └── OTLP traces (OpenTelemetry)                 ◄ sent to Jaeger / Tempo
```

## Instructor Notes
- Many students think observability == logs. Spend time on the three-pillars
  framing.
- Show a metric, a structured log, and a trace span on the same request to
  drive the point home.

## Prerequisites
- Sample app from `demos/sample-app/`.
- `docker compose` for the local stack.

## Folder Structure
```
demos/37-observability-basics/
  app.py
  requirements.txt
  Dockerfile
  compose.yaml
  prometheus.yml
```

## Complete Code

`requirements.txt`
```
fastapi
uvicorn
prometheus-fastapi-instrumentator
opentelemetry-api
opentelemetry-sdk
opentelemetry-instrumentation-fastapi
opentelemetry-exporter-otlp-proto-http
structlog
```

`app.py` — instrumented version
```python
import logging, os, sys, time, random
import structlog
from fastapi import FastAPI, Request
from prometheus_fastapi_instrumentator import Instrumentator
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# ── 1. Structured logging (one JSON object per line) ───────────────
logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(message)s")
structlog.configure(processors=[
    structlog.processors.add_log_level,
    structlog.processors.TimeStamper(fmt="iso"),
    structlog.processors.JSONRenderer(),
])
log = structlog.get_logger()

# ── 2. Tracing via OpenTelemetry → OTLP HTTP ───────────────────────
provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318") + "/v1/traces"
)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

# ── 3. Metrics — exposes /metrics for Prometheus ──────────────────
Instrumentator().instrument(app).expose(app)


@app.middleware("http")
async def access_log(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    log.info(
        "http_request",
        method=request.method,
        path=request.url.path,
        status=response.status_code,
        duration_ms=int((time.time() - start) * 1000),
    )
    return response


@app.get("/health")
def health():
    return {"status": "OK"}


@app.get("/work")
def work():
    # custom span
    with tracer.start_as_current_span("expensive-work"):
        time.sleep(random.uniform(0.05, 0.4))
    return {"ok": True}
```

`Dockerfile`
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`prometheus.yml`
```yaml
global: { scrape_interval: 5s }
scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app:8000']
```

`compose.yaml`
```yaml
services:
  app:
    build: .
    ports: ["8000:8000"]
    environment:
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
    depends_on: [otel-collector]

  prometheus:
    image: prom/prometheus:latest
    volumes: [./prometheus.yml:/etc/prometheus/prometheus.yml]
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: "Admin"
    ports: ["3000:3000"]

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel.yaml"]
    volumes:
      - ./otel.yaml:/etc/otel.yaml
    ports: ["4318:4318"]

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports: ["16686:16686", "4317:4317"]
```

`otel.yaml` (collector)
```yaml
receivers:
  otlp: { protocols: { http: {}, grpc: {} } }
exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls: { insecure: true }
service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlp/jaeger]
```

## Step-by-Step Walkthrough
```bash
cd demos/37-observability-basics
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

## Expected Output
- `Prometheus` shows `http_requests_total{path="/work",status="200"}` rising.
- `Grafana` graph of request rate per path.
- `Jaeger` shows trace `GET /work` with child span `expensive-work`.

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `/metrics` 404 | Forgot `Instrumentator().expose(app)` | Add it |
| No traces in Jaeger | OTLP endpoint wrong | `OTEL_EXPORTER_OTLP_ENDPOINT` should target the collector |
| Logs not JSON | structlog not configured | Re-init structlog before first log call |
| High cardinality alerts | Labels include user IDs | Use bounded labels; aggregate before storing |

## DevOps Best Practices
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
