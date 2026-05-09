#!/usr/bin/env bash
# Extracted commands from 18-docker-compose.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

cd .
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

# --- next block ---

cd .
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