# Demo 22 — Kubernetes Services

## Learning Objectives
- Expose a Deployment with a Service.
- Compare ClusterIP, NodePort, and LoadBalancer.
- Understand how kube-proxy + DNS provide service discovery.

## Concepts Covered
- Service types: `ClusterIP` (default), `NodePort`, `LoadBalancer`, `ExternalName`.
- Selectors match Pod labels (decoupled from Deployment).
- DNS: `<service>.<namespace>.svc.cluster.local`.
- `port` (service) vs `targetPort` (container) vs `nodePort` (host).

## Quick Start
Run the demo end-to-end:

```bash
cd demos/22-kubernetes-services

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
for i in $(seq 1 6); do
  kubectl exec -it $(kubectl get pod -l app=devops-app -o name | head -1) -- hostname
done

# 4. Decoupling: scale up Deployment; Service routes to all pods automatically
kubectl scale deployment devops-app --replicas=5
kubectl get endpoints devops-app-svc

# 5. Cleanup
kubectl delete -f service-clusterip.yaml -f service-nodeport.yaml
```

## Real-World Relevance
Services give pods a stable virtual IP and DNS name even though pods come and
go. Without them, every restart would change addresses and break clients.

## Demo Architecture
```
   client (in cluster)            client (outside cluster)
       │                                  │
       ▼                                  ▼
   Service "devops-app-svc"          NodePort 30080 ──► same Service
        │ selector: app=devops-app
        ▼
   pod-1, pod-2, pod-3 (round-robin)
```

## Instructor Notes
- Stress: a Service is a **virtual** thing. There's no process — kube-proxy
  programs iptables/ipvs rules to forward.
- Show DNS from inside a pod: `nslookup devops-app-svc`.
- Kind doesn't have a real LoadBalancer. NodePort is the practical choice
  locally; in cloud, LoadBalancer provisions an ELB/NLB/ALB.

## Prerequisites
- Demo 21 (Deployment running).

## Folder Structure
```
demos/22-kubernetes-services/
  service-clusterip.yaml
  service-nodeport.yaml
  service-loadbalancer.yaml
```

## Complete Code

`service-clusterip.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-svc
spec:
  type: ClusterIP                    # default; in-cluster only
  selector:
    app: devops-app                  # matches Pod labels
  ports:
    - name: http
      port: 80                       # service port
      targetPort: 8000               # container port
      protocol: TCP
```

`service-nodeport.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-np
spec:
  type: NodePort
  selector: { app: devops-app }
  ports:
    - port: 80
      targetPort: 8000
      nodePort: 30080                # 30000-32767 range; host port on every node
```

`service-loadbalancer.yaml` (cloud only — see Demo 31)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-lb
spec:
  type: LoadBalancer
  selector: { app: devops-app }
  ports:
    - port: 80
      targetPort: 8000
```

## Step-by-Step Walkthrough

```bash
cd demos/22-kubernetes-services

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
for i in $(seq 1 6); do
  kubectl exec -it $(kubectl get pod -l app=devops-app -o name | head -1) -- hostname
done

# 4. Decoupling: scale up Deployment; Service routes to all pods automatically
kubectl scale deployment devops-app --replicas=5
kubectl get endpoints devops-app-svc

# 5. Cleanup
kubectl delete -f service-clusterip.yaml -f service-nodeport.yaml
```

## Expected Output
```
$ kubectl get svc devops-app-svc
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
devops-app-svc   ClusterIP   10.96.123.45    <none>        80/TCP    5s

$ kubectl run shell --rm -it --image=curlimages/curl ... -- curl -s http://devops-app-svc/health
{"status":"OK","message":"The application is healthy!"}

$ kubectl get endpoints devops-app-svc
NAME             ENDPOINTS                                              AGE
devops-app-svc   10.244.1.5:8000,10.244.1.6:8000,10.244.2.4:8000,...   2m
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `curl` connection refused on NodePort | Wrong nodePort or firewall | `kubectl get svc -o wide`; check security group |
| Service has no endpoints | Selector doesn't match Pod labels | `kubectl get pods --show-labels`; fix selector |
| `targetPort` mismatch | App listens on different port than `targetPort` | Match container port |
| LoadBalancer stuck `<pending>` | No cloud controller (e.g., Kind) | Use NodePort or install MetalLB |

## DevOps Best Practices
- One Service per logical interface; name them clearly (`-api`, `-grpc`).
- Reference services by **DNS name**, never IP.
- For internal-only services use `ClusterIP`; expose via Ingress (Demo 23) for HTTP.
- Use **headless services** (`clusterIP: None`) for stateful sets.

## Production Considerations
- Cloud LoadBalancers cost money — prefer one ALB/NLB + Ingress for many services.
- Use **`internalTrafficPolicy: Local`** to keep traffic on the same node when safe.
- Enable **TopologyAwareHints** to keep traffic in-AZ.

## Optional Advanced Enhancements
- Show `kubectl port-forward svc/devops-app-svc 8080:80` for ad-hoc local access.
- Compare round-robin balancing under iptables vs ipvs (`mode: ipvs`).
- Add a second container (sidecar) and show how Services route to one named port.
