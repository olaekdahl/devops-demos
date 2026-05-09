# Demo 07 — Workflow Triggers

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
git add .github/workflows/ && git commit -m "ci: trigger demos" && git push
```

## Prerequisites

- Demo 06 complete.

## Learning Objectives

- Use the most common triggers: `push`, `pull_request`, `schedule`,
  `workflow_dispatch`, `issues`.
- Filter by branch, path, tag.
- Pass user inputs via `workflow_dispatch`.

## Concepts Covered

- Event-driven CI
- Cron syntax for `schedule`
- `paths:` filters to skip irrelevant runs
- `inputs:` for parameterized manual runs

## Architecture

```
push to main   ─►  ci.yaml (build/test)
PR opened      ─►  pr.yaml  (lint/test/comment)
schedule (3am) ─►  nightly.yaml (security scan)
issue opened   ─►  issue.yaml (auto-label)
manual button  ─►  deploy.yaml (with environment input)
```

## Walkthrough

1. Commit and push all five workflows.
2. Push a change to `README.md` only — show CI **does not run** (paths filter).
3. Push a change to `app.py` — CI **does** run.
4. Open a PR — only `pr.yaml` runs.
5. Open a new issue — `issue.yaml` runs (preview from Demo 5).
6. Actions tab → **Manual deploy** → **Run workflow** → choose `prod` + `1.2.3`.
7. Wait until 03:00 UTC, or trigger manually via the dispatch button.

## Expected Output

For the manual deploy:
```
Deploying version=1.2.3
to environment=prod
```

For the PR workflow, the GitHub PR check section shows:
```
✅ PR validation / validate
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Cron never fires | Default branch must contain the file; UTC timing; private repo idle 60d | Push file to default branch; convert your local to UTC; trigger manually weekly |
| `pull_request` doesn't run on forks for secrets | By design — forks can't read secrets | Use `pull_request_target` with explicit, hardened steps |
| `paths:` filter ignored | YAML indentation off | YAML lint; `paths` lives under the event |
| `workflow_dispatch` button missing | Workflow not on default branch | Merge to `main` first |

## Best Practices

- Separate workflows by **purpose** (CI, deploy, scan) not by language.
- Use `paths-ignore:` to skip CI on `*.md`-only changes.
- Use **environments** for any `workflow_dispatch` that touches prod.
- Document inputs in the `description:` — they show in the UI.

## Production Considerations

- Concurrency: `concurrency: deploy-${{ inputs.environment }}` to serialize prod deploys.
- Required reviewers + wait timers via `environments` for `prod`.
- Use **deployment branches** rule to restrict which branches can deploy.

## Optional Advanced Enhancements

- Add a `repository_dispatch` workflow triggered by a webhook from another system.
- Show `workflow_run:` chaining (e.g., deploy after CI succeeds on `main`).
- Use `if:` expressions to conditionally run steps based on `github.event.*`.

## Instructor Notes

- Cron expressions are **UTC** in GitHub Actions. Show this — students always
  trip on it.
- Scheduled workflows on private repos pause after 60 days of inactivity.
- `pull_request` runs from the **base** repo's perms by default — for forks,
  use `pull_request_target` carefully (security risk).

## Real-World Relevance

Triggers are how CI/CD becomes **event-driven** instead of "Bob pushes a button
on Jenkins". Real teams trigger nightly jobs (security scans), on-demand
deploys, and per-PR validation differently.
