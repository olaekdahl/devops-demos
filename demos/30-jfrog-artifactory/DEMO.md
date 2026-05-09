# Demo 30 — jFrog Artifactory

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
INITIALS=oe                                 # your initials
ARTIFACTORY_URL=mycompany.jfrog.io
REPO=devops-docker-local

# 1. Build local
docker build -t devops-app:1.0.0 .

# 2. Login to Artifactory
echo "$ARTIFACTORY_TOKEN" | docker login "$ARTIFACTORY_URL" -u "$ARTIFACTORY_USER" --password-stdin

# 3. Tag & push
IMAGE="$ARTIFACTORY_URL/$REPO/${INITIALS}-devops:1.0.0"
docker tag devops-app:1.0.0 "$IMAGE"
docker push "$IMAGE"

# 4. Verify via the JFrog UI (or REST):
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" \
  "https://$ARTIFACTORY_URL/artifactory/api/repositories/$REPO"

# 5. Create K8s pull secret
ARTIFACTORY_USER="$ARTIFACTORY_USER" ARTIFACTORY_TOKEN="$ARTIFACTORY_TOKEN" \
  ARTIFACTORY_URL="$ARTIFACTORY_URL" bash pull-secret.sh

# 6. Deploy
sed -e "s|__ARTIFACTORY_URL__|$ARTIFACTORY_URL|" \
    -e "s|__REPO__|$REPO|" \
    -e "s|__INITIALS__|$INITIALS|" \
    deployment.yaml | kubectl apply -f -

kubectl rollout status deployment/devops-app
kubectl get svc devops-app-svc
```

## Prerequisites

- Docker, Kubernetes (Kind or EKS).
- Artifactory URL, repo, username, and access token from the lab.

## Learning Objectives

- Authenticate to a JFrog Artifactory Docker registry.
- Tag and push the FastAPI image into Artifactory (matches Lab 4.3).
- Pull from Artifactory in Kubernetes via `imagePullSecrets`.

## Concepts Covered

- Artifactory as a multi-format binary repo (Docker, Maven, npm, generic).
- Repository naming `<artifactory-url>/<repo>/<image>:<tag>`
- `docker login` with Artifactory access token
- K8s pull secret of type `dockerconfigjson`

## Architecture

```
   docker push ──► Artifactory  ──► K8s pull (imagePullSecrets)
                       │
                       └── proxies docker.io, etc., for cached pulls
```

## Expected Output

```
$ docker push mycompany.jfrog.io/devops-docker-local/oe-devops:1.0.0
The push refers to repository [mycompany.jfrog.io/devops-docker-local/oe-devops]
1.0.0: digest: sha256:abc... size: 1456

$ kubectl describe pod -l app=devops-app | grep -A2 Events
Events:
  Type    Reason     Age   From    Message
  Normal  Pulled     5s    kubelet Successfully pulled image "mycompany.jfrog.io/.../oe-devops:1.0.0"
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unauthorized: bad credentials` on push | Wrong token / repo | Verify token, repo name |
| `ImagePullBackOff` in K8s | Pull secret missing or wrong | Re-run `pull-secret.sh`; check secret namespace |
| Slow first pull | Image not cached on node | Normal; subsequent pulls fast |
| `manifest unknown` | Tag mismatch | Re-list with `curl ...` to UI/REST |

## Best Practices

- Push from CI, not from laptops. (See Demo 32 capstone.)
- One repo per **environment lifecycle** (e.g., `docker-dev-local`,
  `docker-prod-local`) with promotion between them.
- Set retention policies — old tags accumulate fast.
- Enable **Xray** (JFrog) for vulnerability scanning at push time.

## Production Considerations

- Use **virtual repos** in front of multiple physical repos for stable URLs.
- Configure **replication** between Artifactory instances for DR.
- Federate auth (SAML/OIDC).
- Use **fine-grained access tokens** scoped to a single repo.

## Optional Advanced Enhancements

- Show JFrog Xray scan results blocking a push (policy = block on critical CVE).
- Promote an image from `docker-dev-local` → `docker-prod-local` via REST API.
- Configure Artifactory as a **pull-through cache** for Docker Hub.

## Instructor Notes

- Get the Artifactory URL, repo name, and access token from your instructor
  (lab provides these).
- Stress: Artifactory tokens are long-lived. Treat as secrets.
- Show **virtual repos** (a single endpoint that fronts proxy + local repos) —
  this is the magic that makes Artifactory more than a registry.

## Real-World Relevance

Artifactory and Nexus are the two most common enterprise binary repos. They
provide a single audited place for ALL build outputs (containers, libs,
binaries) plus virtual/remote repos for proxying public registries.
