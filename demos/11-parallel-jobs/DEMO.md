# Demo 11 — Parallel Jobs

## Learning Objectives
- Run independent jobs in parallel to cut wall-clock time.
- Recognize when jobs are truly independent vs only "appear" independent.
- Tune concurrency.

## Concepts Covered
- Default behaviour: jobs run in parallel unless `needs:` says otherwise
- Cost vs latency tradeoffs
- Where parallel jobs share state (artifacts) vs don't (env, FS)

## Quick Start
Run the demo end-to-end:

```bash
cd demos/11-parallel-jobs
mkdir -p demos/11-parallel-jobs/tests demos/11-parallel-jobs/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/11-parallel-jobs/
cp demos/sample-app/tests/test_app.py demos/11-parallel-jobs/tests/
# add parallel.yaml above
git add . && git commit -m "ci: parallel jobs" && git push
```

## Real-World Relevance
Pipeline wall-clock is a developer-experience metric. Parallelizing lint,
unit tests, security scan, and build cuts feedback time from minutes to seconds.

## Demo Architecture
```
                ┌─ lint        ─┐
push  ─────────►├─ unit-tests  ─┤   (all run in parallel — independent)
                ├─ security    ─┤
                └─ build       ─┘
```

## Instructor Notes
- Show the job graph in the Actions UI — students *see* parallelism.
- Note: each parallel job is a fresh runner — no shared filesystem; pass data
  via artifacts.
- This demo is the foundation for **Demo 12** which adds dependencies.

## Prerequisites
- Demo 9 complete.

## Folder Structure
```
demos/11-parallel-jobs/
  app.py, requirements.txt, tests/test_app.py
  .github/workflows/parallel.yaml
```

## Complete Code

`.github/workflows/parallel.yaml`
```yaml
name: Parallel CI
on: [push, pull_request]

jobs:

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install flake8
      - run: flake8 app.py --max-line-length=120

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt pytest httpx
      - run: PYTHONPATH=$(pwd) pytest -v tests/

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install pip-audit bandit
      - name: Audit dependencies
        run: pip-audit -r requirements.txt || true   # warn, don't block
      - name: Static analysis
        run: bandit -r . -x ./tests || true

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install build && python -m build --wheel
      - uses: actions/upload-artifact@v4
        with: { name: app-wheel, path: dist/*.whl }
```

## Step-by-Step Walkthrough
```bash
mkdir -p demos/11-parallel-jobs/tests demos/11-parallel-jobs/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/11-parallel-jobs/
cp demos/sample-app/tests/test_app.py demos/11-parallel-jobs/tests/
# add parallel.yaml above
git add . && git commit -m "ci: parallel jobs" && git push
```

In Actions, observe four jobs running simultaneously. Total wall-clock ≈ time
of the slowest job (typically ~45s) instead of the sum (~3 min).

Now intentionally fail `lint` (introduce a 200-char line) and observe:
- `lint` ❌
- `unit-tests`, `security`, `build` still ✅
- The PR check is overall ❌ — *any* failed required job blocks merge.

## Expected Output
Run page:
```
lint         ❌  18s
unit-tests   ✅  42s
security     ✅  35s
build        ✅  28s
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Jobs run sequentially despite no `needs:` | Account/runner concurrency cap | Upgrade plan or use larger runners |
| Build can't see test results | Tried to share filesystem between jobs | Use artifacts or combine into one job |
| One job times out | Forgot `cache: 'pip'` so install is slow | Add caching |
| All jobs cancelled when one fails | A `concurrency` group set to cancel-in-progress | Loosen `concurrency.cancel-in-progress` |

## DevOps Best Practices
- Push truly independent work to parallel jobs.
- **Cache** dependencies — runners are stateless.
- For matrix×parallel, use `max-parallel` to control burst.
- Mark required checks in branch protection so all parallel jobs gate the merge.

## Production Considerations
- Track `pipeline.duration_seconds` as a metric — alert on regressions.
- For monorepos, parallelize per-service via path-filtered jobs.
- Use **larger runners** for compute-heavy jobs (build, scan).

## Optional Advanced Enhancements
- Add a **fan-in** job (`needs: [lint, unit-tests, security, build]`) that posts
  a single Slack summary.
- Add `pytest-xdist -n auto` inside the unit-tests job for in-job parallelism.
- Generate the parallel job list dynamically from changed paths in a monorepo.
