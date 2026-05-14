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
