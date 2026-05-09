# Demo 12 — Sequential Pipelines

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
demos/12-sequential-pipelines/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/12-sequential-pipelines/
cp demos/sample-app/tests/test_app.py demos/12-sequential-pipelines/tests/
# add staged.yaml above
git add . && git commit -m "ci: staged pipeline" && git push
```

## Prerequisites

- Demos 8–11 complete.

## Learning Objectives

- Use `needs:` to define job order and dependencies.
- Pass values between jobs via job `outputs`.
- Skip downstream work on upstream failure.

## Concepts Covered

- Directed acyclic graph (DAG) of jobs
- `needs:`, `if:`, `outputs:`, `env:`
- Conditional deploys (only on `main`, only on tag)

## Architecture

```
   lint ─┐
         ├──► test ──► build ──► publish ──► deploy(dev) ──► deploy(prod)
         │                                                       ▲
   sec  ─┘                                                  manual approval
```

## Walkthrough

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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Job skipped unexpectedly | Upstream `needs:` failed or was skipped | Inspect upstream; add `if: always()` if you want to run regardless |
| `outputs` empty | Wrote to stdout instead of `$GITHUB_OUTPUT` | Use `echo "k=v" >> "$GITHUB_OUTPUT"` |
| Prod deploy ran without approval | Forgot to set required reviewers on environment | Configure environment protection |
| `if:` always false | Used `${{ }}` *inside* an `if:` (don't) | Just `if: needs.x.outputs.y == 'true'` |

## Best Practices

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

## Instructor Notes

- Show the **graph** view in Actions — `needs:` literally draws arrows.
- Reveal `needs.<job>.result` for fine-grained control:
  `if: needs.lint.result == 'success' && always()`.
- Use **environments** with required reviewers for the "manual approval" gate.

## Real-World Relevance

Most production pipelines mix parallel + sequential: parallel where possible,
sequential where order matters (build → publish → deploy).
