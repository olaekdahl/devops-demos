# Demo 16 — Docker Networking

## Learning Objectives
- Understand the default `bridge` network and `host` mode.
- Create a **user-defined bridge** so containers can find each other by name.
- Publish ports vs link by service name.

## Concepts Covered
- `bridge`, `host`, `none` network modes
- DNS resolution by container name on user-defined networks
- Port mapping (`-p host:container`) vs container-to-container traffic

## Real-World Relevance
Service-to-service communication inside Docker (and inside Kubernetes) relies on
the same idea: each service gets a DNS name. Understanding it on Docker first
makes Kubernetes Services intuitive.

## Demo Architecture
```
   ┌────────────── user-defined bridge "appnet" ──────────────┐
   │                                                          │
   │   [api]:8000  ◄── DNS "api"  ──  [client]                │
   │       │                              │                    │
   │       └── EXPOSE 8000                └── curl http://api:8000/health
   └──────────────────────────────────────────────────────────┘
       host port 8000  ◄── -p 8000:8000  (only api is published)
```

## Instructor Notes
- Show: on the **default** `bridge`, container-by-name DNS does NOT work.
  On a **user-defined** bridge, it does. This is the most common gotcha.
- `host` mode = container shares the host's network namespace; no isolation.

## Prerequisites
- Docker.

## Folder Structure
```
demos/16-docker-networking/
  Dockerfile          (re-uses sample-app)
  app.py
  requirements.txt
```

## Complete Code

Re-use `Dockerfile` from Demo 15 and the sample app.

## Step-by-Step Walkthrough

### 1. Inspect default networks
```bash
docker network ls
docker network inspect bridge | head -30
```

### 2. Default bridge — no DNS by name
```bash
docker run -d --name api  devops-app:1.0.0           # no published port needed for inter-container
docker run --rm curlimages/curl curl -m2 http://api:8000/health
# ► curl: (6) Could not resolve host: api
docker rm -f api
```

### 3. User-defined bridge — DNS works
```bash
docker network create appnet

docker run -d --network appnet --name api devops-app:1.0.0
docker run --rm --network appnet curlimages/curl \
    curl -s http://api:8000/health
# ► {"status":"OK","message":"The application is healthy!"}
```

### 4. Publish to the host
```bash
docker run -d --network appnet --name api2 -p 8000:8000 devops-app:1.0.0
curl localhost:8000/version
```

### 5. Host networking
```bash
docker run -d --network host --name apihost devops-app:1.0.0
ss -tlnp | grep 8000     # port 8000 owned by uvicorn directly on the host
docker rm -f apihost
```

### 6. Inspect a container's IP
```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api
```

### 7. Cleanup
```bash
docker rm -f api api2 2>/dev/null
docker network rm appnet
```

## Expected Output
```
$ docker run --rm --network appnet curlimages/curl curl -s http://api:8000/health
{"status":"OK","message":"The application is healthy!"}

$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api
172.18.0.2
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `Could not resolve host: api` | On the default `bridge` | Create user-defined bridge |
| `port is already allocated` | Two containers `-p 8000:8000` | Use different host ports |
| Cross-container traffic blocked | Containers on different networks | Put them on the same network or use `--network` |
| Host can't reach container | Used `EXPOSE` only, forgot `-p` | `EXPOSE` is metadata; need `-p` |

## DevOps Best Practices
- Always use **user-defined networks** in real deployments.
- Don't publish a port unless the host actually needs it.
- One container, one purpose.

## Production Considerations
- In Kubernetes, every Pod gets its own IP and can be addressed via Service DNS
  — same model, scaled up.
- Network policies (Calico, Cilium) restrict which pods can talk to which.
- For multi-host, use overlay networks (Docker Swarm) or Kubernetes CNI plugins.

## Optional Advanced Enhancements
- `--network none` → fully isolated; no traffic in or out.
- Compare with **Docker Compose** networks (next demo) — same concept, declarative.
- Show NAT chain: `iptables -t nat -L DOCKER` after publishing a port.
