# Demo 13 — Secrets Management

## Learning Objectives
- Store and use secrets in GitHub Actions.
- Differentiate repo, environment, and organization secrets.
- Avoid logging secrets accidentally.
- Prefer **OIDC** to AWS over long-lived access keys.

## Concepts Covered
- `${{ secrets.NAME }}` syntax
- Auto-masking in logs
- GitHub Environments and required reviewers
- AWS access keys (Lab pattern) vs OIDC (best practice)

## Real-World Relevance
Hardcoded secrets in code are the #1 cause of cloud breaches. Modern CI uses
short-lived federated credentials (OIDC) to assume IAM roles without storing
keys at all.

## Demo Architecture
```
    GitHub Actions Runner
    ─────────────────────
       │  read secret AWS_ACCESS_KEY (lab)            ╲
       │  ── or ──                                      ► AWS API
       │  exchange OIDC JWT for IAM role (prod)       ╱
```

## Instructor Notes
- The lab uses long-lived AWS access keys (chapter 2.8) because IAM is locked
  down for the class. Show **both** approaches; explain the lab approach is
  acceptable for a controlled lab but **not** for production.
- Demo masking: `echo "${{ secrets.X }}"` prints `***`. Show this live.
- Warn about **printenv | grep PASS** style mistakes — masking won't help if you
  base64-encode and print.

## Prerequisites
- A GitHub repo with admin access (to add secrets).
- (For OIDC section) AWS account, IAM role, OIDC provider configured.

## Folder Structure
```
demos/13-secrets-management/
  .github/workflows/
    secrets-basic.yaml
    secrets-oidc.yaml
```

## Complete Code

### Approach A — Long-lived access keys (matches lab 2.8–2.10)

In **GitHub → Settings → Secrets and variables → Actions** add:
- `AWS_ACCESS_KEY` = `AKIA…`
- `AWS_SECRET_KEY` = `…`
- `MY_API_TOKEN` = `super-secret-string`

`.github/workflows/secrets-basic.yaml`
```yaml
name: Secrets — basic
on: [workflow_dispatch]

jobs:
  use-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Demonstrate masking
        # GitHub auto-masks any secret value found in logs.
        run: echo "Token is ${{ secrets.MY_API_TOKEN }}"
        # ► output: "Token is ***"

      - name: NEVER do this  (decoded form bypasses masking)
        run: |
          # The following is intentionally bad to teach the failure mode:
          # echo "${{ secrets.MY_API_TOKEN }}" | base64
          # The base64 is NOT in the masking dictionary — it would leak.
          echo "(skipped — illustrative only)"

      - name: Configure AWS CLI from secrets
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY }}
          aws-region:            us-west-2

      - name: Verify caller identity
        run: aws sts get-caller-identity
```

### Approach B — OIDC federation to AWS (best practice)

One-time AWS setup (run on a workstation, not in a workflow):
```bash
# 1. Create OIDC provider for GitHub
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create role with trust policy bound to your repo
cat > trust.json <<EOF
{ "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": { "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:<account>/<repo>:ref:refs/heads/main"
    }}
  }]}
EOF
aws iam create-role --role-name gha-deploy --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name gha-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

`.github/workflows/secrets-oidc.yaml`
```yaml
name: Secrets — OIDC (no long-lived keys)
on: [workflow_dispatch]

permissions:
  id-token: write       # required to mint the OIDC JWT
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/gha-deploy
          aws-region:     us-west-2
      - run: aws sts get-caller-identity
      - run: aws s3 ls
```

## Step-by-Step Walkthrough
1. Add `MY_API_TOKEN` repo secret.
2. Run `secrets-basic.yaml`. In logs, look for `***` masking.
3. Try to print the secret in a different encoding — show that masking *only*
   protects the literal value.
4. Run `secrets-oidc.yaml`. No keys stored; the JWT is exchanged at runtime.
5. (If admin) Show **environment-scoped secrets** for `prod` env.

## Expected Output
Approach A:
```
Token is ***
{
  "UserId": "AIDAEXAMPLE",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/github-actions"
}
```
Approach B:
```
{
  "UserId": "AROA...:GitHubActions",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/gha-deploy/GitHubActions"
}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Secret value visible in log | Base64/JSON-encoded — masking missed it | Don't transform secrets in shell; use them in-process |
| `Could not assume role with OIDC` | `sub:` claim mismatch | Match `sub` to actual ref/env exactly |
| `Missing required field id-token` | Forgot `permissions: id-token: write` | Add it |
| Secrets unavailable in fork PR | By design (forks can't read secrets) | Use `pull_request_target` carefully or run protected jobs only on `main` |

## DevOps Best Practices
- **Never commit secrets.** Use `git-secrets`/`gitleaks` pre-commit hooks.
- Prefer **OIDC** to long-lived keys.
- Use **GitHub Environments** to scope prod secrets and require approvals.
- **Rotate** keys regularly; set short PAT/secret lifetimes.

## Production Considerations
- Centralize secrets in **AWS Secrets Manager**, **HashiCorp Vault**, or **Azure Key Vault** and pull at runtime.
- Audit secret access through CloudTrail / Vault audit log.
- Separate dev/staging/prod accounts; OIDC trust on `ref:refs/heads/main` for prod, on `pull_request` only for dev.
- Use **pinned actions by SHA** for any step that touches secrets.

## Optional Advanced Enhancements
- Use **organization-level secrets** shared across repos.
- Demo Vault dynamic secrets — generate fresh DB creds per run.
- Show how to rotate a leaked PAT in 60 seconds (revoke → regenerate → update secret).
