# Demo 10 — Matrix Builds

## Learning Objectives
- Use `strategy.matrix` to test across multiple combinations.
- Limit / exclude / include matrix cells.
- Read a matrix run in the GitHub UI.

## Concepts Covered
- Combinatorial test coverage (Python × OS)
- `fail-fast`, `max-parallel`
- `include:` / `exclude:` to surgically tune the grid

## Real-World Relevance
Libraries (anyone publishing to PyPI) test on every supported Python and OS.
Apps test on prod-like + N-1 versions to catch upgrade regressions.

## Demo Architecture
```
strategy.matrix:                 ┌──── ubuntu / py3.12 ──── pytest
  os:    [ubuntu, macos]   ───►  ├──── ubuntu / py3.13 ──── pytest
  py:    [3.12, 3.13]            ├──── macos  / py3.12 ──── pytest
                                 └──── macos  / py3.13 ──── pytest
```

## Instructor Notes
- macOS runners are 10× the cost of Linux. Mention it.
- Default `fail-fast: true` cancels siblings on first failure — sometimes
  unwanted; show how to flip it.
- Matrix expansion happens at workflow parse time — show it in the UI.

## Prerequisites
- Demo 9 complete.

## Folder Structure
```
demos/10-matrix-builds/
  app.py, requirements.txt, tests/test_app.py    (from sample-app)
  .github/workflows/matrix.yaml
```

## Complete Code

`.github/workflows/matrix.yaml`
```yaml
name: Matrix tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false           # let all cells finish so we see ALL failures
      max-parallel: 4            # cap concurrent jobs
      matrix:
        os: [ubuntu-latest, macos-latest]
        python-version: ['3.11', '3.12', '3.13']
        # Skip a known-broken combo
        exclude:
          - os: macos-latest
            python-version: '3.11'
        # Add a special cell with extra env
        include:
          - os: ubuntu-latest
            python-version: '3.12'
            extra: 'with-coverage'

    name: ${{ matrix.os }} / py${{ matrix.python-version }}${{ matrix.extra && format(' / {0}', matrix.extra) || '' }}

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'
      - run: pip install -r requirements.txt pytest httpx pytest-cov
      - name: Run tests
        run: PYTHONPATH=$(pwd) pytest -v tests/
      - name: Coverage report (special cell only)
        if: matrix.extra == 'with-coverage'
        run: PYTHONPATH=$(pwd) pytest --cov=app --cov-report=term-missing tests/
```

## Step-by-Step Walkthrough
```bash
mkdir -p demos/10-matrix-builds/tests demos/10-matrix-builds/.github/workflows
cp demos/sample-app/app.py demos/sample-app/requirements.txt demos/10-matrix-builds/
cp demos/sample-app/tests/test_app.py demos/10-matrix-builds/tests/
# Add matrix.yaml above
git add . && git commit -m "ci: matrix build" && git push
```

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

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Matrix not expanding | Wrong indentation under `strategy:` | YAML lint |
| One cell fails, all cancelled | `fail-fast: true` (default) | Set `fail-fast: false` for diagnostic runs |
| `python-version: 3.10` becomes `3.1` | YAML treats it as a number | Quote it: `'3.10'` |
| Combinatorial explosion → minute hog | Too broad matrix | Use `exclude:` and matrix only on critical dims |

## DevOps Best Practices
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
