#!/usr/bin/env bash
# Extracted commands from 17-docker-debugging.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

docker build -f Dockerfile.broken1 -t bad1 .
docker run -d --name bad1 -p 8000:8000 bad1
docker ps -a                           # status: Exited (1)
docker logs bad1
# ► ERROR: Error loading ASGI app. Could not import module "apps".
docker rm bad1

# --- next block ---

docker build -f Dockerfile.broken2 -t bad2 .
docker run -d --name bad2 -p 3000:3000 bad2
docker logs bad2                        # uvicorn says "listening on 8000"
curl localhost:3000/health              # CONNECTION REFUSED
# Diagnosis: app inside listens on 8000, but host port 3000 maps to container 3000
docker rm -f bad2
docker run -d --name bad2 -p 3000:8000 bad2     # remap host->container
curl localhost:3000/health              # works

# --- next block ---

docker build -f Dockerfile.broken3 -t bad3 .
# ► ERROR: requirements.txt: No such file or directory
# Fix: ensure COPY requirements.txt . happens BEFORE the RUN pip install

# --- next block ---

# Live tail of logs
# docker logs -f --tail=50 <container>  # contains <placeholder> — edit before running

# Shell into a running container
# docker exec -it <container> /bin/sh  # contains <placeholder> — edit before running
ls -l /app
env

# Inspect everything
# docker inspect <container> | less  # contains <placeholder> — edit before running
# docker top <container>  # contains <placeholder> — edit before running

# Network view
# docker port <container>  # contains <placeholder> — edit before running
# docker inspect -f '{{json .NetworkSettings}}' <container> | jq .  # contains <placeholder> — edit before running

# Run an "ephemeral debug pod" with the same image
docker run --rm -it --entrypoint /bin/sh devops-app:1.0.0