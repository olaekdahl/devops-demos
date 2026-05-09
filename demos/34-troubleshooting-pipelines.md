# Demo 34 — Troubleshooting Pipelines

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

## Real-World Relevance
Pipelines fail. Students will spend a lot of their professional lives
diagnosing CI failures. A tight debugging loop is a career skill.

## Demo Architecture
```
   GitHub Actions log
        ├── ::error::    annotations
        ├── ::warning::
        ├── ::group:: / ::endgroup::    collapsible
        └── ::debug::    only with ACTIONS_STEP_DEBUG=true

   Local repro:
        act -j <job>          # nektos/act runs your workflow in Docker
```

## Instructor Notes
- Build a deliberately-broken workflow that students debug live.
- Show **annotations** appearing as red squiggles on PR diffs.
- `tmate` opens a real SSH session to the runner — **only for debugging,
  never on workflows that touch secrets**.

## Prerequisites
- Working repo + workflow.

## Folder Structure
```
demos/34-troubleshooting-pipelines/
  .github/workflows/broken.yaml
  fix-broken.md
```

## Complete Code

`.github/workflows/broken.yaml` — intentionally broken
```yaml
name: Broken — debug me
on: [workflow_dispatch]
jobs:
  fail:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # BUG 1: typo in setup action version
      - uses: actions/setup-python@v55
        with: { python-version: '3.12' }

      # BUG 2: heredoc unquoted, $VAR is expanded at workflow parse instead of shell
      - name: Print stuff
        run: |
          cat <<EOF
          hello $USER from runner
          EOF

      # BUG 3: silently ignored failure
      - name: Maybe broken
        run: pytest tests/  # tests/ doesn't exist

      # BUG 4: secret used in shell with set -x leaks
      - name: Leaky
        env:
          MY_TOKEN: ${{ secrets.MY_TOKEN }}
        run: |
          set -x
          echo "Token=$MY_TOKEN"

      # BUG 5: outputs not propagated
      - id: ver
        run: echo "version=1.2.3"          # missing >> "$GITHUB_OUTPUT"
      - run: echo "got ${{ steps.ver.outputs.version }}"
```

## Step-by-Step Walkthrough

### 1. Read the failure
```
✘ actions/setup-python@v55  ── action not found (BUG 1)
```
Fix: `actions/setup-python@v5`.

### 2. Enable debug logging
- Repo → Settings → Secrets → add:
  - `ACTIONS_STEP_DEBUG = true`
  - `ACTIONS_RUNNER_DEBUG = true`
- Re-run the workflow → ::debug:: lines appear.

### 3. Add a tmate SSH session (only on failure)
```yaml
      - name: SSH into runner on failure
        if: failure()
        uses: mxschmitt/action-tmate@v3
        timeout-minutes: 15
```
Run again, fail, follow the printed `ssh ... @ny1.tmate.io` URL.

### 4. Use workflow annotations
```yaml
      - run: |
          echo "::warning file=app.py,line=8::Version mismatch"
          echo "::error::Tests directory missing"
```

### 5. Reproduce locally with `act`
```bash
# Install act (https://github.com/nektos/act)
brew install act    # or scoop / apt
act -j fail
```

### 6. Fix all the bugs (see `fix-broken.md`)

`fix-broken.md`
```
BUG 1 -> use @v5 (pinned to a real major)
BUG 2 -> use heredoc 'EOF' (single quotes) to disable expansion if not desired,
         or just trust the shell to expand $USER at runtime — the bug here
         was assuming $USER inside heredoc would be the GitHub user.
BUG 3 -> add tests/ directory and tests, or remove pytest step.
         Use `set -e` (Actions does this by default for `run:` since 2024)
         and `if: ${{ !cancelled() }}` to ensure subsequent steps still run when needed.
BUG 4 -> never `set -x` with secrets; even masking can fail when split or transformed.
BUG 5 -> echo "version=1.2.3" >> "$GITHUB_OUTPUT"
```

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

## Common Failure Scenarios
| Symptom | Diagnostic |
|---|---|
| "Workflow file is invalid" | YAML lint locally; check indentation |
| "Resource not accessible by integration" | `permissions:` too restrictive; add what's needed |
| Job hangs on `setup-*` | Network/cache issue; re-run; consider matrix exclusion |
| Random flakes | Add `actions/cache` for deps; pin versions |
| Step succeeded but did nothing | Implicit silent success; add explicit assertions |

## DevOps Best Practices
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
