#!/usr/bin/env bash
# Extracted commands from 14-docker-fundamentals.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# Create a process in its own PID + UTS namespace.
sudo unshare --pid --uts --fork --mount-proc /bin/bash
# Inside that bash:

# --- next block ---

# Create a process in its own PID + UTS namespace.
sudo unshare --pid --uts --fork --mount-proc /bin/bash
# Inside that bash:

# --- next block ---

docker run --rm -it --name nginx-demo -p 8080:80 nginx:alpine

# --- next block ---

docker ps                                            # list running containers
docker exec -it nginx-demo /bin/sh                   # shell INTO container
ls /                                                 # container's own filesystem

# --- next block ---

docker images                       # downloaded images (read-only blueprints)
docker ps                           # running containers (instantiations)
docker ps -a                        # including stopped containers

# Same image, three independent containers
docker run -d --name web1 -p 8081:80 nginx:alpine
docker run -d --name web2 -p 8082:80 nginx:alpine
docker run -d --name web3 -p 8083:80 nginx:alpine
docker ps

# --- next block ---

docker run -d --name limited \

docker stats limited --no-stream
# MEM USAGE / LIMIT shown ◄─── enforced by Linux cgroups

# --- next block ---

docker rm -f $(docker ps -aq) 2>/dev/null