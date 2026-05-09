# Demo 03 — GitHub Fundamentals

## Learning Objectives
- Create a GitHub repository and connect a local repo to it.
- Authenticate using a Personal Access Token (PAT) — and understand why PATs
  are *temporary* security tokens, not permanent passwords.
- Push and pull changes; understand `origin` and `main` tracking.

## Concepts Covered
- Remotes (`origin`)
- HTTPS auth via PAT (classic) vs SSH keys vs GitHub CLI auth
- Repo visibility (private/public/internal)
- README, default branch, branch protection (preview)

## Real-World Relevance
GitHub (or GitHub Enterprise) is the source-of-truth code host for most
companies. Every CI pipeline, every deployment, every audit log starts from a
Git remote.

## Demo Architecture
```
  Lab VM                           GitHub
  ──────                           ──────
  local repo  ─── git push ──►   origin/main
  local repo  ◄── git pull ───   origin/main
            (HTTPS + PAT auth)
```

## Instructor Notes
- Stress: a PAT *replaces your password* for git over HTTPS. Treat it like a
  credit card. Use minimum scopes (`repo`, `workflow`) and short expirations.
- Some students will paste their PAT into a chat or repo. Warn first.
- If your VM has GitHub CLI installed, `gh auth login` is friendlier — show it.

## Prerequisites
- A GitHub account.
- Git ≥ 2.40, optionally `gh` CLI ≥ 2.40.

## Folder Structure
```
demos/03-github-fundamentals/
  README.md
```

## Complete Code

`demos/03-github-fundamentals/README.md`
```markdown
# devops-<initials>

Sample DevOps Fundamentals repo.
```

## Step-by-Step Walkthrough

### 1. Create the repo on GitHub
1. https://github.com → **New** → name `devops-<initials>` → private → **Create**.
2. Copy the HTTPS URL.

### 2. Generate a PAT
- Profile → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**.
- Name: `devops-<initials>`. Expiration: 7–30 days. Scopes: `repo`, `workflow`.
- Copy and treat as a secret.

### 3. Connect local → remote
```bash
mkdir -p demos/03-github-fundamentals && cd demos/03-github-fundamentals
git init && git branch -m main
echo "# devops-<initials>" > README.md
git add . && git commit -m "initial commit"

# Wire up the remote
git remote add origin https://github.com/<account>/devops-<initials>.git
git remote -v        # verify

# First push — will prompt for username and PAT (paste PAT as password)
git push -u origin main
```

### 4. Round-trip via the GitHub UI
- On GitHub, edit `README.md` directly, commit on `main`.
- Locally:
  ```bash
  git pull
  cat README.md
  ```

## Expected Output
```
$ git push -u origin main
Enumerating objects: 3, done.
...
To https://github.com/learning-git-labs/devops-oe.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `remote: Invalid username or password` | Used account password instead of PAT | Re-enter using PAT |
| `Permission to <repo>.git denied` | Wrong account / PAT lacks `repo` scope | Regenerate PAT with `repo` |
| `fatal: refusing to merge unrelated histories` | Created README on GitHub *and* locally | `git pull --allow-unrelated-histories` then resolve |
| PAT keeps prompting | No credential helper | `git config --global credential.helper store` (lab only — never in prod) |

## DevOps Best Practices
- Prefer **OAuth or fine-grained PATs** over classic PATs.
- Always set an **expiration**.
- For CI, use **GITHUB_TOKEN** (auto-injected) rather than a PAT.
- Enable **branch protection** on `main` in real repos: required reviews, required checks.

## Production Considerations
- Use **GitHub Enterprise** + SSO + SCIM for org provisioning.
- Audit PAT usage from the org's **Audit log**.
- Replace long-lived secrets in CI with **OIDC federation** to AWS/Azure/GCP.
- Codeowners files (`.github/CODEOWNERS`) gate sensitive paths.

## Optional Advanced Enhancements
- Switch the demo to SSH: `ssh-keygen -t ed25519`, add public key to GitHub,
  use `git@github.com:...` URL.
- Show `gh repo create`, `gh pr create`, `gh issue list` from the GitHub CLI.
- Demonstrate fine-grained PAT scoped to a single repo.
