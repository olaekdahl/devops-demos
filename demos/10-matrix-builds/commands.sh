#!/usr/bin/env bash
# Extracted commands from 10-matrix-builds.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

mkdir -p tests .github/workflows
cp app.py requirements.txt 
cp tests/test_app.py tests/
# Add matrix.yaml above
# git add . && git commit -m "ci: matrix build" && git push  # parent-repo op — review & run manually