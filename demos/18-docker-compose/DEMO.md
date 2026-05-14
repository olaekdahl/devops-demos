# Demo 18 — Docker Compose

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
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

## Prerequisites

- Docker Desktop OR Docker engine + `docker compose` plugin.

## Learning Objectives

- Define a multi-service app declaratively in `compose.yaml`.
- `docker compose up`, `down`, `logs`, `ps`.
- Compose networks, volumes, env files.

## Concepts Covered

- Declarative vs imperative container management
- Services, networks, volumes
- `depends_on`, healthchecks
- `.env` files and variable substitution

## Architecture

```
  ┌────── compose.yaml ──────┐
  │                          │
  │  app  ──► db (postgres)  │
  │       └─► cache (redis)  │
  │                          │
  │  port 8000:8000          │   ◄── only "app" published to host
  └──────────────────────────┘
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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `app` exits — `connection refused db:5432` | DB not ready when app started | Add `depends_on.condition: service_healthy` + healthcheck |
| `KeyError: POSTGRES_USER` | Forgot `.env` file | Create it; or use `--env-file` |
| Volume data persists across recreates unexpectedly | Compose preserves named volumes | `docker compose down -v` to wipe |
| Port conflict | Host already running Postgres | Change host port mapping (`5433:5432`) |

## Best Practices

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


## Real-World Relevance

For local dev, Compose is the de facto standard: spin up your app + DB + cache
+ message queue with one command. In CI it's used for integration test rigs.
