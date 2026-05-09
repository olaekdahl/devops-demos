# Demo 14 — Docker Fundamentals

## Learning Objectives
- Explain what a Linux container actually *is* (namespaces + cgroups), before
  introducing Docker syntax.
- Distinguish images, containers, layers, and the Docker daemon.
- Run a container and inspect it.

## Concepts Covered
- Linux namespaces (`pid`, `net`, `mnt`, `uts`, `ipc`, `user`)
- cgroups (CPU, memory limits)
- Docker engine architecture: client → daemon → containerd → runc
- Image vs container vs registry

## Quick Start
Run the demo end-to-end:

```bash
cd demos/14-docker-fundamentals
# Create a process in its own PID + UTS namespace.
sudo unshare --pid --uts --fork --mount-proc /bin/bash
# Inside that bash:
hostname new-isolated-host        # only changed in this namespace
ps -ef                            # PID 1 is *this* bash
exit
```

## Real-World Relevance
Containers are the unit of deployment everywhere — Kubernetes, ECS, Cloud Run,
Lambda (under the hood). Understanding **what** Docker really gives you (Linux
process isolation in a portable bundle) is foundational.

## Demo Architecture
```
   ┌──────────────────────── Host Linux Kernel ─────────────────────────┐
   │                                                                    │
   │  PID 1 (init) ─► containerd ─► runc ─► pid=42 ─► nginx [container] │
   │                                                  (isolated by NS)  │
   └────────────────────────────────────────────────────────────────────┘
```

A container = a normal Linux process **wrapped in namespaces & cgroups**.
There is no hypervisor; the kernel is shared.

## Instructor Notes
- Show `ps -ef` on host vs `ps -ef` *inside* a container — different process trees.
- Show `unshare` (Linux command) doing 80% of what Docker does, to demystify it.
- Common confusion: containers ≠ VMs. They share the host kernel.

## Prerequisites
- Linux host with Docker installed (`docker --version` ≥ 25).

## Folder Structure
No source files — pure CLI demo.

## Complete Code

Pure shell — every command is the demo.

## Step-by-Step Walkthrough

### 1. Bare Linux: containers without Docker (concept proof)
```bash
# Create a process in its own PID + UTS namespace.
sudo unshare --pid --uts --fork --mount-proc /bin/bash
# Inside that bash:
hostname new-isolated-host        # only changed in this namespace
ps -ef                            # PID 1 is *this* bash
exit
```
Now, `hostname` on the host is unchanged — proving namespaces isolate views.

### 2. Same idea, with Docker
```bash
docker run --rm -it --name nginx-demo -p 8080:80 nginx:alpine
```
Open another terminal:
```bash
docker ps                                            # list running containers
docker exec -it nginx-demo /bin/sh                   # shell INTO container
ps -ef                                               # PID 1 is nginx
hostname                                             # random container ID
ls /                                                 # container's own filesystem
exit
```

### 3. Image vs container
```bash
docker images                       # downloaded images (read-only blueprints)
docker ps                           # running containers (instantiations)
docker ps -a                        # including stopped containers

# Same image, three independent containers
docker run -d --name web1 -p 8081:80 nginx:alpine
docker run -d --name web2 -p 8082:80 nginx:alpine
docker run -d --name web3 -p 8083:80 nginx:alpine
docker ps
```

### 4. Resource limits via cgroups
```bash
docker run -d --name limited \
  --memory=128m --cpus=0.5 nginx:alpine

docker stats limited --no-stream
# MEM USAGE / LIMIT shown ◄─── enforced by Linux cgroups
```

### 5. Cleanup
```bash
docker rm -f $(docker ps -aq) 2>/dev/null
```

## Expected Output
```
$ docker ps
CONTAINER ID  IMAGE         COMMAND                  STATUS         PORTS                  NAMES
a1b2c3d4e5f6  nginx:alpine  "/docker-entrypoint.…"   Up 5 seconds   0.0.0.0:8080->80/tcp   nginx-demo

$ docker exec nginx-demo hostname
a1b2c3d4e5f6
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `permission denied` on docker.sock | User not in `docker` group | `sudo usermod -aG docker $USER` and re-login |
| `port already allocated` | Port collides with host service | Use a different `-p` |
| `unshare: invalid option` | Old util-linux | Update package or run a Docker container instead |
| Container exits immediately | Default CMD finished | `docker logs <name>` to see why |

## DevOps Best Practices
- **One process per container** — easier to scale and observe.
- Use **minimal base images** (`alpine`, `distroless`).
- Always set explicit **tags** (`nginx:alpine` not `nginx:latest`).
- Always set **resource limits** in production.

## Production Considerations
- Run as **non-root** inside the container.
- Read-only root filesystem (`--read-only`).
- Drop Linux capabilities (`--cap-drop=ALL --cap-add=NET_BIND_SERVICE`).
- Use **rootless Docker** or `podman` for stronger isolation.

## Optional Advanced Enhancements
- Use `nsenter` to enter a container's namespaces from the host.
- Show `docker inspect` and pull out `.State.Pid`, then `ls /proc/<pid>/ns/`.
- Compare container size vs VM size (10s of MB vs GB).
