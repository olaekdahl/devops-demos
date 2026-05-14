# Demo 08 — CI/CD Pipelines

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
demos/08-cicd-pipelines/.github/workflows
cp demos/sample-app/app.py demos/08-cicd-pipelines/
cp demos/sample-app/requirements.txt demos/08-cicd-pipelines/
cp demos/sample-app/tests/test_app.py demos/08-cicd-pipelines/tests/
git add demos/08-cicd-pipelines
git commit -m "ci: add full pipeline"
git push
```

## Prerequisites

- Demos 6–7 complete. Sample app from `demos/sample-app/`.

## Learning Objectives

- Define CI vs CD vs Continuous Deployment.
- Build a complete pipeline: lint → test → build → publish artifact → deploy → smoke test.
- Read the workflow graph in the Actions UI.

## Concepts Covered

- Pipeline stages and gates
- Artifact upload/download between jobs
- `needs:` for sequencing (deep dive in Demo 12)
- Smoke tests as a safety net

## Architecture

```
                ┌──────┐
push ─►  lint ─►│ test │─► build ─► publish (artifact) ─► deploy ─► smoke
        (flake8)│pytest│   wheel       upload-artifact        bash      curl
                └──────┘
```

## Walkthrough

In the Actions tab:
1. Watch the pipeline graph: lint → test → build → deploy → smoke.
2. Click the **build** job → **Artifacts** → download the wheel.
3. Re-run with a failing test (change `VERSION` in `app.py` to `1.0.1`):
   the **test** job goes red, **build/deploy/smoke** are skipped.

## Expected Output

```
✅ lint   (12s)
✅ test   (45s)
✅ build  (28s)         + 1 artifact: app-wheel
✅ deploy (4s)          (skipped on PRs)
✅ smoke  (3s)
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `flake8` exits non-zero | Real lint issue | Fix code or set `--ignore=E501` for line length |
| `ModuleNotFoundError: app` in tests | `PYTHONPATH` not set | Keep `PYTHONPATH=$(pwd)` |
| Artifact missing in deploy job | Used `upload-artifact@v3` & `download-artifact@v4` mix | Use `@v4` on both |
| Deploy ran from PR | Forgot `if: github.ref == 'refs/heads/main'` | Add the guard |

## Best Practices

- **Fail fast**: lint is cheapest, run it first.
- **Build once, deploy many**: produce one artifact, promote through envs.
- **No secrets in PR runs** — gate deploy on `main`-only and use environments.
- **Idempotent steps** — re-running a workflow should not corrupt state.

## Production Considerations

- Add **container scan** (Trivy) and **SBOM** (Syft) before publish.
- Replace mock deploy with `aws-actions/configure-aws-credentials` + `kubectl apply`.
- Add **canary** + **rollback** stages.
- Surface deployment to Slack via `slackapi/slack-github-action`.

## Optional Advanced Enhancements

- Split into **reusable workflows** (`workflow_call`) so multiple repos share the pipeline.
- Add a **manual approval gate** before `deploy` using GitHub Environments.
- Add **DORA metric** export to a dashboard.


## Real-World Relevance

This is the canonical CI/CD pipeline shape used by 90% of services in industry.
The exact tools change (lint, scan, registry, deploy target), the *shape* does not.
