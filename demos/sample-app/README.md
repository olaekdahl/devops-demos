# Shared Sample App — DevOps Demo

Tiny FastAPI service used across demos 09 → 38. One file (`app.py`),
no DB, no external services. Endpoints: `/`, `/health`, `/version`,
`/env`, `/tips`, `/login`, `/logout`.

## Quick start

```bash
make install   # create venv + install deps
make run       # http://localhost:8000  (Ctrl+C to stop)

# Tests
make dev       # install dev deps
make test      # run pytest
make cov       # with coverage

# Docker
make docker        # build image -> devops-demo-app:local
make docker-run    # run on :8000
```

## Manual (no make)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000

# tests
pip install -r requirements-dev.txt
PYTHONPATH=. pytest -v tests/
```

## Env vars (read by `/env`)

| Var | Default |
|---|---|
| `APP_NAME` | `DevOps Demo App` |
| `ENVIRONMENT` | `dev` |
| `SECRET_KEY` | `not-set` |
