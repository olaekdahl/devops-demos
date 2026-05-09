#!/usr/bin/env bash
# Extracted commands from 04-pull-requests.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

git checkout -b docs/add-readme
# edit README.md
# git add README.md && git commit -m "docs: add README"  # parent-repo op — review & run manually
# git push -u origin docs/add-readme  # parent-repo op — review & run manually

# --- next block ---

cd .            # reuse the repo from Demo 3
git switch -c docs/add-readme

cat > README.md <<'EOF'
# devops-<initials>


## Endpoints (after Demo 09)
- GET /env

# git add README.md  # parent-repo op — review & run manually
# git commit -m "docs: expand README with endpoints"  # parent-repo op — review & run manually
# git push -u origin docs/add-readme  # parent-repo op — review & run manually
EOF


# --- next block ---

git switch main
git pull
git branch -d docs/add-readme