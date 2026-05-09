# Demo 17 — Docker Debugging

## Learning Objectives
- Use `docker logs`, `docker exec`, `docker inspect`, `docker top` to debug.
- Diagnose CrashLoopBackOff-style failures (container exits immediately).
- Use `docker run --rm -it ... sh` for ad-hoc debugging.

## Concepts Covered
- Stdout/stderr → `docker logs`
- Live shell into a container
- Inspecting container metadata (state, mounts, networks)
- Common failures: bad CMD, missing file, port conflict, crash loop

## Real-World Relevance
Every container engineer spends 30% of their time debugging containers.
Knowing the four commands above instinctively is a force multiplier.

## Demo Architecture
```
  Container fails ──► docker ps -a   (find ID)
                  ├─► docker logs    (why did it die?)
                  ├─► docker inspect (full state)
                  └─► docker run -it <image> sh   (poke around)
```

## Instructor Notes
- Provide a *deliberately broken* image and let students debug.
- Walk through the **5 most common failure modes** (table below) one by one.
- Stress: `docker logs` of a crashed container shows the *last* run's output.

## Prerequisites
- Docker, sample app.

## Folder Structure
```
demos/17-docker-debugging/
  Dockerfile.broken1   # missing CMD module
  Dockerfile.broken2   # wrong port binding
  Dockerfile.broken3   # missing file
  app.py
  requirements.txt
```

## Complete Code

Re-use `app.py` and `requirements.txt` from sample-app.

`Dockerfile.broken1` — "module not found"
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# BUG: app module name is wrong (apps vs app)
CMD ["uvicorn", "apps:app", "--host", "0.0.0.0", "--port", "8000"]
```

`Dockerfile.broken2` — "port mismatch"
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 3000
# BUG: app listens on 8000, container exposes 3000.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`Dockerfile.broken3` — "missing file"
```dockerfile
FROM python:3.12-slim
WORKDIR /app
# BUG: forgot to COPY requirements.txt before RUN pip install
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Step-by-Step Walkthrough

### Failure 1: bad CMD module
```bash
docker build -f Dockerfile.broken1 -t bad1 .
docker run -d --name bad1 -p 8000:8000 bad1
docker ps -a                           # status: Exited (1)
docker logs bad1
# ► ERROR: Error loading ASGI app. Could not import module "apps".
docker rm bad1
```
Fix: change CMD to `app:app`. Rebuild, run, success.

### Failure 2: port mismatch
```bash
docker build -f Dockerfile.broken2 -t bad2 .
docker run -d --name bad2 -p 3000:3000 bad2
docker logs bad2                        # uvicorn says "listening on 8000"
curl localhost:3000/health              # CONNECTION REFUSED
# Diagnosis: app inside listens on 8000, but host port 3000 maps to container 3000
docker rm -f bad2
docker run -d --name bad2 -p 3000:8000 bad2     # remap host->container
curl localhost:3000/health              # works
```

### Failure 3: missing build file
```bash
docker build -f Dockerfile.broken3 -t bad3 .
# ► ERROR: requirements.txt: No such file or directory
# Fix: ensure COPY requirements.txt . happens BEFORE the RUN pip install
```

### General debugging toolbox
```bash
# Live tail of logs
docker logs -f --tail=50 <container>

# Shell into a running container
docker exec -it <container> /bin/sh
ls -l /app
ps -ef
env

# Inspect everything
docker inspect <container> | less
docker top <container>

# Network view
docker port <container>
docker inspect -f '{{json .NetworkSettings}}' <container> | jq .

# Run an "ephemeral debug pod" with the same image
docker run --rm -it --entrypoint /bin/sh devops-app:1.0.0
```

## Expected Output
```
$ docker logs bad1
INFO:     Started server process [1]
ERROR:    Error loading ASGI app. Could not import module "apps".

$ docker exec -it api /bin/sh
/ # ls /app
app.py  requirements.txt  ...
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Exits immediately | Bad CMD or missing dep | `docker logs` |
| Container running but unreachable | Wrong port mapping | `docker port` then re-`-p` |
| `OCI runtime exec failed: exec: "/bin/sh"` | Distroless image (no shell) | Use a debug sidecar or `docker cp` files out |
| Logs empty | App writes to a file, not stdout | Make app log to stdout (12-factor) |
| Out of disk | Old images & layers | `docker system prune -af --volumes` |

## DevOps Best Practices
- **Log to stdout/stderr**, never to a file inside the container.
- Add a `HEALTHCHECK` to your Dockerfile for early failure detection.
- Tag images per build (`devops-app:git-sha`) so `docker logs` correlates with code.
- Keep a tiny **debug image** with `curl/dig/ps` for ephemeral troubleshooting.

## Production Considerations
- Use **Kubernetes ephemeral debug containers** (`kubectl debug`) — same model.
- Centralize logs (CloudWatch, Loki, Splunk).
- Use **OpenTelemetry** for traces; logs alone aren't enough.

## Optional Advanced Enhancements
- Add a `HEALTHCHECK` instruction; show `docker ps` STATUS column include health.
- Use `docker events` in a second terminal to watch container lifecycle live.
- `docker run --init` to reap zombie processes correctly.
