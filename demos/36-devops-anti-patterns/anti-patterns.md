# DevOps Anti-Patterns — Reference Card

The three folders alongside this file each pair a `bad-*` example with a `good-*` fix. Walk them in order.

---

## 1. Snowflake server (manual provisioning)
- **Bad:** [`1-snowflake-vs-iac/bad-setup.sh`](1-snowflake-vs-iac/bad-setup.sh) — SSH in, `apt-get install`, hand-edit nginx config. Nobody knows what is on `prod-vm-7`. Disaster on rebuild.
- **Good:** [`1-snowflake-vs-iac/good-setup.tf`](1-snowflake-vs-iac/good-setup.tf) — Terraform resource, declarative bootstrap.
- **Principle:** Infrastructure as Code, immutable infrastructure.

## 2. Secrets in repo
- **Bad:** [`2-secret-in-repo/.env.bad`](2-secret-in-repo/.env.bad) — real password and live Stripe key committed.
- **Good:** [`2-secret-in-repo/.env.good`](2-secret-in-repo/.env.good) — reference markers; values come from Secrets Manager / Vault. Plus `.gitignore` covering `.env`, `*.pem`, `*.key`, and a `detect-secrets` pre-commit hook.
- **Principle:** Never commit secrets; rotate when they leak.

## 3. No rollback plan
- **Bad:** no script, no documented procedure, no muscle memory.
- **Good:** [`3-no-rollback/rollback.sh`](3-no-rollback/rollback.sh) — 30-second runnable playbook. If you cannot write this, you cannot deploy.
- **Principle:** Every change must be reversible in minutes.

---

## Other anti-patterns to discuss (no code, whiteboard only)

- Manual prod deploys (someone with sudo + ssh).
- Long-lived branches (>1 week) → painful merges, drift.
- Single environment ("we test in prod").
- Skipping tests on red builds (`pytest || true`).
- One-pipeline-per-team monolith with no shared steps.
- "It works on my machine" → no Docker, no devcontainer.
- Zero observability (no metrics, no logs, no traces).
