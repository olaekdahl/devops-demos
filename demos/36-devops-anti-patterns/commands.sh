#!/usr/bin/env bash
# Extracted commands from 36-devops-anti-patterns.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
ssh prod-vm-7
sudo apt-get install -y nginx
sudo vi /etc/nginx/sites-available/myapp
sudo systemctl restart nginx
# Result: nobody knows what's on prod-vm-7. Disaster on rebuild.

# --- next block ---

pip install detect-secrets
# pre-commit-config.yaml runs detect-secrets on every commit.

# --- next block ---

#!/usr/bin/env bash
# Rollback playbook — runnable in 30 seconds.
# Required for every prod service. If you can't write this, you can't deploy.

PREVIOUS=$(kubectl rollout history deploy/devops-app | tail -2 | head -1 | awk '{print $1}')
echo "Rolling back to revision $PREVIOUS"
kubectl rollout undo deploy/devops-app --to-revision="$PREVIOUS"
kubectl rollout status deploy/devops-app
echo "Smoke test:"
curl -fs http://devops-app.example.com/health || { echo "rollback failed"; exit 1; }
echo "Rollback OK"