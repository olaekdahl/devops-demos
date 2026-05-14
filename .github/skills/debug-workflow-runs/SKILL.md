---
name: debug-workflow-runs
description: 'Diagnose and debug failed GitHub Actions workflow runs in this repository. Use when a workflow run is failing, a job/step errored, a CI check is red on a PR, a workflow is not triggering as expected, or the user mentions "failed action", "broken workflow", "CI failing", "actions error", "workflow run", or asks to investigate a specific run ID/URL. Walks through fetching run logs via `gh`, locating the failing step, mapping it back to the workflow YAML in `.github/workflows/`, and proposing a fix.'
argument-hint: '[run-id | run-url | workflow-name | PR number]'
---

# Debug Failed GitHub Actions Workflow Runs

## When to Use

- A workflow run failed and the user wants to know why.
- A pull request has a red check from GitHub Actions.
- A workflow is not triggering, is queued forever, or behaving unexpectedly.
- Re-running a failed job and needing root-cause analysis first.
- The user pastes a run URL like `https://github.com/<owner>/<repo>/actions/runs/<id>`.

## Prerequisites

- `gh` CLI authenticated (`gh auth status`). If not, ask the user to run `gh auth login`.
- Working directory is the repo (or pass `-R <owner>/<repo>` to `gh`).
- Workflows live under [.github/workflows/](../../workflows/).

## Procedure

### 1. Identify the target run

Pick ONE based on what the user provided:

```bash
# By explicit run ID or URL
gh run view <run-id> --log-failed

# Latest failed run on current branch
gh run list --branch "$(git branch --show-current)" --status failure --limit 5

# Failures for a specific workflow file
gh run list --workflow <file.yaml> --status failure --limit 10

# Checks for a PR
gh pr checks <pr-number>
```

If multiple candidates exist, list them with `gh run list` and ask the user to confirm.

### 2. Pull failure-focused logs

Prefer the filtered view first — it is much smaller than the full log:

```bash
gh run view <run-id> --log-failed | tail -n 300
```

If that is insufficient, fetch the full log for the specific job:

```bash
gh run view <run-id> --job <job-id> --log
```

Use `gh run view <run-id>` (no `--log`) to list jobs and their IDs with status icons.

### 3. Locate the failing step in the workflow

1. From the log header, note the `workflow`, `job`, and step name.
2. Open the matching file under [.github/workflows/](../../workflows/) (naming convention here is `<demo>__<name>.yaml`).
3. Find the step by `name:` or `run:` content. Inspect:
   - `uses:` action version pinning
   - `with:` inputs and `env:` values
   - `if:` conditions
   - `permissions:`, `secrets`, and `${{ ... }}` expressions
   - `runs-on:` runner and matrix entries

### 4. Classify the failure

Match the error against these common categories before proposing a fix:

| Symptom in logs | Likely cause | First check |
|---|---|---|
| `Error: Resource not accessible by integration` | Missing `permissions:` block | Job/workflow `permissions:` |
| `Bad credentials` / `401` on `gh`/API | Token/secret missing or expired | `secrets.*` referenced, repo/org secret config |
| `Unable to resolve action` | Wrong `uses:` ref or private action | Action name, tag/sha, network |
| `npm ERR!` / `pip` resolution error | Dependency drift, lockfile mismatch | Caching keys, lockfile committed |
| Test failures only on one matrix entry | OS/version-specific bug | `strategy.matrix`, conditional steps |
| Job stuck `queued` | Missing/offline runner label | `runs-on:`, self-hosted runner status |
| `context access might be invalid` | Expression references undefined secret/var | Spelling, env scoping |
| OIDC `Not authorized` to cloud | Trust policy / `aud` / `sub` mismatch | `permissions: id-token: write`, IAM trust |
| Workflow not triggering | Wrong `on:` event, paths filter, branch | `on:` block, default branch |
| Timeouts / cancelled | `timeout-minutes`, hanging process | Step output near end of log |

### 5. Propose and (if approved) apply a fix

- State the root cause in one sentence with a log excerpt as evidence.
- Show the minimal YAML diff against the workflow file.
- Note any required out-of-band changes (secrets, runner labels, cloud IAM).
- After editing, validate locally if possible:
  ```bash
  # Lint workflow YAML (already wired up in this repo)
  gh run list --workflow 39-supply-chain-security__lint-workflows.yaml --limit 1
  ```
- Re-run the failed jobs only:
  ```bash
  gh run rerun <run-id> --failed
  ```

### 6. Report back

Summarize for the user:
- Run ID + workflow file (linked)
- Failing job / step
- Root cause
- Fix applied or recommended
- Command to re-trigger

## Useful one-liners

```bash
# Most recent failed run for this repo
gh run list --status failure --limit 1 --json databaseId,displayTitle,workflowName,headBranch,conclusion

# Download all logs as a zip for offline inspection
gh run download <run-id> --dir /tmp/run-<run-id>

# Watch an in-progress run
gh run watch <run-id>

# Show annotations (the red error summaries) for a run
gh api repos/{owner}/{repo}/actions/runs/<run-id>/jobs --jq '.jobs[] | {name, conclusion, steps: [.steps[] | select(.conclusion=="failure") | .name]}'
```

## Anti-patterns

- Don't dump the full unfiltered log into the conversation — use `--log-failed` and `tail`.
- Don't guess the workflow file; map it from the run metadata.
- Don't blindly bump action versions to "fix" an error; identify the cause first.
- Don't add `continue-on-error: true` to silence a real failure.
- Don't commit secrets or tokens into the workflow while debugging.
