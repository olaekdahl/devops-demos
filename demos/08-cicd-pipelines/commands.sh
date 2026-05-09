#!/usr/bin/env bash
# Extracted commands from 08-cicd-pipelines.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

mkdir -p tests .github/workflows
# cp demos/sample-app/app.py demos/08-cicd-pipelines/  # source path stripped — sample-app is pre-copied
# cp demos/sample-app/requirements.txt demos/08-cicd-pipelines/  # source path stripped — sample-app is pre-copied
cp tests/test_app.py tests/
# create the workflow file above
# git add demos/08-cicd-pipelines  # parent-repo op — review & run manually
# git commit -m "ci: add full pipeline"  # parent-repo op — review & run manually
# git push  # parent-repo op — review & run manually

# --- next block ---

mkdir -p tests .github/workflows
# cp demos/sample-app/app.py demos/08-cicd-pipelines/  # source path stripped — sample-app is pre-copied
# cp demos/sample-app/requirements.txt demos/08-cicd-pipelines/  # source path stripped — sample-app is pre-copied
cp tests/test_app.py tests/
# create the workflow file above
# git add demos/08-cicd-pipelines  # parent-repo op — review & run manually
# git commit -m "ci: add full pipeline"  # parent-repo op — review & run manually
# git push  # parent-repo op — review & run manually