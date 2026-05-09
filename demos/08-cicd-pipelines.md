# Demo 08 — CI/CD Pipelines

## Learning Objectives
- Define CI vs CD vs Continuous Deployment.
- Build a complete pipeline: lint → test → build → publish artifact → deploy → smoke test.
- Read the workflow graph in the Actions UI.

## Concepts Covered
- Pipeline stages and gates
- Artifact upload/download between jobs
- `needs:` for sequencing (deep dive in Demo 12)
- Smoke tests as a safety net

## Quick Start
Run the demo end-to-end:

```bash
cd demos/08-cicd-pipelines
mkdir -p demos/08-cicd-pipelines/tests demos/08-cicd-pipelines/.github/workflows
cp demos/sample-app/app.py demos/08-cicd-pipelines/
cp demos/sample-app/requirements.txt demos/08-cicd-pipelines/
cp demos/sample-app/tests/test_app.py demos/08-cicd-pipelines/tests/
# create the workflow file above
git add demos/08-cicd-pipelines
git commit -m "ci: add full pipeline"
git push
```

## Real-World Relevance
This is the canonical CI/CD pipeline shape used by 90% of services in industry.
The exact tools change (lint, scan, registry, deploy target), the *shape* does not.

## Demo Architecture
```
                ┌──────┐
push ─►  lint ─►│ test │─► build ─► publish (artifact) ─► deploy ─► smoke
        (flake8)│pytest│   wheel       upload-artifact        bash      curl
                └──────┘
```

## Instructor Notes
- Show a green pipeline first, then **break it** (introduce a failing test).
  Watch downstream jobs not run.
- Highlight that artifacts (wheel) decouple **build** from **deploy** — same
  artifact promoted across environments.

## Prerequisites
- Demos 6–7 complete. Sample app from `demos/sample-app/`.

## Folder Structure
```
demos/08-cicd-pipelines/
  app.py                # copied from sample-app
  requirements.txt
  tests/test_app.py
  .github/workflows/cicd.yaml
```

## Complete Code

Use the canonical `app.py`, `requirements.txt`, `tests/test_app.py` from
[demos/sample-app/](sample-app/).

`.github/workflows/cicd.yaml`
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:

# Reduce GITHUB_TOKEN permissions to least privilege
permissions:
  contents: read

# Cancel previous runs of the same branch
concurrency:
  group: cicd-${{ github.ref }}
  cancel-in-progress: true

jobs:

  # ── Stage 1: Lint ──────────────────────────────────────────────────────
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install flake8
      - run: flake8 app.py --max-line-length=120

  # ── Stage 2: Unit tests ────────────────────────────────────────────────
  test:
    runs-on: ubuntu-latest
    needs: lint                    # only runs if lint passed
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt pytest httpx
      - run: PYTHONPATH=$(pwd) pytest -v tests/

  # ── Stage 3: Build wheel ───────────────────────────────────────────────
  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install build && python -m build --wheel
      - name: Upload wheel artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-wheel
          path: dist/*.whl
          retention-days: 7

  # ── Stage 4: Deploy (mock) ─────────────────────────────────────────────
  deploy:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'    # never deploy from PRs
    steps:
      - uses: actions/download-artifact@v4
        with: { name: app-wheel, path: dist }
      - run: |
          ls -lh dist/
          echo "Pretending to upload $(ls dist/) to S3 / Beanstalk / EKS..."
          # In a real pipeline this is `aws s3 cp` / `eb deploy` / `kubectl apply`.

  # ── Stage 5: Smoke test (mock) ─────────────────────────────────────────
  smoke:
    runs-on: ubuntu-latest
    needs: deploy
    steps:
      - run: |
          echo "curl https://devops-demo.example.com/health"
          echo '{"status":"OK"}'           # pretend response
          echo "::notice::smoke test passed"
```

## Step-by-Step Walkthrough

```bash
mkdir -p demos/08-cicd-pipelines/tests demos/08-cicd-pipelines/.github/workflows
cp demos/sample-app/app.py demos/08-cicd-pipelines/
cp demos/sample-app/requirements.txt demos/08-cicd-pipelines/
cp demos/sample-app/tests/test_app.py demos/08-cicd-pipelines/tests/
# create the workflow file above
git add demos/08-cicd-pipelines
git commit -m "ci: add full pipeline"
git push
```

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

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `flake8` exits non-zero | Real lint issue | Fix code or set `--ignore=E501` for line length |
| `ModuleNotFoundError: app` in tests | `PYTHONPATH` not set | Keep `PYTHONPATH=$(pwd)` |
| Artifact missing in deploy job | Used `upload-artifact@v3` & `download-artifact@v4` mix | Use `@v4` on both |
| Deploy ran from PR | Forgot `if: github.ref == 'refs/heads/main'` | Add the guard |

## DevOps Best Practices
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
