# Demo 36 — DevOps Anti-Patterns

## Learning Objectives
- Recognize and articulate the most common DevOps anti-patterns.
- For each, describe the *fix* and the principle it violates.

## Concepts Covered
- "Snowflake" servers
- Manual prod deploys
- Long-lived branches
- Secrets in code/repos
- Single environment ("we test in prod")
- Skipping tests on red builds
- One-pipeline-per-team monoliths
- "It works on my machine"
- Zero rollback plan
- Tribal knowledge / no runbooks

## Real-World Relevance
Most outages and security incidents trace back to one of these anti-patterns.
Pattern recognition is half the fight.

## Demo Architecture
A facilitated discussion, plus 1 quick *live demo of a bad pattern + the fix*
for each.

## Instructor Notes
- For each anti-pattern, ask the class: "Have you seen this?" Stories cement
  the lesson.
- Use a 2-column slide: **Bad** on the left, **Better** on the right.

## Prerequisites
- Demos 1–32 complete.

## Folder Structure
```
demos/36-devops-anti-patterns/
  1-snowflake-vs-iac/
    bad-setup.sh
    good-setup.tf
  2-secret-in-repo/
    .env.bad
    .env.good
  3-no-rollback/
    rollback.sh
```

## Complete Code

### Anti-pattern 1: Snowflake server
`1-snowflake-vs-iac/bad-setup.sh` — manual provisioning
```bash
#!/usr/bin/env bash
ssh prod-vm-7
sudo apt-get install -y nginx
sudo vi /etc/nginx/sites-available/myapp
sudo systemctl restart nginx
# Result: nobody knows what's on prod-vm-7. Disaster on rebuild.
```

`1-snowflake-vs-iac/good-setup.tf` — Terraform
```hcl
resource "aws_instance" "web" {
  ami                    = "ami-0abcd1234"
  instance_type          = "t3.small"
  user_data              = file("cloud-init.yaml")  # declarative bootstrap
  vpc_security_group_ids = [aws_security_group.web.id]
  tags = { Name = "web", env = "prod", managed_by = "terraform" }
}
```
Principle: **Infrastructure as Code, immutable infrastructure.**

### Anti-pattern 2: Secrets in repo
`2-secret-in-repo/.env.bad`
```env
# DO NOT EVER commit this file.
DB_PASSWORD=hunter2
STRIPE_KEY=sk_live_REAL_KEY
```
`2-secret-in-repo/.env.good`
```env
# Reference, not values. Real values come from Secrets Manager / Vault.
DB_PASSWORD=__from_secrets_manager__
STRIPE_KEY=__from_secrets_manager__
```
Plus `.gitignore`:
```
.env
*.pem
*.key
```
And add a pre-commit hook:
```bash
pip install detect-secrets
detect-secrets scan > .secrets.baseline
# pre-commit-config.yaml runs detect-secrets on every commit.
```
Principle: **Never commit secrets; rotate when they leak.**

### Anti-pattern 3: No rollback plan
`3-no-rollback/rollback.sh`
```bash
#!/usr/bin/env bash
# Rollback playbook — runnable in 30 seconds.
# Required for every prod service. If you can't write this, you can't deploy.

set -e
PREVIOUS=$(kubectl rollout history deploy/devops-app | tail -2 | head -1 | awk '{print $1}')
echo "Rolling back to revision $PREVIOUS"
kubectl rollout undo deploy/devops-app --to-revision="$PREVIOUS"
kubectl rollout status deploy/devops-app
echo "Smoke test:"
curl -fs http://devops-app.example.com/health || { echo "rollback failed"; exit 1; }
echo "Rollback OK"
```
Principle: **Every change must be reversible in minutes.**

## Step-by-Step Walkthrough
For each anti-pattern, do:
1. Show the **bad** version (10 sec).
2. Discuss: "What goes wrong?"
3. Show the **good** version.
4. Name the principle.

## Expected Output
A class consensus on the top 3 anti-patterns most present in their orgs.

## Common Anti-Patterns Cheat Sheet
| Anti-pattern | Symptom | Fix |
|---|---|---|
| Snowflake server | "Don't reboot prod-vm-7" | Terraform/Pulumi + immutable AMIs |
| Manual prod deploy | "Bob ssh's in" | CI/CD with approvals |
| Long-lived branches | Constant merge hell | Trunk-based, short branches |
| Secrets in code | git history full of keys | Vault/Secrets Manager + pre-commit scan |
| Test in prod | Customers find bugs | Real staging env + canary |
| Disable failing tests | Builds always green, prod red | Treat red CI as a stop-the-line |
| Mega monolith pipeline | 90-min CI, fear of changes | Per-service pipelines |
| Tribal knowledge | "Ask Alice" | Runbooks, ADRs, on-call rotation |
| No rollback | "We'll fix forward" | Tested rollback playbook |
| Vanity metrics | "We deploy 1000x/day" with 80% failures | DORA metrics: include change-fail rate |

## DevOps Best Practices (the inverse rules)
- Automate everything that runs more than twice.
- Treat infrastructure as code; treat code as data.
- Optimize for **lead time** + **change-fail rate** together.
- "Boring deploys" are the goal.

## Production Considerations
- Track **DORA** metrics; share them transparently.
- Run **gameday** drills (chaos engineering) to validate runbooks.
- Use **post-incident reviews** without blame.

## Optional Advanced Enhancements
- Have students bring an anti-pattern from their job; debug as a class.
- Read "The Phoenix Project" / "Accelerate" excerpts.
- Workshop: rewrite a "snowflake setup" doc into Terraform.
