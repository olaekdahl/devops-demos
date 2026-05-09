# Demo 29 — Container Registries

## Learning Objectives
- Explain what an OCI registry is and how the push/pull protocol works.
- Tag, push, and pull from Docker Hub, GHCR, and a generic registry.
- Use immutable tags + digests.

## Concepts Covered
- Registry vs repository vs image vs tag vs digest
- `docker login`, `docker tag`, `docker push`, `docker pull`
- Public vs private; auth via token
- Pulling by digest for reproducibility

## Real-World Relevance
Every container goes through a registry on the way to production. Choice of
registry (Docker Hub, ECR, GHCR, GAR, Artifactory) matters for cost, security,
geo, and integration.

## Demo Architecture
```
   build → docker tag → docker push ──► [Registry]
                                            │
   K8s/runtime ◄── docker pull (or kubelet) ──┘
```

## Instructor Notes
- Many students conflate "image" with "image:tag". Show the same image with
  multiple tags pointing to the same SHA256 digest.
- Show `imagePullPolicy` interaction: `latest` defaults to `Always`; explicit
  tags default to `IfNotPresent`. Always pin to a digest in prod for true immutability.

## Prerequisites
- Docker.
- A free Docker Hub account; or a GHCR token; or a JFrog token.

## Folder Structure
```
demos/29-container-registries/
  Dockerfile, app.py, requirements.txt   (re-used)
```

## Complete Code

Re-use the sample app + Dockerfile from Demo 15.

## Step-by-Step Walkthrough

### Push to Docker Hub
```bash
cd demos/29-container-registries
docker build -t devops-app:1.0.0 .

docker login                                      # username + token (NOT password)

docker tag  devops-app:1.0.0  <user>/devops-app:1.0.0
docker tag  devops-app:1.0.0  <user>/devops-app:latest

docker push <user>/devops-app:1.0.0
docker push <user>/devops-app:latest
```

### Push to GitHub Container Registry (GHCR)
```bash
echo "$GITHUB_PAT" | docker login ghcr.io -u <github-user> --password-stdin
docker tag  devops-app:1.0.0  ghcr.io/<github-user>/devops-app:1.0.0
docker push ghcr.io/<github-user>/devops-app:1.0.0
```

### Inspect the digest and pull by digest (true immutability)
```bash
docker inspect --format='{{index .RepoDigests 0}}' <user>/devops-app:1.0.0
# ► <user>/devops-app@sha256:abc123...

# Pull by digest — guaranteed bit-identical to what you pushed.
docker pull <user>/devops-app@sha256:abc123...
```

### Use the pushed image from Kubernetes
```yaml
spec:
  containers:
    - name: app
      image: <user>/devops-app@sha256:abc123...
      imagePullPolicy: IfNotPresent
```

### Multi-arch images (preview)
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <user>/devops-app:1.0.0 --push .
```

## Expected Output
```
$ docker push <user>/devops-app:1.0.0
The push refers to repository [docker.io/<user>/devops-app]
abc123... Pushed
1.0.0: digest: sha256:abc123def... size: 1234

$ docker inspect --format='{{index .RepoDigests 0}}' <user>/devops-app:1.0.0
<user>/devops-app@sha256:abc123def...
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `denied: requested access to the resource is denied` | Wrong namespace / missing repo | Login as correct user; create repo or use accessible namespace |
| `manifest unknown` | Wrong tag/registry | Verify tag exists; check spelling |
| Slow pulls | Cross-region / rate-limited | Use a registry mirror or in-region cache |
| `unauthorized` from K8s | Missing `imagePullSecrets` | Create a `dockerconfigjson` Secret (Demo 27) |

## DevOps Best Practices
- **Pin by digest** in production manifests, not by tag.
- Sign images with **cosign**, verify in admission controllers (Sigstore policy controller).
- Push **SBOMs** (Syft) and scan with Trivy in CI.
- Tag with both immutable (`git-sha`) and movable (`latest`, `1.0`) tags.

## Production Considerations
- Use a registry **near** your cluster (ECR in same region) for fast/cheap pulls.
- **Replicate** between regions for DR.
- Enforce **image provenance** (SLSA) and **vulnerability gates**.
- Garbage-collect old tags to control storage cost.

## Optional Advanced Enhancements
- Build & push from GitHub Actions using `docker/build-push-action`.
- Set up a **pull-through cache** to Docker Hub to bypass anonymous rate limits.
- Demonstrate **OCI artifacts** (storing Helm charts / SBOMs in the same registry).
