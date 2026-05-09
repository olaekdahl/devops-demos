#!/usr/bin/env bash
# Extracted commands from 22-kubernetes-services.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail


# 1. ClusterIP — only reachable from inside the cluster
kubectl apply -f service-clusterip.yaml
kubectl get svc devops-app-svc

# Spin up an ephemeral debug pod to test in-cluster DNS + connectivity
kubectl run shell --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'curl -s http://devops-app-svc/health && echo'

# 2. NodePort — reachable on each node's IP at port 30080
kubectl apply -f service-nodeport.yaml

# Find any node IP (Kind nodes are containers; use the docker-bridge IP)
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl http://$NODE_IP:30080/health

# 3. Watch round-robin across pods
  kubectl exec -it $(kubectl get pod -l app=devops-app -o name | head -1) -- hostname

# 4. Decoupling: scale up Deployment; Service routes to all pods automatically
kubectl scale deployment devops-app --replicas=5
kubectl get endpoints devops-app-svc

# 5. Cleanup
kubectl delete -f service-clusterip.yaml -f service-nodeport.yaml