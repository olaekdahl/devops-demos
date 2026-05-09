# Demo 12 — Sequential Pipelines

## Learning Objectives
- Use `needs:` to define job order and dependencies.
- Pass values between jobs via job `outputs`.
- Skip downstream work on upstream failure.

## Concepts Covered
- Directed acyclic graph (DAG) of jobs
- `needs:`, `if:`, `outputs:`, `env:`
- Conditional deploys (only on `main`, only on tag)

## Quick Start
Run the demo end-to-end:

```bash
cd demos/12-sequential-pipelines
mkdir -p demos/12-sequential-pipelines/tests demos/12-sequential-pipelines/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/12-sequential-pipelines/
cp demos/sample-app/tests/test_app.py demos/12-sequential-pipelines/tests/
# add staged.yaml above
git add . && git commit -m "ci: staged pipeline" && git push
```

## Real-World Relevance
Most production pipelines mix parallel + sequential: parallel where possible,
sequential where order matters (build → publish → deploy).

## Demo Architecture
```
   lint ─┐
         ├──► test ──► build ──► publish ──► deploy(dev) ──► deploy(prod)
         │                                                       ▲
   sec  ─┘                                                  manual approval
```

## Instructor Notes
- Show the **graph** view in Actions — `needs:` literally draws arrows.
- Reveal `needs.<job>.result` for fine-grained control:
  `if: needs.lint.result == 'success' && always()`.
- Use **environments** with required reviewers for the "manual approval" gate.

## Prerequisites
- Demos 8–11 complete.

## Folder Structure
```
demos/12-sequential-pipelines/
  app.py, requirements.txt, tests/
  .github/workflows/staged.yaml
```

## Complete Code

`.github/workflows/staged.yaml`
```yaml
name: Staged pipeline
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:

  # Stage 1 — parallel quality gates
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install flake8 && flake8 app.py --max-line-length=120

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install pip-audit && pip-audit -r requirements.txt || true

  # Stage 2 — needs both quality gates
  test:
    needs: [lint, security]
    runs-on: ubuntu-latest
    outputs:
      tests-passed: ${{ steps.set.outputs.passed }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt pytest httpx
      - run: PYTHONPATH=$(pwd) pytest -v tests/
      - id: set
        run: echo "passed=true" >> "$GITHUB_OUTPUT"

  # Stage 3 — build runs only after tests pass
  build:
    needs: test
    if: needs.test.outputs.tests-passed == 'true'
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.ver.outputs.version }}
    steps:
      - uses: actions/checkout@v4
      - id: ver
        run: echo "version=1.0.${{ github.run_number }}" >> "$GITHUB_OUTPUT"
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install build && python -m build --wheel
      - uses: actions/upload-artifact@v4
        with: { name: app-wheel, path: dist/*.whl }

  deploy-dev:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: dev          # GitHub Environment (no protection rules)
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }} to DEV"

  deploy-prod:
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: prod         # configure required reviewers in repo settings
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }} to PROD"
```

Configure once in GitHub → Settings → **Environments**:
- Create `dev` (no protections).
- Create `prod` with **Required reviewers** = your username.

## Step-by-Step Walkthrough
```bash
mkdir -p demos/12-sequential-pipelines/tests demos/12-sequential-pipelines/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/12-sequential-pipelines/
cp demos/sample-app/tests/test_app.py demos/12-sequential-pipelines/tests/
# add staged.yaml above
git add . && git commit -m "ci: staged pipeline" && git push
```

In Actions:
1. Watch the graph: `lint` ‖ `security` → `test` → `build` → `deploy-dev` →
   (waiting for approval) → `deploy-prod`.
2. Click **Review deployments** on `prod`, approve, watch it deploy.
3. Break a test — `build`/`deploy-*` are skipped.

## Expected Output
```
✅ lint
✅ security
✅ test                outputs.tests-passed=true
✅ build               outputs.version=1.0.42
✅ deploy-dev          environment: dev
🟡 deploy-prod         waiting for review...
   ▶ approved by oe
✅ deploy-prod
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Job skipped unexpectedly | Upstream `needs:` failed or was skipped | Inspect upstream; add `if: always()` if you want to run regardless |
| `outputs` empty | Wrote to stdout instead of `$GITHUB_OUTPUT` | Use `echo "k=v" >> "$GITHUB_OUTPUT"` |
| Prod deploy ran without approval | Forgot to set required reviewers on environment | Configure environment protection |
| `if:` always false | Used `${{ }}` *inside* an `if:` (don't) | Just `if: needs.x.outputs.y == 'true'` |

## DevOps Best Practices
- Express order with `needs:` — not with `sleep` or `if`.
- Use **environments** as the gate for prod, not magic branch rules.
- Use job `outputs` instead of artifacts for small string values.
- Always `cancel-in-progress` for the same branch but **never** for tags.

## Production Considerations
- Add **manual approval + wait timer** on prod.
- Add **rollback job** triggered manually with the previous artifact's version.
- Track per-stage duration; long stages → split or parallelize.
- For monorepos, generate per-service downstream stages dynamically.

## Optional Advanced Enhancements
- Replace inline build with a **reusable workflow** (`uses: ./.github/workflows/_build.yaml`).
- Add a **canary** stage between dev and prod (10% of pods first).
- Trigger downstream **deploy** workflows in other repos via `repository_dispatch`.
