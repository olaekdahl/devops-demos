#!/usr/bin/env bash
# Extracted commands from 06-github-actions-basics.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

mkdir -p .github/workflows
# (create hello.yaml above)
# git init && git branch -m main  # parent-repo op — review & run manually
# git add . && git commit -m "ci: hello workflow"  # parent-repo op — review & run manually
# Push into your devops-<initials> repo's main branch (or a separate repo)
# git remote add origin https://github.com/<account>/devops-<initials>.git  # contains <placeholder> — edit before running
# git push -u origin main  # parent-repo op — review & run manually

# --- next block ---

mkdir -p .github/workflows
# (create hello.yaml above)
# git init && git branch -m main  # parent-repo op — review & run manually
# git add . && git commit -m "ci: hello workflow"  # parent-repo op — review & run manually
# Push into your devops-<initials> repo's main branch (or a separate repo)
# git remote add origin https://github.com/<account>/devops-<initials>.git  # contains <placeholder> — edit before running
# git push -u origin main  # parent-repo op — review & run manually