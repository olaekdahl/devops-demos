#!/usr/bin/env bash
# Extracted commands from 28-persistent-storage.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail


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

# --- next block ---


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