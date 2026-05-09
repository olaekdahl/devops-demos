#!/usr/bin/env bash
# Extracted commands from 05-github-issues.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# git add .github/ISSUE_TEMPLATE/ && git commit -m "chore: issue templates" && git push  # parent-repo op — review & run manually

# --- next block ---

git switch -c docs/usage-instructions

cat >> README.md <<'EOF'

## Running the Application
# git clone https://github.com/<account>/devops-<initials>.git  # contains <placeholder> — edit before running
# cd devops-<initials>  # contains <placeholder> — edit before running
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000
EOF