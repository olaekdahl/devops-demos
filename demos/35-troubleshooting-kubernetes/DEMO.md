# Demo 35 — Troubleshooting Kubernetes

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
kubectl create namespace broken
kubectl -n broken apply -f broken/

# Status overview
kubectl -n broken get pods,svc

# ── 01 ImagePullBackOff ──
kubectl -n broken describe pod -l app=ipb | tail -20
# Events: "Failed to pull image" + "ErrImagePull"
# Fix: kubectl set image deploy/ipb c=nginx:alpine

# ── 02 CrashLoopBackOff ──
kubectl -n broken logs crash --previous
# Output: "starting" then exit 9
# Fix: change command to a long-running process

# ── 03 OOMKilled ──
kubectl -n broken get pod oom
kubectl -n broken describe pod oom | grep -A3 Last
# State: Terminated  Reason: OOMKilled  Exit Code: 137
# Fix: bump limits.memory to 256Mi

# ── 04 Pending ──
kubectl -n broken describe pod pending | tail -10
# Events: "0/N nodes are available: <N> node(s) didn't match Pod's node affinity/selector"
# Fix: remove the bad nodeSelector

# ── 05 No Endpoints ──
kubectl -n broken get endpoints backend-svc
# ENDPOINTS: <none>
kubectl -n broken get pods --show-labels -l app=BACKEND
# Pods labeled BACKEND, Service selecting backend → mismatch.
# Fix: align case in deployment.spec.template.metadata.labels

# Cleanup
kubectl delete namespace broken
```

## Prerequisites

- Kind cluster.

## Learning Objectives

- Build a mental "first 60 seconds" diagnostic flow for any K8s issue.
- Use the core `kubectl` commands: `describe`, `logs`, `events`, `top`, `exec`,
  `debug`.
- Diagnose: ImagePullBackOff, CrashLoopBackOff, OOMKilled, Pending,
  no Endpoints, DNS issues.

## Concepts Covered

- Events on Pod / Node / Deployment
- `kubectl debug` ephemeral containers
- `crictl` on the node for container-runtime issues
- The "decision tree" approach

## Architecture

```
   Issue reported
        │
        ▼
   kubectl get pods             (status column tells you the category)
        │
        ▼
   ┌── ImagePullBackOff ─►   describe → events; check secret/tag
   ├── CrashLoopBackOff ─►   logs --previous; events
   ├── OOMKilled ───────►   describe; bump limits; profile memory
   ├── Pending ─────────►   describe; node resources, taints, PVC
   ├── Running but 0/1 ─►   describe; readiness probe failing
   └── No Endpoints ────►   service selector vs pod labels
```

## Walkthrough

### Bonus: ephemeral debug container
```bash
# Add a busybox sidecar to a running pod for tcpdump/curl/dig
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container-name>
```

### Bonus: cluster-wide events
```bash
kubectl get events -A --sort-by=.lastTimestamp | tail
```

## Expected Output

```
$ kubectl -n broken get pods
NAME                READY   STATUS              RESTARTS   AGE
backend-...         1/1     Running             0          1m
crash               0/1     CrashLoopBackOff    4          1m
ipb-...             0/1     ImagePullBackOff    0          1m
oom                 0/1     OOMKilled           3          1m
pending             0/1     Pending             0          1m
```

## Best Practices

- **Always describe before you assume.** Events are your friend.
- Use **labels consistently** to avoid Service selector bugs.
- Set **probes**, **requests**, **limits** to make problems visible early.
- Monitor `kubectl get events --watch` during deploys.

## Production Considerations

- Centralize events to logging (CloudWatch/Loki) for retention.
- Use **kube-state-metrics** + alerts on `kube_pod_status_phase`.
- Adopt **`stern`** for multi-pod log tailing.
- For node-level issues, ssh + `crictl ps` / `journalctl -u kubelet`.

## Optional Advanced Enhancements

- Walk through **kubectl-doctor** plugin or k9s for a TUI experience.
- Show `kubectl drain` for node maintenance.
- Demo **PodDisruptionBudget** preventing too many parallel evictions.


## Real-World Relevance

On-call engineers triage cluster incidents weekly. The faster the diagnosis,
the less downtime.
