# Demo 34 — Troubleshooting Pipelines

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# Install act (https://github.com/nektos/act)
brew install act    # or scoop / apt
act -j fail
```

## Prerequisites

- Working repo + workflow.

## Learning Objectives

- Read GitHub Actions logs efficiently.
- Use **debug logging**, **re-run with debug**, **tmate** for live SSH.
- Reproduce a CI failure locally with `act`.
- Recognize common failure patterns.

## Concepts Covered

- `ACTIONS_STEP_DEBUG` / `ACTIONS_RUNNER_DEBUG` secrets
- `mxschmitt/action-tmate` for SSH access into the runner
- Workflow visualization, job logs, annotations
- Difference between *workflow file* errors and *step* errors

## Architecture

```
   GitHub Actions log
        ├── ::error::    annotations
        ├── ::warning::
        ├── ::group:: / ::endgroup::    collapsible
        └── ::debug::    only with ACTIONS_STEP_DEBUG=true

   Local repro:
        act -j <job>          # nektos/act runs your workflow in Docker
```

## Walkthrough

### 6. Fix all the bugs (see `fix-broken.md`)

The answer key was extracted alongside this file as `fix-broken.md`.

## Expected Output

After enabling debug:
```
##[debug]Evaluating: secrets.MY_TOKEN
##[debug]Evaluating Index: secrets.MY_TOKEN
##[debug]Result: '***'
```

`tmate` step prints:
```
SSH:  ssh CcEY...@ny1.tmate.io
Web:  https://tmate.io/t/cceY...
```

## Troubleshooting

| Symptom | Diagnostic |
|---|---|
| "Workflow file is invalid" | YAML lint locally; check indentation |
| "Resource not accessible by integration" | `permissions:` too restrictive; add what's needed |
| Job hangs on `setup-*` | Network/cache issue; re-run; consider matrix exclusion |
| Random flakes | Add `actions/cache` for deps; pin versions |
| Step succeeded but did nothing | Implicit silent success; add explicit assertions |

## Best Practices

- **Pin actions** to major versions (or SHA for high-trust).
- Use `::group::` to fold long output: `echo "::group::install"`/`::endgroup::`.
- Add **exit codes** explicitly: `set -euo pipefail` at top of multiline `run:`.
- Use **annotations** so PR reviewers see issues inline.

## Production Considerations

- Tmate is a security risk — restrict to forked or dev branches only.
- Centralize action versions via Dependabot (`.github/dependabot.yml`).
- Capture run telemetry (duration, success rate) to a dashboard.

## Optional Advanced Enhancements

- Use `actions-runner-controller` to run runners in-cluster for SSH-style debug.
- `gh run view --log` and `gh run rerun --debug` from the CLI.
- Adopt **`actionlint`** as a pre-commit hook to catch errors before CI.

## Instructor Notes

- Build a deliberately-broken workflow that students debug live.
- Show **annotations** appearing as red squiggles on PR diffs.
- `tmate` opens a real SSH session to the runner — **only for debugging,
  never on workflows that touch secrets**.

## Real-World Relevance

Pipelines fail. Students will spend a lot of their professional lives
diagnosing CI failures. A tight debugging loop is a career skill.
