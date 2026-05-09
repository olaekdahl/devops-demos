#!/usr/bin/env bash
# Extracted commands from 01-devops-fundamentals.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
# A *manual* DevOps loop in 30 lines of Bash. We will replace each step with
# real tools across the rest of the course: git, GitHub Actions, Docker, K8s.

PHASE() { echo -e "\n=== $1 ==="; }

PHASE "PLAN";        echo "Goal: ship a tiny service that prints a heartbeat."
PHASE "CODE";        cat app.py
PHASE "BUILD";       python3 -m py_compile app.py && echo "syntax OK"
PHASE "TEST";        grep -q heartbeat app.py && echo "smoke test passed"
PHASE "RELEASE";     export APP_VERSION="1.0.$(date +%s)"
                     echo "tagged release: $APP_VERSION"
PHASE "DEPLOY";      python3 app.py &
                     APP_PID=$!
PHASE "OPERATE";     echo "PID=$APP_PID running"
PHASE "MONITOR";     echo "--- last 3 log lines ---"
                     # In real life this is Datadog / CloudWatch / Loki.
                     # Here we just read stdout we redirected.
PHASE "FEEDBACK";    echo "If heartbeat missing -> open ticket, plan fix, loop."

# --- next block ---

chmod +x loop.sh