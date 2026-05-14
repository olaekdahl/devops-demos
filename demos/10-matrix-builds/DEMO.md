# Demo 10 — Matrix Builds

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
demos/10-matrix-builds/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/10-matrix-builds/
cp demos/sample-app/tests/test_app.py demos/10-matrix-builds/tests/
# Add matrix.yaml above
git add . && git commit -m "ci: matrix build" && git push
```

## Prerequisites

- Demo 9 complete.

## Learning Objectives

- Use `strategy.matrix` to test across multiple combinations.
- Limit / exclude / include matrix cells.
- Read a matrix run in the GitHub UI.

## Concepts Covered

- Combinatorial test coverage (Python × OS)
- `fail-fast`, `max-parallel`
- `include:` / `exclude:` to surgically tune the grid

## Architecture

```
strategy.matrix:                 ┌──── ubuntu / py3.12 ──── pytest
  os:    [ubuntu, macos]   ───►  ├──── ubuntu / py3.13 ──── pytest
  py:    [3.12, 3.13]            ├──── macos  / py3.12 ──── pytest
                                 └──── macos  / py3.13 ──── pytest
```

## Walkthrough

In Actions:
1. The single `test` job expands into 5 jobs (2×3 − 1 exclude = 5).
2. The "with-coverage" cell shows extra coverage step output.
3. Cancel one cell and watch others continue (`fail-fast: false`).

## Expected Output

```
✅ test (ubuntu-latest / py3.11)
✅ test (ubuntu-latest / py3.12 / with-coverage)   ◄ extra coverage step
✅ test (ubuntu-latest / py3.13)
✅ test (macos-latest  / py3.12)
✅ test (macos-latest  / py3.13)
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Matrix not expanding | Wrong indentation under `strategy:` | YAML lint |
| One cell fails, all cancelled | `fail-fast: true` (default) | Set `fail-fast: false` for diagnostic runs |
| `python-version: 3.10` becomes `3.1` | YAML treats it as a number | Quote it: `'3.10'` |
| Combinatorial explosion → minute hog | Too broad matrix | Use `exclude:` and matrix only on critical dims |

## Best Practices

- Match prod + N-1 + (optionally) preview versions — not every version ever.
- Quote all version strings.
- Use `include:` for one-off variations rather than spawning separate jobs.
- Consider `fail-fast: false` while diagnosing, `true` for normal CI.

## Production Considerations

- For library projects, generate the matrix from `pyproject.toml` classifiers.
- Use **GitHub-hosted larger runners** for big matrices to keep wall-clock low.
- Cost-aware: avoid macOS unless needed; ARM Linux runners are cheaper than x86 macs.

## Optional Advanced Enhancements

- Build the matrix dynamically from a job output (`needs.<id>.outputs.matrix`).
- Use `runs-on: [self-hosted, gpu]` cells for a hardware-tagged matrix.
- Demonstrate matrix on Docker base images for cross-distro test coverage.


## Real-World Relevance

Libraries (anyone publishing to PyPI) test on every supported Python and OS.
Apps test on prod-like + N-1 versions to catch upgrade regressions.
