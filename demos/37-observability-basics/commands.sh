#!/usr/bin/env bash
# Extracted commands from 37-observability-basics.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

docker compose up -d --build

# Generate traffic
for i in $(seq 1 50); do curl -s localhost:8000/work > /dev/null; done

# Logs (structured)
docker compose logs app | tail
# {"event":"http_request","level":"info","method":"GET","path":"/work","status":200,"duration_ms":214,...}

# Metrics
curl -s localhost:8000/metrics | grep http_requests_total | head

# Prometheus UI

# Grafana UI (anonymous admin)

# Traces in Jaeger
open http://localhost:16686    # service: 'unknown_service:python' or your OTEL_SERVICE_NAME