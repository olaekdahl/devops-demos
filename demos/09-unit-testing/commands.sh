#!/usr/bin/env bash
# Extracted commands from 09-unit-testing.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

mkdir -p tests
cp *  2>/dev/null || true
# cp -r demos/sample-app/tests demos/09-unit-testing/  # source path stripped — sample-app is pre-copied

python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt pytest httpx pytest-cov

# Run all tests
PYTHONPATH=$(pwd) pytest -v tests/

# Run only the health test
PYTHONPATH=$(pwd) pytest -v -k health tests/

# With coverage
PYTHONPATH=$(pwd) pytest --cov=app --cov-report=term-missing tests/

# --- next block ---

sed -i 's/VERSION = "1.0.0"/VERSION = "1.0.1"/' app.py
PYTHONPATH=$(pwd) pytest -v tests/test_app.py::test_get_version