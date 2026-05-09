# Demo 35 — Troubleshooting Kubernetes

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

## Real-World Relevance
On-call engineers triage cluster incidents weekly. The faster the diagnosis,
the less downtime.

## Demo Architecture
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

## Instructor Notes
- Provide a "broken namespace" with five intentional issues; let students fix
  each.
- Reinforce: `describe` first, `logs` second. Most info lives in events.

## Prerequisites
- Kind cluster.

## Folder Structure
```
demos/35-troubleshooting-kubernetes/
  broken/
    01-image-pull.yaml         # bad image
    02-crashloop.yaml          # bad command
    03-oomkilled.yaml          # tiny limit, big malloc
    04-pending.yaml            # impossible nodeSelector
    05-no-endpoints.yaml       # selector mismatch
```

## Complete Code

`broken/01-image-pull.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: ipb }
spec:
  replicas: 1
  selector: { matchLabels: { app: ipb } }
  template:
    metadata: { labels: { app: ipb } }
    spec:
      containers:
        - name: c
          image: nginx:does-not-exist     # bad tag
```

`broken/02-crashloop.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata: { name: crash }
spec:
  containers:
    - name: c
      image: busybox
      command: ["/bin/sh", "-c", "echo starting; sleep 2; exit 9"]
```

`broken/03-oomkilled.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata: { name: oom }
spec:
  containers:
    - name: c
      image: polinux/stress
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "200M", "--vm-hang", "0"]
      resources:
        limits: { memory: "32Mi" }
```

`broken/04-pending.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata: { name: pending }
spec:
  nodeSelector:
    disktype: nvme-extreme       # no node has this label
  containers:
    - name: c
      image: busybox
      command: ["sleep", "9999"]
```

`broken/05-no-endpoints.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: backend }
spec:
  replicas: 2
  selector: { matchLabels: { app: backend } }
  template:
    metadata: { labels: { app: BACKEND } }   # case mismatch! breaks selector
    spec:
      containers:
        - name: c
          image: nginx:alpine
          ports: [{ containerPort: 80 }]
---
apiVersion: v1
kind: Service
metadata: { name: backend-svc }
spec:
  selector: { app: backend }                  # never matches BACKEND
  ports: [{ port: 80, targetPort: 80 }]
```

## Step-by-Step Walkthrough

```bash
cd demos/35-troubleshooting-kubernetes
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

## Common Failure Scenarios → first command
| Status | First command |
|---|---|
| `ImagePullBackOff` | `kubectl describe pod` (events) |
| `CrashLoopBackOff` | `kubectl logs --previous` |
| `OOMKilled` | `kubectl describe pod` (Last State) |
| `Pending` | `kubectl describe pod` (Events: scheduling) |
| `Running 0/1` | `kubectl describe pod` (probe failures) |
| Service has no Endpoints | `kubectl get endpoints` then check labels |
| DNS not resolving | `kubectl exec -it pod -- nslookup <svc>` |

## DevOps Best Practices
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
