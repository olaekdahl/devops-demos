# Demo 28 — Persistent Storage

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
kubectl get sc                              # 'standard' should exist on Kind
kubectl apply -f pvc.yaml
kubectl get pvc                             # status: Bound (after pod created in some provisioners)
kubectl get pv

kubectl apply -f pod.yaml
kubectl wait --for=condition=Ready pod/writer
kubectl exec writer -- cat /data/log.txt

# Delete + recreate the pod, data persists
kubectl delete pod writer
kubectl apply -f pod.yaml
kubectl wait --for=condition=Ready pod/writer
kubectl exec writer -- cat /data/log.txt    # shows BOTH start lines

# What's actually on the host?
NODE=$(kubectl get pod writer -o jsonpath='{.spec.nodeName}')
docker exec $NODE ls /var/local-path-provisioner/

# Cleanup
kubectl delete pod writer
kubectl delete pvc app-data
```

## Prerequisites

- Kind cluster.

## Learning Objectives

- Distinguish PV / PVC / StorageClass.
- Mount a PVC into a Pod and persist data across Pod restarts.
- Use dynamic provisioning.

## Concepts Covered

- **PersistentVolume (PV)**: cluster resource representing real storage.
- **PersistentVolumeClaim (PVC)**: user request for storage.
- **StorageClass**: template for dynamic provisioning.
- Access modes: `ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`, `ReadWriteOncePod`.
- Reclaim policies: `Delete`, `Retain`.

## Architecture

```
   StorageClass "standard" (Kind ships one — local-path-provisioner)
        │ provisions on demand
        ▼
   PV  (auto-created)  ◄──bound by── PVC "app-data" (10Mi, RWO)
                                            │
                                            ▼
                                  mounted at /data in Pod
```

## Expected Output

```
$ kubectl get pvc
NAME       STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS
app-data   Bound    pvc-abc...  10Mi       RWO            standard

$ kubectl exec writer -- cat /data/log.txt
Pod started at Wed Apr  9 10:00:00 UTC 2026
Pod started at Wed Apr  9 10:01:00 UTC 2026   ◄ second start, same volume
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| PVC stuck `Pending` | No StorageClass / no provisioner | Install one or set `storageClassName` |
| Pod stuck Pending — `pod has unbound immediate PersistentVolumeClaims` | `volumeBindingMode: WaitForFirstConsumer` (normal!) | Just wait for pod scheduling |
| Data lost after node drain | Used `local-path` (node-local) | Use cloud CSI (EBS/EFS) |
| `multi-attach error` | RWO PV used by 2 pods on different nodes | Use RWX or single-node access |

## Best Practices

- Use the right access mode: RWO is the safe default.
- Set `volumeBindingMode: WaitForFirstConsumer` for cloud volumes (binds to AZ).
- Use **StatefulSet** instead of bare Pods for stable identity + ordered storage.
- Back up persistent data — Kubernetes does NOT back it up for you.

## Production Considerations

- EKS: install **AWS EBS CSI Driver** addon; default StorageClass `gp3`.
- For shared RWX storage, use **EFS CSI** or **FSx for Lustre**.
- Use **Velero** for cluster + PV backups.
- Enable encryption at rest on the underlying volume class.

## Optional Advanced Enhancements

- Convert `Pod` to a `StatefulSet` with a `volumeClaimTemplates`.
- Show snapshotting via `VolumeSnapshot` CRDs.
- Demonstrate dynamic resize: edit PVC `resources.requests.storage`.

## Instructor Notes

- Kind ships `local-path-provisioner` — dynamic provisioning works out of the box.
- Show **data survives Pod restart**, but not necessarily node failure (local volumes).
- For network-attached storage in EKS, swap the StorageClass for `gp3`.

## Real-World Relevance

Stateful workloads (databases, queues, ML training) need persistent storage. In
the cloud, EBS/EFS/Azure Disk/GCE PD are exposed via CSI drivers. The PV/PVC
contract is the same everywhere.
