#!/usr/bin/env bash
# Extracted commands from 16-docker-networking.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

docker network ls
docker network inspect bridge | head -30

# --- next block ---

docker network ls
docker network inspect bridge | head -30

# --- next block ---

docker run -d --name api  devops-app:1.0.0           # no published port needed for inter-container
docker run --rm curlimages/curl curl -m2 http://api:8000/health
# ► curl: (6) Could not resolve host: api
docker rm -f api

# --- next block ---

docker network create appnet

docker run -d --network appnet --name api devops-app:1.0.0
docker run --rm --network appnet curlimages/curl \
    curl -s http://api:8000/health
# ► {"status":"OK","message":"The application is healthy!"}

# --- next block ---

docker run -d --network appnet --name api2 -p 8000:8000 devops-app:1.0.0
curl localhost:8000/version

# --- next block ---

docker run -d --network host --name apihost devops-app:1.0.0
ss -tlnp | grep 8000     # port 8000 owned by uvicorn directly on the host
docker rm -f apihost

# --- next block ---

docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api

# --- next block ---

docker rm -f api api2 2>/dev/null
docker network rm appnet