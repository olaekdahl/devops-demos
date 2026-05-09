#!/usr/bin/env bash
# Extracted commands from 29-container-registries.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

docker build -t devops-app:1.0.0 .

docker login                                      # username + token (NOT password)

# docker tag  devops-app:1.0.0  <user>/devops-app:1.0.0  # contains <placeholder> — edit before running
# docker tag  devops-app:1.0.0  <user>/devops-app:latest  # contains <placeholder> — edit before running

# docker push <user>/devops-app:1.0.0  # contains <placeholder> — edit before running
# docker push <user>/devops-app:latest  # contains <placeholder> — edit before running

# --- next block ---

# echo "$GITHUB_PAT" | docker login ghcr.io -u <github-user> --password-stdin  # contains <placeholder> — edit before running
# docker tag  devops-app:1.0.0  ghcr.io/<github-user>/devops-app:1.0.0  # contains <placeholder> — edit before running
# docker push ghcr.io/<github-user>/devops-app:1.0.0  # contains <placeholder> — edit before running

# --- next block ---

# docker inspect --format='{{index .RepoDigests 0}}' <user>/devops-app:1.0.0  # contains <placeholder> — edit before running
# ► <user>/devops-app@sha256:abc123...

# Pull by digest — guaranteed bit-identical to what you pushed.
# docker pull <user>/devops-app@sha256:abc123...  # contains <placeholder> — edit before running

# --- next block ---

docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \