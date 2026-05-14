# Demo 20 — Kind (Kubernetes IN Docker) Local Clusters

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Single-node cluster
kind create cluster
kubectl get nodes

# 2. Multi-node cluster
kind delete cluster
kind create cluster --config kind-multi-node.yaml
kubectl get nodes -o wide

# 3. Verify the "nodes are Docker containers" claim
docker ps --format 'table {{.Names}}\t{{.Image}}' | grep devops

# 4. Build the FastAPI image and load it
docker build -t devops-app:1.0.0 .
kind load docker-image devops-app:1.0.0 --name devops

# 5. Confirm image is on every node
for n in $(kind get nodes --name devops); do
  echo "==== $n ===="
  docker exec "$n" crictl images | grep devops-app
done

# 6. Switching contexts
kubectl config get-contexts
kubectl config use-context kind-devops

# 7. Cleanup
kind delete cluster --name devops
```

## Prerequisites

- Docker.
- `kind` (https://kind.sigs.k8s.io) and `kubectl` installed.

## Learning Objectives

- Spin up a local Kubernetes cluster in seconds with **Kind**.
- Load locally-built Docker images into the cluster.
- Use multi-node Kind for realistic scheduling demos.

## Concepts Covered

- Kind = each Kubernetes "node" is itself a Docker container.
- `kind create/delete cluster`
- `kind load docker-image` to skip a registry round-trip.
- Cluster contexts in kubeconfig.

## Architecture

```
   Host                                     Docker
   ────                                     ──────
   kubectl ──► localhost:xxxxx ──► [container] kind-control-plane
                                   [container] kind-worker
                                   [container] kind-worker2
                                       └── containerd inside each
```

## Expected Output

```
$ kubectl get nodes -o wide
NAME                   STATUS   ROLES           AGE   VERSION
devops-control-plane   Ready    control-plane   1m    v1.30.0
devops-worker          Ready    <none>          1m    v1.30.0
devops-worker2         Ready    <none>          1m    v1.30.0

$ docker ps --format 'table {{.Names}}\t{{.Image}}' | grep devops
devops-control-plane   kindest/node:v1.30.0
devops-worker          kindest/node:v1.30.0
devops-worker2         kindest/node:v1.30.0
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `failed to create cluster: docker is not running` | Daemon down | Start Docker |
| `image pull backoff` for local image | Forgot `kind load docker-image` | Load it; or use `imagePullPolicy: IfNotPresent` |
| Port already in use on host | Previous Kind cluster still up | `kind delete cluster` |
| Out of memory | Multi-node Kind is heavy | Reduce nodes or increase Docker resources |

## Best Practices

- Use Kind in **CI** (`kind create cluster` in a GitHub Actions job) for
  realistic K8s integration tests.
- Set `imagePullPolicy: IfNotPresent` so Kind reuses loaded images.
- Tag images with the **git SHA** so you can reload deterministically.

## Production Considerations

- Kind is **not** for production. For prod use EKS/GKE/AKS or self-managed
  clusters with proper HA control planes.
- For staging-like local clusters, consider **k3d** (k3s in Docker) — even
  smaller footprint.

## Optional Advanced Enhancements

- Add ingress-nginx ready to use: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`
- Run a Kind cluster inside a GitHub Actions workflow for E2E tests.
- Use `kind export logs` to grab full logs after a failed CI run.


## Real-World Relevance

Kind is the standard local cluster for development and CI. It's used by the
Kubernetes project itself for end-to-end tests. Faster than Minikube, simpler
than k3d in many cases.
