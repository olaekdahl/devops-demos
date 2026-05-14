# Demo 06 — GitHub Actions Basics

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
/workflows
git init && git branch -m main
git add . && git commit -m "ci: hello workflow"
# Push into your devops-<initials> repo's main branch (or a separate repo)
git remote add origin https://github.com/<account>/devops-<initials>.git
git push -u origin main
```

## Prerequisites

- A GitHub repo (Demos 03–04). Actions enabled (default).

## Learning Objectives

- Define **workflow**, **job**, **step**, **action**, **runner**.
- Author a first `.github/workflows/*.yaml` and watch it run.
- Read run logs and the workflow visualization.

## Concepts Covered

- YAML structure: `name`, `on`, `jobs`, `runs-on`, `steps`, `uses`, `run`.
- Hosted vs self-hosted runners.
- Marketplace actions (`actions/checkout`, `actions/setup-python`).
- The implicit `GITHUB_TOKEN` and `GITHUB_*` env vars.

## Architecture

```
   git push  ─►  GitHub  ─►  schedules a Job on a Runner (ubuntu-latest VM)
                              └─ checks out code
                              └─ runs steps
                              └─ uploads logs/artifacts
                              └─ status reported on commit (✅/❌)
```

## Walkthrough

In GitHub:
1. **Actions** tab → see "Hello Actions" run scheduled.
2. Click the run → click the `greet` job → expand each step.
3. Click **Re-run jobs** to demonstrate idempotency.
4. Click **Run workflow** to demonstrate the `workflow_dispatch` button.

## Expected Output

In the `Print runner info` step:
```
Repo:   <account>/devops-<initials>
SHA:    deadbeef...
Actor:  <your-username>
Event:  push
Linux fv-az... 6.5.0-... GNU/Linux
```

The job summary shows ✅ green. A green check appears next to the commit on the
**Code** tab.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Workflow file not found` | Wrong path; must be `.github/workflows/*.y(a)ml` | Move it |
| Run never starts | Workflow disabled in repo settings | Settings → Actions → Allow all |
| Step fails: `bash: setup-python: command not found` | Tried `run:` for an action | Use `uses:` for actions, `run:` for shell |
| Permission denied writing back | `permissions:` insufficient | Add `permissions: contents: write` |

## Best Practices

- **Pin actions to a major version** (`@v4`) — easy upgrades + security patches.
- For high-trust workflows, **pin to commit SHA**: `uses: actions/checkout@8e5e7e5...`.
- Keep workflow files small; refactor shared logic into reusable workflows.
- Name jobs/steps clearly — they show up in PR check status.

## Production Considerations

- Set `permissions:` explicitly per workflow — least privilege for `GITHUB_TOKEN`.
- Use **environments** for prod deploys with required reviewers.
- Cache dependencies (`actions/cache`) to cut minutes (and cost).
- Concurrency control: `concurrency: { group: deploy, cancel-in-progress: true }`.

## Optional Advanced Enhancements

- Add a **status badge** to the README: `![CI](https://github.com/<a>/<r>/actions/workflows/hello.yaml/badge.svg)`.
- Show `act` (https://github.com/nektos/act) to run a workflow locally with Docker.
- Inspect the run with `gh run watch` from the CLI.


## Real-World Relevance

GitHub Actions is the default CI/CD for any repo on GitHub. It replaces or
augments Jenkins, CircleCI, GitLab CI in most new projects.
