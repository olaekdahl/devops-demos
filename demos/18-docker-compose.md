# Demo 18 — Docker Compose

## Learning Objectives
- Define a multi-service app declaratively in `compose.yaml`.
- `docker compose up`, `down`, `logs`, `ps`.
- Compose networks, volumes, env files.

## Concepts Covered
- Declarative vs imperative container management
- Services, networks, volumes
- `depends_on`, healthchecks
- `.env` files and variable substitution

## Quick Start
Run the demo end-to-end:

```bash
cd demos/18-docker-compose
mkdir -p demos/18-docker-compose && cd demos/18-docker-compose
# (create the files above)

# Build & start everything
docker compose up -d --build

# Inspect
docker compose ps
docker compose logs -f app

# Hit the API
curl localhost:8000/health
curl localhost:8000/visit
curl localhost:8000/visit
curl localhost:8000/visit

# Restart only the app (not db/cache)
docker compose restart app

# Tear down (keep volume)
docker compose down

# Tear down + remove volume (wipe data)
docker compose down -v
```

## Real-World Relevance
For local dev, Compose is the de facto standard: spin up your app + DB + cache
+ message queue with one command. In CI it's used for integration test rigs.

## Demo Architecture
```
  ┌────── compose.yaml ──────┐
  │                          │
  │  app  ──► db (postgres)  │
  │       └─► cache (redis)  │
  │                          │
  │  port 8000:8000          │   ◄── only "app" published to host
  └──────────────────────────┘
```

## Instructor Notes
- Modern syntax: file is `compose.yaml`, command is `docker compose ...` (no
  hyphen). Older `docker-compose` works but is legacy.
- Show that `depends_on` ensures *start order*, not *readiness*. Use a
  healthcheck for true readiness.

## Prerequisites
- Docker Desktop OR Docker engine + `docker compose` plugin.

## Folder Structure
```
demos/18-docker-compose/
  compose.yaml
  Dockerfile
  app.py            (extended to talk to db + redis)
  requirements.txt
  .env
```

## Complete Code

`requirements.txt`
```
fastapi
uvicorn
psycopg[binary]
redis
```

`app.py`
```python
import os
import psycopg
import redis
from fastapi import FastAPI

app = FastAPI()
DB_DSN = os.getenv("DB_DSN", "postgresql://app:app@db:5432/app")
RDS_HOST = os.getenv("REDIS_HOST", "cache")

r = redis.Redis(host=RDS_HOST, port=6379, decode_responses=True)


@app.get("/")
def root():
    return {"msg": "compose demo", "endpoints": ["/health", "/visit"]}


@app.get("/health")
def health():
    # Verifies app + Postgres + Redis all reachable.
    with psycopg.connect(DB_DSN) as conn:
        conn.execute("SELECT 1").fetchone()
    r.ping()
    return {"status": "OK"}


@app.get("/visit")
def visit():
    n = r.incr("visits")
    return {"visits": n}
```

`Dockerfile`
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`.env`
```
POSTGRES_USER=app
POSTGRES_PASSWORD=app
POSTGRES_DB=app
```

`compose.yaml`
```yaml
# Compose Spec — no top-level 'version:' needed in modern Compose.
services:

  app:
    build: .                     # build from local Dockerfile
    image: devops-app:compose
    ports:
      - "8000:8000"              # host:container
    environment:
      DB_DSN: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_HOST: cache
    depends_on:
      db:    { condition: service_healthy }
      cache: { condition: service_started }
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 5s
      timeout: 3s
      retries: 5

  cache:
    image: redis:7-alpine
    # No published port — only reachable from inside the compose network.

volumes:
  dbdata:
```

## Step-by-Step Walkthrough
```bash
mkdir -p demos/18-docker-compose && cd demos/18-docker-compose
# (create the files above)

# Build & start everything
docker compose up -d --build

# Inspect
docker compose ps
docker compose logs -f app

# Hit the API
curl localhost:8000/health
curl localhost:8000/visit
curl localhost:8000/visit
curl localhost:8000/visit

# Restart only the app (not db/cache)
docker compose restart app

# Tear down (keep volume)
docker compose down

# Tear down + remove volume (wipe data)
docker compose down -v
```

## Expected Output
```
$ docker compose ps
NAME                IMAGE                 STATUS               PORTS
compose-app-1       devops-app:compose    Up (healthy)         0.0.0.0:8000->8000/tcp
compose-cache-1     redis:7-alpine        Up
compose-db-1        postgres:16-alpine    Up (healthy)         5432/tcp

$ curl localhost:8000/visit
{"visits":1}
$ curl localhost:8000/visit
{"visits":2}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `app` exits — `connection refused db:5432` | DB not ready when app started | Add `depends_on.condition: service_healthy` + healthcheck |
| `KeyError: POSTGRES_USER` | Forgot `.env` file | Create it; or use `--env-file` |
| Volume data persists across recreates unexpectedly | Compose preserves named volumes | `docker compose down -v` to wipe |
| Port conflict | Host already running Postgres | Change host port mapping (`5433:5432`) |

## DevOps Best Practices
- One Compose file per app, in the repo root.
- Use `.env` for environment-specific values; never commit secrets.
- Pin image tags (`postgres:16-alpine`, not `postgres:latest`).
- Use **healthchecks** so `depends_on` actually waits for readiness.

## Production Considerations
- Compose is for **dev/test/CI**, not for prod multi-host.
- For prod, translate Compose → Kubernetes manifests (Demos 21+) using **kompose**
  or rewrite manually.
- Use **profiles** (`profiles: ["dev"]`) to skip services in CI.

## Optional Advanced Enhancements
- Add a **second app instance** + simple nginx for round-robin LB:
  ```yaml
  app:  { deploy: { replicas: 3 } }       # requires Swarm mode
  ```
- Use **Compose watch mode**: `docker compose watch` to auto-rebuild on file changes.
- Add a **Compose-based integration test** stage in your GitHub Actions workflow.
