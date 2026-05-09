#!/usr/bin/env bash
# Extracted commands from 15-docker-build-process.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

cd .
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