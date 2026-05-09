# Demo 09 — Unit Testing

## Learning Objectives
- Write `pytest` unit tests for a FastAPI app.
- Run tests locally and in CI.
- Read a failing test report and fix it.

## Concepts Covered
- `pytest` discovery, fixtures, assertions
- `fastapi.testclient.TestClient` for in-process HTTP tests
- Why CI must run the same tests as your laptop
- Fast vs slow tests; deterministic tests

## Real-World Relevance
Unit tests are the cheapest, fastest safety net. Every PR should run them.
Companies often gate merges on **green tests + coverage threshold**.

## Demo Architecture
```
test_app.py  ─►  pytest  ─►  TestClient(app)  ─►  in-memory ASGI call
                                       │
                                       └─► assert response status & JSON
```

## Instructor Notes
- Run tests **green** first, then break the app to show a red report.
- Highlight that `TestClient` does **not** start a real server — no port, no
  network — so tests are fast and CI-friendly.
- Show `pytest -v -k health` to run a subset.

## Prerequisites
- Python 3.12, virtualenv tooling.

## Folder Structure
```
demos/09-unit-testing/
  app.py
  requirements.txt
  tests/test_app.py
  .github/workflows/tests.yaml
```

## Complete Code

Use the canonical [sample-app/app.py](sample-app/app.py),
[sample-app/requirements.txt](sample-app/requirements.txt),
[sample-app/tests/test_app.py](sample-app/tests/test_app.py).

`.github/workflows/tests.yaml`
```yaml
name: Unit tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt pytest httpx pytest-cov
      - name: Run tests with coverage
        run: |
          PYTHONPATH=$(pwd) pytest -v --cov=app --cov-report=term-missing tests/
      - name: Fail if coverage < 80%
        run: |
          PYTHONPATH=$(pwd) pytest --cov=app --cov-fail-under=80 tests/
```

## Step-by-Step Walkthrough
```bash
mkdir -p demos/09-unit-testing/tests
cp demos/sample-app/* demos/09-unit-testing/ 2>/dev/null || true
cp -r demos/sample-app/tests demos/09-unit-testing/
cd demos/09-unit-testing

python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt pytest httpx pytest-cov

# Run all tests
PYTHONPATH=$(pwd) pytest -v tests/

# Run only the health test
PYTHONPATH=$(pwd) pytest -v -k health tests/

# With coverage
PYTHONPATH=$(pwd) pytest --cov=app --cov-report=term-missing tests/
```

Now break a test on purpose:
```bash
sed -i 's/VERSION = "1.0.0"/VERSION = "1.0.1"/' app.py
PYTHONPATH=$(pwd) pytest -v tests/test_app.py::test_get_version
```

Watch the assertion error. Revert and re-run.

## Expected Output
```
============================= test session starts =============================
collected 8 items

tests/test_app.py::test_health_check     PASSED  [ 12%]
tests/test_app.py::test_get_version      PASSED  [ 25%]
tests/test_app.py::test_get_env          PASSED  [ 37%]
tests/test_app.py::test_get_devops_tip   PASSED  [ 50%]
tests/test_app.py::test_read_root        PASSED  [ 62%]
tests/test_app.py::test_login            PASSED  [ 75%]
tests/test_app.py::test_logout           PASSED  [ 87%]
============================== 8 passed in 0.42s ==============================
```

Failing run:
```
>       assert r.json() == {"version": "1.0.0"}
E       AssertionError: assert {'version': '1.0.1'} == {'version': '1.0.0'}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: No module named 'app'` | `PYTHONPATH` missing | Prefix with `PYTHONPATH=$(pwd)` or add `conftest.py` |
| `httpx` missing | TestClient depends on it | `pip install httpx` |
| Tests pollute env vars | Fixture forgot to clean up | Use `yield` + `del os.environ[...]` |
| CI passes, local fails | Different Python version | Use matrix builds (Demo 10) |

## DevOps Best Practices
- Tests are **part of the codebase** and live with it.
- One assertion concept per test — easy to read failures.
- Use **fixtures** for setup/teardown.
- Keep tests **deterministic** — never depend on real network or wall clock.

## Production Considerations
- Add **integration tests** in their own job (slower, parallel).
- Track coverage trends in Codecov / Sonar.
- Use **mutation testing** (`mutmut`) to validate test quality on critical modules.
- Parallelize with `pytest-xdist` for large suites.

## Optional Advanced Enhancements
- Add **property-based testing** with `hypothesis` for edge cases.
- Show `pytest --lf` to re-run only last-failed tests.
- Add a **flaky-test detector** that re-runs failed tests N times.
