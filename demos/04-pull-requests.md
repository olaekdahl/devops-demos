# Demo 04 — Pull Requests

## Learning Objectives
- Use a feature branch + pull request as the unit of code change.
- Read a PR diff, leave a review comment, and merge.
- Understand merge strategies: merge commit, squash, rebase.

## Concepts Covered
- Branch → PR → review → merge → delete branch
- Required reviews, required status checks (preview — fully covered in Demo 33)
- Why direct pushes to `main` are an anti-pattern in shared repos

## Quick Start
This demo runs in the **GitHub UI**, not on the command line. From your fork:

```bash
cd demos/04-pull-requests
git checkout -b docs/add-readme
# edit README.md
git add README.md && git commit -m "docs: add README"
git push -u origin docs/add-readme
```

Then open GitHub → **Compare & pull request** → fill in template → request review → **Squash and merge**.

## Real-World Relevance
PRs are the single most common collaboration artifact in modern engineering
orgs. They are also the place where CI status, security scans, and compliance
approvals converge.

## Demo Architecture
```
  feature/readme branch              main branch
  ──────────────────                ───────────
        │   commits                       │
        └──── PR ────► review/CI ────► merge
                                          │
                                       deploy
```

## Instructor Notes
- Use a branch name that describes the change: `docs/add-readme`, not `dev`.
- After merge, **delete the branch** — students often leave hundreds of stale
  branches around. Show "automatically delete head branches" repo setting.
- If branch protection is on, intentionally try to push directly to `main` to
  show the rejection message.

## Prerequisites
- Demo 03 complete (`devops-<initials>` repo on GitHub).

## Folder Structure
Same repo as Demo 03. No new local files; PR is created via the GitHub UI.

## Complete Code

`README.md` content for the PR:
```markdown
# devops-<initials>

Welcome! This repository is used in the WA3647 DevOps Fundamentals course.

## Endpoints (after Demo 09)
- `GET /` welcome
- `GET /health`
- `GET /version`
- `GET /env`
- `GET /tips`
```

## Step-by-Step Walkthrough

```bash
cd demos/03-github-fundamentals            # reuse the repo from Demo 3
git switch -c docs/add-readme

cat > README.md <<'EOF'
# devops-<initials>

Welcome! This repository is used in the WA3647 DevOps Fundamentals course.

## Endpoints (after Demo 09)
- GET /
- GET /health
- GET /version
- GET /env
- GET /tips
EOF

git add README.md
git commit -m "docs: expand README with endpoints"
git push -u origin docs/add-readme
```

On GitHub:
1. The repo page shows a yellow banner: **Compare & pull request** → click.
2. Title: `docs: expand README with endpoints`. Description: short why.
3. Click **Create pull request**.
4. Switch to **Files changed** tab, leave a review comment on a line.
5. **Merge pull request** → choose strategy:
   - **Create a merge commit** — preserves branch history.
   - **Squash and merge** — collapses to one tidy commit (most popular).
   - **Rebase and merge** — replays commits on top of `main` (linear history).
6. **Delete branch**.

Locally pull the merged result:
```bash
git switch main
git pull
git branch -d docs/add-readme
```

## Expected Output
GitHub PR page shows:
```
docs/add-readme   ►  main
✅ This branch has no conflicts with the base branch.
[Squash and merge]  ▼
```
After merge:
```
$ git pull
Updating 1234abc..deadbee
Fast-forward
 README.md | 11 ++++++++++-
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| "This branch is out-of-date" | `main` advanced after PR opened | Click **Update branch** on GitHub or `git rebase main` |
| Cannot merge — conflicts | Same lines edited on both sides | Resolve in editor, push again |
| Cannot push to `main` | Branch protection enabled | Open a PR (the *intended* workflow) |
| PR shows wrong files | Branched off the wrong commit | Rebase onto correct base or recreate branch |

## DevOps Best Practices
- **Small PRs** (< 400 LoC) get reviewed faster and have fewer bugs.
- **One logical change per PR.**
- **Required reviewers** + **required status checks** for protected branches.
- Use **draft PRs** to share early progress.

## Production Considerations
- Configure **CODEOWNERS** so the right team is auto-requested.
- Require linear history (rebase/squash only) for cleaner audit trails.
- Use **merge queues** (GitHub Merge Queue) for high-volume repos to avoid
  "green PR + red main" race conditions.
- Auto-delete merged branches.

## Optional Advanced Enhancements
- Add a `.github/pull_request_template.md` and show how it pre-fills PR bodies.
- Demo `gh pr create --fill` and `gh pr merge --squash --delete-branch`.
- Add a "PR title lint" workflow that enforces Conventional Commits.
