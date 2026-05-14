#!/usr/bin/env bash
# A *manual* DevOps loop in 30 lines of Bash. We will replace each step with
# real tools used across the rest of the demo set: git, GitHub Actions, Docker, K8s.
set -euo pipefail

PHASE() { echo -e "\n=== $1 ==="; }

PHASE "PLAN";        echo "Goal: ship a tiny service that prints a heartbeat."
PHASE "CODE";        cat app.py
PHASE "BUILD";       python3 -m py_compile app.py && echo "syntax OK"
PHASE "TEST";        grep -q heartbeat app.py && echo "smoke test passed"
PHASE "RELEASE";     export APP_VERSION="1.0.$(date +%s)"
                     echo "tagged release: $APP_VERSION"
PHASE "DEPLOY";      python3 app.py &
                     APP_PID=$!
                     sleep 5
PHASE "OPERATE";     echo "PID=$APP_PID running"
PHASE "MONITOR";     echo "--- last 3 log lines ---"
                     # In real life this is Datadog / CloudWatch / Loki.
                     # Here we just read stdout we redirected.
                     kill $APP_PID
PHASE "FEEDBACK";    echo "If heartbeat missing -> open ticket, plan fix, loop."
