# Demo 13 — Secrets Management

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
git add .github/workflows/ && git commit -m "ci: secrets demo" && git push
```

## Prerequisites

- A GitHub repo with admin access (to add secrets).
- (For OIDC section) AWS account, IAM role, OIDC provider configured.

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

## Architecture

```
    GitHub Actions Runner
    ─────────────────────
       │  read secret AWS_ACCESS_KEY (lab)            ╲
       │  ── or ──                                      ► AWS API
       │  exchange OIDC JWT for IAM role (prod)       ╱
```

## Walkthrough

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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Secret value visible in log | Base64/JSON-encoded — masking missed it | Don't transform secrets in shell; use them in-process |
| `Could not assume role with OIDC` | `sub:` claim mismatch | Match `sub` to actual ref/env exactly |
| `Missing required field id-token` | Forgot `permissions: id-token: write` | Add it |
| Secrets unavailable in fork PR | By design (forks can't read secrets) | Use `pull_request_target` carefully or run protected jobs only on `main` |

## Best Practices

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

## Instructor Notes

- The lab uses long-lived AWS access keys (chapter 2.8) because IAM is locked
  down for the class. Show **both** approaches; explain the lab approach is
  acceptable for a controlled lab but **not** for production.
- Demo masking: `echo "${{ secrets.X }}"` prints `***`. Show this live.
- Warn about **printenv | grep PASS** style mistakes — masking won't help if you
  base64-encode and print.

## Real-World Relevance

Hardcoded secrets in code are the #1 cause of cloud breaches. Modern CI uses
short-lived federated credentials (OIDC) to assume IAM roles without storing
keys at all.
