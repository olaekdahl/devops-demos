# Demo 19 — Kubernetes Fundamentals

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# What's running?
kubectl get nodes
kubectl get pods -A                         # all namespaces — see control plane

# Where the API server lives
kubectl config view --minify

# A controller in action: create a deployment, kill a pod, watch it return.
kubectl create deployment web --image=nginx:alpine --replicas=3
kubectl get pods -l app=web
POD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD
kubectl get pods -l app=web -w              # a new pod appears within seconds

# Cleanup
kubectl delete deployment web
```

## Prerequisites

- None for the conceptual portion.
- For the live walk: `kubectl` installed; any cluster (Kind from Demo 20 works).

## Learning Objectives

- Articulate **why** Kubernetes exists (the orchestration problem).
- Identify the major components of the control plane and worker nodes.
- Understand the declarative model: "I want N replicas of X" → controllers
  reconcile reality.

## Concepts Covered

- Orchestration problems: scheduling, self-healing, scaling, rolling updates,
  service discovery, secret/config delivery.
- **Control plane**: API server, etcd, scheduler, controller-manager, cloud-controller-manager.
- **Worker node**: kubelet, container runtime (containerd), kube-proxy.
- Core objects: Pod, ReplicaSet, Deployment, Service, Namespace.
- Declarative reconciliation loop.

## Architecture

```
            ┌─────────────────────── Control Plane ───────────────────────┐
            │                                                             │
            │  kubectl ─► API Server ─► etcd                              │
            │                  ▲    ▲                                     │
            │                  │    └── Scheduler (assigns pods → nodes)  │
            │                  └────── Controller Manager (reconciles)    │
            └──────────────────┬──────────────────────────────────────────┘
                               │ watches
            ┌──────────────────┴───────────── Worker Node ─────────────────┐
            │   kubelet  ◄── runs Pods ◄── containerd                      │
            │   kube-proxy (networking, iptables/ipvs)                     │
            └──────────────────────────────────────────────────────────────┘
```

## Walkthrough

### 3. Object hierarchy
```
Deployment ─owns─► ReplicaSet ─owns─► Pod ─runs─► container(s)
```

## Expected Output

```
$ kubectl get nodes
NAME                  STATUS   ROLES           AGE   VERSION
kind-control-plane    Ready    control-plane   2m    v1.30.0

$ kubectl get pods -l app=web
NAME                   READY   STATUS    RESTARTS   AGE
web-7d4d8b8f9b-2k4xk   1/1     Running   0          12s
web-7d4d8b8f9b-q9hcm   1/1     Running   0          12s
web-7d4d8b8f9b-x7m2t   1/1     Running   0          12s
```

After deleting one pod, you'll see a new one with a different suffix appear.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `The connection to the server was refused` | No cluster context | `kind create cluster` (Demo 20) |
| Pod stays `Pending` | No node has resources / wrong nodeSelector | `kubectl describe pod` → Events |
| Pod CrashLoopBackOff | App crashing on start | `kubectl logs` |
| `forbidden` errors | RBAC denies your user | Use `kubectl auth can-i ...` |

## Best Practices

- **Always** use Deployments, never bare Pods for app workloads.
- Manage manifests in **Git** (GitOps).
- Use **namespaces** to isolate teams/environments.
- Apply **resource requests & limits** to every container.

## Production Considerations

- Multi-node, multi-AZ control plane (managed services do this for you).
- Network policies, Pod Security Admission, image scanning.
- GitOps tooling (Argo CD, Flux) instead of `kubectl apply` from laptops.
- Observability stack (Demos 37–38).

## Optional Advanced Enhancements

- `kubectl explain pod.spec.containers` — built-in API docs.
- Show CRDs (Custom Resource Definitions): `kubectl get crd` after installing
  Argo CD or cert-manager.
- Inspect `etcd` directly (in-cluster only — read-only is fine).

## Instructor Notes

- Spend 10–15 minutes on the architecture before any `kubectl` command.
- Use the metaphor: "Docker = run a container on one machine. Kubernetes =
  schedule containers across many machines and keep them running."
- Stress: Kubernetes is **declarative**. You don't say *how*, you say *what*.
  Controllers do the rest.
- Common confusion: Pod ≠ container. A Pod is a group of containers sharing a
  network/IPC namespace. Almost always 1 container per Pod.

## Real-World Relevance

Kubernetes is the de facto standard for containerized workloads in production.
Even managed services (EKS, GKE, AKS) are just hosted Kubernetes. Understanding
the architecture clarifies *why* your kubectl commands behave the way they do.
