# Demo 25 — Scaling Workloads

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Metrics server (needed for HPA)
bash install-metrics-server.sh
kubectl top nodes
kubectl top pods

# 2. Manual scale first
kubectl scale deployment devops-app --replicas=2
kubectl get pods -l app=devops-app

# 3. Apply HPA
kubectl apply -f hpa.yaml
kubectl get hpa

# 4. Hammer the service
kubectl apply -f loadgen.yaml

# 5. Watch HPA scale up
kubectl get hpa -w &
WATCH=$!
sleep 90
kill $WATCH

# 6. After load stops, watch scale-down ~ 1 minute later
kubectl get hpa -w

# Cleanup
kubectl delete -f hpa.yaml -f loadgen.yaml
```

## Prerequisites

- Deployment from Demo 21 with `resources.requests.cpu` set.
- Kind cluster.

## Learning Objectives

- Manually scale a Deployment.
- Configure a HorizontalPodAutoscaler (HPA) on CPU.
- Generate load and watch autoscaling.

## Concepts Covered

- `kubectl scale` for manual scaling.
- HPA controller polls metrics-server every 15s.
- Resource **requests** are mandatory for HPA to compute utilization.
- HPA v2 with multiple metrics; VPA / Cluster Autoscaler (preview).

## Architecture

```
   metrics-server scrapes pod CPU ──► HPA controller
                                            │
                                            ▼
                 desired replicas = ceil( current * (utilization / target) )
                                            │
                                            ▼
                              kubectl scale deploy ...
```

## Expected Output

```
$ kubectl get hpa -w
NAME              REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS
devops-app-hpa    Deployment/devops-app  2%/50%    1         8         2
devops-app-hpa    Deployment/devops-app  82%/50%   1         8         2
devops-app-hpa    Deployment/devops-app  82%/50%   1         8         4
devops-app-hpa    Deployment/devops-app  60%/50%   1         8         5
...
devops-app-hpa    Deployment/devops-app  3%/50%    1         8         5
devops-app-hpa    Deployment/devops-app  3%/50%    1         8         1   ◄ after stabilization
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| HPA TARGETS shows `<unknown>` | metrics-server missing or pod has no `resources.requests.cpu` | Install metrics-server; set requests |
| HPA never scales down | Stabilization window not elapsed | Wait or lower it |
| Scale up oscillates | Threshold too aggressive | Increase `averageUtilization` |
| Pods scheduled but stuck Pending | Node CPU exhausted | Add nodes (Cluster Autoscaler) |

## Best Practices

- Always set `resources.requests` — HPA + scheduler depend on them.
- Combine HPA with **Cluster Autoscaler** (or Karpenter) so nodes scale too.
- Avoid scaling on raw metrics — use **SLI-based** scaling for user-facing services.

## Production Considerations

- Scale on **custom metrics** (RPS, queue depth) via Prometheus Adapter / KEDA.
- Combine with **PodDisruptionBudget** so scale-down doesn't violate availability.
- Use **Vertical Pod Autoscaler** for right-sizing requests over time.

## Optional Advanced Enhancements

- Replace HPA with **KEDA** scaled on RabbitMQ / Kafka / SQS depth.
- Show **Karpenter** provisioning new nodes in EKS within ~30s.
- Demo VPA in `recommend` mode and look at suggested requests.


## Real-World Relevance

Auto-scaling is the cost-savings + reliability trick that lets you serve traffic
spikes without overprovisioning during quiet hours.
