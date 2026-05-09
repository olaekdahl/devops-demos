#!/usr/bin/env bash
# Extracted commands from 03-github-fundamentals.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

cd .
# git init && git branch -m main  # parent-repo op — review & run manually
# echo "# devops-<initials>" > README.md  # contains <placeholder> — edit before running
# git add . && git commit -m "initial commit"  # parent-repo op — review & run manually

# Wire up the remote
# git remote add origin https://github.com/<account>/devops-<initials>.git  # contains <placeholder> — edit before running
git remote -v        # verify

# First push — will prompt for username and PAT (paste PAT as password)
# git push -u origin main  # parent-repo op — review & run manually