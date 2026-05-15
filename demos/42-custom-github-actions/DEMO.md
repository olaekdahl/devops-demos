# Bonus Demo — Custom GitHub Actions (Composite, JavaScript, Docker)

## How to Run

All files needed by this demo are in this folder. From the repo root:

```bash
# 1) Copy this demo's contents into your devops-<initials> repo working tree
cp -r demos/42-custom-github-actions/.github   /path/to/devops-<initials>/
cp -r demos/42-custom-github-actions/actions   /path/to/devops-<initials>/

cd /path/to/devops-<initials>
git checkout -b feat/custom-actions
git add .
git commit -m "ci: demo composite, javascript, and docker custom actions"
git push -u origin feat/custom-actions
```

Then open the **Actions** tab on GitHub and watch the **Custom Actions Demo** workflow
run on the push. You can also trigger it manually via **Run workflow** (it uses
`workflow_dispatch`).

## Prerequisites

- Completed Demo 06 (GitHub Actions Basics) — you can author a workflow file.
- A GitHub repo with Actions enabled.
- No local Docker or Node.js install is required — the GitHub runner builds and
  runs everything.

## Learning Objectives

- Understand the **three flavors** of custom GitHub Actions and when to pick each.
- Author a **composite** action (shell steps bundled as a reusable unit).
- Author a **JavaScript** action (`node20` runtime, uses `@actions/core`).
- Author a **Docker container** action (any language, fully sandboxed image).
- Wire `inputs`, `outputs`, and `env` between actions and calling workflows.
- Reference a **local** action with `uses: ./path/to/action`.

## Concepts Covered

| Action type   | Defined by                | Runs on                | Best for |
|---------------|---------------------------|------------------------|----------|
| Composite     | `action.yml` w/ `runs.using: composite` | Host runner shell | Bundling existing shell/CLI steps; zero build step |
| JavaScript    | `action.yml` w/ `runs.using: node20`    | Host runner Node.js   | Fast startup, GitHub API calls, cross-platform |
| Docker        | `action.yml` w/ `runs.using: docker`    | Runner's Docker daemon | Any language/toolchain; reproducible env (Linux runners only) |

Each action exposes the same contract to the workflow: `inputs:` and `outputs:`
declared in `action.yml`, regardless of implementation.

## Architecture

```
.github/workflows/custom-actions.yaml      ← the calling workflow
   │
   ├─ uses: ./actions/greet-composite       ─► runs shell on the runner
   ├─ uses: ./actions/greet-javascript      ─► runs node20 on the runner
   └─ uses: ./actions/greet-docker          ─► builds image, runs container
```

Each action takes a `who` input and emits a `greeting` output. The workflow
prints all three outputs at the end to prove the contract works identically.

## Walkthrough

1. **Inspect each `action.yml`.** Note that `inputs`/`outputs` look identical;
   only the `runs:` block differs.
   - [actions/greet-composite/action.yml](actions/greet-composite/action.yml)
   - [actions/greet-javascript/action.yml](actions/greet-javascript/action.yml)
   - [actions/greet-docker/action.yml](actions/greet-docker/action.yml)

2. **Composite action.** Open
   [actions/greet-composite/action.yml](actions/greet-composite/action.yml).
   The `runs.steps` look just like workflow steps — `run:` shell with
   `shell: bash` required. Outputs are set via `$GITHUB_OUTPUT`.

3. **JavaScript action.** Open
   [actions/greet-javascript/index.js](actions/greet-javascript/index.js).
   It uses `@actions/core` for `getInput`/`setOutput`. In real life you'd
   `npm install` and commit `node_modules/` (or bundle with `ncc`). This
   demo keeps it tiny by reading env vars directly — no dependencies needed.

4. **Docker action.** Open
   [actions/greet-docker/Dockerfile](actions/greet-docker/Dockerfile) and
   [actions/greet-docker/entrypoint.sh](actions/greet-docker/entrypoint.sh).
   The runner builds the image on first use and runs the container with
   inputs passed as `INPUT_<NAME>` env vars (uppercased).

5. **Calling workflow.** Open
   [.github/workflows/custom-actions.yaml](.github/workflows/custom-actions.yaml).
   Each job uses one action via a **local path** (`uses: ./actions/...`),
   which requires `actions/checkout` first.

6. **Run it.** Push the branch (see *How to Run*). On GitHub, expand each
   job and find the **Print greeting** step.

## Expected Output

In each of the three jobs, the **Print greeting** step prints:

```
greeting=Hello, Ada! (from composite)
greeting=Hello, Ada! (from javascript)
greeting=Hello, Ada! (from docker)
```

The Docker job additionally shows a `Build container image` step in the run
graph (one-time per workflow run).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Can't find 'action.yml'` | Wrong path in `uses:` | Path is relative to repo root; needs `./` prefix |
| `Error: Container action is only supported on Linux` | Used a Docker action on `windows-latest`/`macos-latest` | Run that job on `ubuntu-latest` |
| Composite step: `shell` is required | Composite `run:` steps must declare `shell:` | Add `shell: bash` to each `run:` |
| JS action: `Cannot find module '@actions/core'` | `node_modules/` not committed | Commit deps or use `ncc` to bundle; this demo avoids the dep entirely |
| Output is empty in next step | Forgot to write `$GITHUB_OUTPUT` | `echo "name=value" >> "$GITHUB_OUTPUT"` |
| Docker action ignores input | Reading `$1` instead of `INPUT_WHO` | Docker actions get inputs as `INPUT_<NAME>` env vars (and as args if declared) |

## Best Practices

- **Pick the lightest tool that works:** composite < JavaScript < Docker, in
  startup cost. Docker actions add ~10–30s for image build/pull per run.
- **Pin third-party actions** by SHA in production; pin by major (`@v1`) for
  your own private actions.
- Keep `action.yml` `inputs`/`outputs` stable — they are the public API.
- For JavaScript actions, **bundle** with `@vercel/ncc` so you don't commit
  `node_modules/`.
- For Docker actions, **pre-build and push the image** to GHCR for faster
  runs (`runs.using: docker`, `image: docker://ghcr.io/...`).
- Publish reusable actions to **their own repo** and tag releases (`v1`,
  `v1.2.3`) so consumers can pin. Local actions (`./path`) are great for
  monorepo-internal use.
- Composite actions cannot use `if:` on individual `run:` steps the same way
  jobs can — test conditional logic carefully.
