# Demo 15 — Docker Build Process

## Learning Objectives
- Author a `Dockerfile` for the FastAPI sample app.
- Understand image layers and how the build cache works.
- Use a `.dockerignore` to keep images small and fast.

## Concepts Covered
- `FROM`, `WORKDIR`, `COPY`, `RUN`, `CMD`, `EXPOSE`
- Layer caching: order matters
- Multi-stage builds (preview)
- `.dockerignore`

## Real-World Relevance
Every containerized app has a `Dockerfile`. A well-ordered one cuts CI build
times from minutes to seconds and keeps images small (less attack surface,
faster pulls).

## Demo Architecture
```
   Dockerfile                           Image (read-only layers)
   ──────────                           ──────────────────────────
   FROM python:3.12-slim   ───layer 1───  base OS + Python
   COPY requirements.txt   ───layer 2───  deps file
   RUN pip install -r ...  ───layer 3───  installed packages   ◄── cache hit if requirements.txt unchanged
   COPY . .                ───layer 4───  app source
   CMD [...]                              metadata only (no layer)
```

## Instructor Notes
- Show that changing `app.py` triggers re-build of layer 4 only — layers 1–3
  are cached. Then change `requirements.txt` to invalidate from layer 2 down.
- Live-show `docker history <image>` to see layer sizes.

## Prerequisites
- Docker installed. Sample app from `demos/sample-app/`.

## Folder Structure
```
demos/15-docker-build-process/
  app.py
  requirements.txt
  Dockerfile
  .dockerignore
```

## Complete Code

`Dockerfile` (single-stage — matches Lab 4.1)
```dockerfile
# Use the official slim Python image — small, well-maintained.
FROM python:3.12-slim

# All subsequent commands run from /app.
WORKDIR /app

# 1) Copy ONLY requirements first → cache-friendly layer.
COPY requirements.txt .

# 2) Install deps. --no-cache-dir keeps the image small.
RUN pip install --no-cache-dir -r requirements.txt

# 3) Copy the rest of the source (this layer changes most often).
COPY . .

# Document the port; does NOT publish it (that's `-p` on `docker run`).
EXPOSE 8000

# Run as a non-root user (security best practice).
RUN useradd --create-home --shell /bin/bash app && chown -R app /app
USER app

# Default command: launch FastAPI via uvicorn.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

`.dockerignore`
```
__pycache__/
*.pyc
.venv/
venv/
.git/
.github/
tests/
*.md
.dockerignore
Dockerfile
```

## Step-by-Step Walkthrough
```bash
mkdir -p demos/15-docker-build-process && cd demos/15-docker-build-process
cp ../sample-app/app.py ../sample-app/requirements.txt .
# create Dockerfile and .dockerignore above

# 1. Build
docker build -t devops-app:1.0.0 .

# 2. Inspect layers
docker history devops-app:1.0.0
docker image ls devops-app

# 3. Re-build with NO source change → all layers cached, near-instant.
docker build -t devops-app:1.0.0 .

# 4. Touch app.py → only the COPY/CMD layers rebuild.
echo "# trivial change" >> app.py
docker build -t devops-app:1.0.0 .         # fast

# 5. Touch requirements.txt → cache invalidates from that layer onward.
echo "" >> requirements.txt
docker build -t devops-app:1.0.0 .         # slower

# 6. Run it
docker run -d -p 8000:8000 --name app devops-app:1.0.0
curl localhost:8000/health
docker logs app
docker rm -f app
```

## Expected Output
```
$ docker build -t devops-app:1.0.0 .
[+] Building 18.2s (10/10) FINISHED
 => [internal] load build definition
 => [1/5] FROM docker.io/library/python:3.12-slim
 => [2/5] WORKDIR /app
 => [3/5] COPY requirements.txt .
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY . .
 => exporting to image
 => => writing image sha256:abc123...

$ docker history devops-app:1.0.0
IMAGE          CREATED         CREATED BY                                       SIZE
abc123...      5 seconds ago   CMD ["uvicorn" "app:app" "--host" "0.0.0.0"...   0B
<missing>      5 seconds ago   USER app                                         0B
<missing>      5 seconds ago   RUN useradd --create-home...                     3.5kB
<missing>      8 seconds ago   COPY . .                                         48kB
<missing>      12 seconds ago  RUN pip install --no-cache-dir...                42MB
<missing>      18 seconds ago  COPY requirements.txt .                          22B
<missing>      2 weeks ago     /bin/sh -c #(nop) WORKDIR /app                   0B
<missing>      2 weeks ago     /bin/sh -c #(nop) FROM python:3.12-slim          120MB

$ curl localhost:8000/health
{"status":"OK","message":"The application is healthy!"}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Image > 1 GB | Built `FROM python:3.12` (full) instead of `slim` | Use `-slim` or `-alpine` |
| Build cache never hits | `COPY . .` placed before `pip install` | Move `requirements.txt` copy first |
| `permission denied` writing files | Switched to non-root before `chown` | Reorder: chown then USER |
| Port 8000 unreachable | Forgot `-p 8000:8000` on `docker run` | Add it |

## DevOps Best Practices
- Order layers from **least to most frequently changing**.
- Pin base image versions: `python:3.12-slim` not `python:latest`.
- Always include a `.dockerignore` (smaller, faster, safer).
- Run as **non-root**.

## Production Considerations
- **Multi-stage builds** for compiled apps (preview):
  ```dockerfile
  FROM python:3.12 AS build
  RUN pip wheel --wheel-dir /wheels -r requirements.txt
  FROM python:3.12-slim
  COPY --from=build /wheels /wheels
  RUN pip install --no-index --find-links /wheels fastapi uvicorn
  ```
- Sign images with **cosign**, scan with **Trivy/Grype**, generate **SBOMs**.
- Use **Distroless** (no shell) base for prod.

## Optional Advanced Enhancements
- BuildKit cache mounts: `RUN --mount=type=cache,target=/root/.cache/pip pip install ...`.
- `docker buildx bake` for multi-platform (linux/amd64, linux/arm64) builds.
- Show image scanning: `docker scout cves devops-app:1.0.0`.
