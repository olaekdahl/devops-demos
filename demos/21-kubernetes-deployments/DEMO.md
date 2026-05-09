# Demo 21 — Kubernetes Deployments

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app

kubectl get deploy,rs,pods -l app=devops-app

# Tail logs from one pod
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD &
LOGS=$!

# Kill a pod, watch self-healing
kubectl delete pod $POD
kubectl get pods -l app=devops-app -w &
WATCH=$!
sleep 8 && kill $LOGS $WATCH 2>/dev/null

# ── Rolling update to v1.0.1 ────────────────────────────────────────
docker build -t devops-app:1.0.1 ../15-docker-build-process    # rebuild
kind load docker-image devops-app:1.0.1 --name devops

kubectl set image deployment/devops-app app=devops-app:1.0.1 --record
kubectl rollout status deployment/devops-app
kubectl get rs -l app=devops-app

# ── Roll back ───────────────────────────────────────────────────────
kubectl rollout history deployment/devops-app
kubectl rollout undo deployment/devops-app
kubectl rollout status deployment/devops-app

# ── Inspect events on failure (deploy a broken image) ──────────────
kubectl set image deployment/devops-app app=devops-app:does-not-exist
kubectl rollout status deployment/devops-app --timeout=30s    # times out
kubectl describe deploy devops-app | tail -20                 # see ImagePullBackOff
kubectl rollout undo deployment/devops-app

# Cleanup
kubectl delete -f deployment.yaml
```

## Prerequisites

- Demo 20 (Kind cluster up). Image `devops-app:1.0.0` loaded.

## Learning Objectives

- Author a Deployment manifest from scratch.
- Roll out a new image version with zero downtime.
- Roll back when something breaks.
- Distinguish Pod / ReplicaSet / Deployment.

## Concepts Covered

- `apps/v1 Deployment`
- `selector`, `template`, `replicas`
- Rolling update strategy: `maxSurge`, `maxUnavailable`
- `kubectl rollout status / history / undo`
- Liveness & readiness probes

## Architecture

```
   Deployment "devops-app"  (v1.0.0)
        │  manages
        ▼
   ReplicaSet rs-abc        (3 pods)
        │  manages
        ▼
   pod-1 pod-2 pod-3        (image: devops-app:1.0.0)

   kubectl set image ─► new ReplicaSet rs-def created with v1.0.1
                       new pods scheduled, old pods drained gradually.
```

## Expected Output

```
$ kubectl get deploy,rs,pods -l app=devops-app
NAME                         READY   UP-TO-DATE   AVAILABLE
deployment.apps/devops-app   3/3     3            3

NAME                                    DESIRED   CURRENT   READY
replicaset.apps/devops-app-7d6b...      3         3         3

NAME                              READY   STATUS    RESTARTS
pod/devops-app-7d6b...-2k4xk      1/1     Running   0
pod/devops-app-7d6b...-q9hcm      1/1     Running   0
pod/devops-app-7d6b...-x7m2t      1/1     Running   0

$ kubectl rollout status deployment/devops-app
Waiting for deployment "devops-app" rollout to finish: 1 of 3 updated replicas are available...
deployment "devops-app" successfully rolled out
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `0/3 pods are available` | Readiness probe failing | `kubectl describe pod` → check probe path/port |
| Rollout stuck on `ImagePullBackOff` | Tag doesn't exist or not Kind-loaded | Build + `kind load` then re-set image |
| Pods restart constantly | Liveness probe too aggressive | Increase `initialDelaySeconds` |
| Old pods linger | `maxUnavailable: 0` & resource pressure | Reduce replicas or add node |

## Best Practices

- Always set **probes**, **resource requests/limits**, and `revisionHistoryLimit`.
- Pin image tags to immutable versions (no `:latest` in prod).
- Label pods with `app`, `version`, `component` for queryability.
- Use **PodDisruptionBudgets** in clusters with autoscaling.

## Production Considerations

- Use **GitOps** (Argo CD/Flux) so Deployments come from Git, not laptops.
- Add **anti-affinity** so replicas spread across nodes/AZs.
- Use **Progressive delivery** (canary, blue/green) via Argo Rollouts or Flagger.
- Enable **horizontal pod autoscaling** (Demo 25).

## Optional Advanced Enhancements

- Add `topologySpreadConstraints` for AZ-aware scheduling.
- Use `kubectl diff -f deployment.yaml` to preview changes before applying.
- Adopt the `Recreate` strategy and contrast (downtime, simpler).

## Instructor Notes

- Show that `kubectl get rs` reveals the historical ReplicaSets — that's how
  rollback works.
- Watch pods come and go during a rolling update with `kubectl get pods -w`.
- Demonstrate **rollback** by deploying an intentionally broken image.

## Real-World Relevance

Deployments are how 95% of stateless workloads run in Kubernetes. Rolling
updates + readiness probes give you safe, no-downtime releases.
