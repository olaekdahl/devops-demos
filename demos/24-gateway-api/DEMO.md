# Demo 24 — Gateway API

## Learning Objectives
- Install the Gateway API CRDs and a conformant implementation.
- Author `GatewayClass`, `Gateway`, `HTTPRoute`.
- Articulate how Gateway API improves on Ingress.

## Concepts Covered
- Three roles: **infra provider** (GatewayClass), **cluster operator**
  (Gateway), **app developer** (HTTPRoute).
- Cross-namespace routing via `ReferenceGrant`.
- Typed routes: `HTTPRoute`, `TLSRoute`, `GRPCRoute`, `TCPRoute`, `UDPRoute`.

## Real-World Relevance
Gateway API is the Kubernetes-project-blessed replacement for Ingress. Modern
controllers (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric, AWS LB
Controller) all support it. New projects should prefer Gateway API.

## Demo Architecture
```
  GatewayClass "envoy"   (installed once per cluster)
         ▲ implementedBy
  Gateway "public-https"
         │ listens on :80, :443
         ▼ attaches
  HTTPRoute "devops-routes"
         │ host: devops.local
         │ /api ─► devops-app-svc:80
         │ /web ─► web-svc:80
```

## Instructor Notes
- Compare side-by-side with the Ingress YAML from Demo 23.
- Stress separation of concerns: infra team owns `Gateway`, app team owns
  `HTTPRoute`, both can change independently.
- The CRDs (`networking.k8s.io/v1` is for Ingress; Gateway API uses
  `gateway.networking.k8s.io/v1`).

## Prerequisites
- Demo 23 cluster + sample-app + web-svc deployed.

## Folder Structure
```
demos/24-gateway-api/
  install.sh
  gateway.yaml
  httproute.yaml
```

## Complete Code

`install.sh`
```bash
#!/usr/bin/env bash
set -e
# 1. Install Gateway API standard CRDs (v1.1.0 stable as of 2025).
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# 2. Install Envoy Gateway as a conformant implementation (lightweight).
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.1.0 -n envoy-gateway-system --create-namespace

kubectl wait --namespace envoy-gateway-system \
  --for=condition=Available deployment --all --timeout=180s
```

`gateway.yaml`
```yaml
# Cluster-operator owned: defines the listener.
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: envoy }
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: public-http
  namespace: default
spec:
  gatewayClassName: envoy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces: { from: Same }       # only routes in same namespace
```

`httproute.yaml`
```yaml
# App-team owned: defines what to route where.
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: devops-routes
  namespace: default
spec:
  parentRefs:
    - name: public-http
  hostnames:
    - devops.local
  rules:
    - matches:
        - path: { type: PathPrefix, value: /api }
      backendRefs:
        - name: devops-app-svc
          port: 80
    - matches:
        - path: { type: PathPrefix, value: /web }
      backendRefs:
        - name: web-svc
          port: 80
```

## Step-by-Step Walkthrough

```bash
cd demos/24-gateway-api
bash install.sh

kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

kubectl get gatewayclass
kubectl get gateway
kubectl get httproute

# Find the gateway's externally reachable address (in Kind it's a Service of type LoadBalancer with external <pending>; use NodePort or port-forward for the demo)
kubectl -n envoy-gateway-system get svc

# Port-forward for the demo
kubectl -n envoy-gateway-system port-forward svc/envoy-default-public-http-* 8081:80 &

curl -H 'Host: devops.local' http://127.0.0.1:8081/api/health
curl -H 'Host: devops.local' http://127.0.0.1:8081/web/

# Cleanup
kubectl delete -f httproute.yaml -f gateway.yaml
helm uninstall eg -n envoy-gateway-system
```

## Expected Output
```
$ kubectl get gateway
NAME          CLASS   ADDRESS    PROGRAMMED   AGE
public-http   envoy   10.96.x.y  True         15s

$ curl -H 'Host: devops.local' http://127.0.0.1:8081/api/health
{"status":"OK","message":"The application is healthy!"}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `no matches for kind "Gateway"` | CRDs not installed | Run `install.sh` step 1 |
| Route shows `Accepted=False` | Listener not allowing namespace | `allowedRoutes.namespaces.from: All` |
| Route `ResolvedRefs=False` | Backend Service missing | Apply Service first |
| 404 on `/api` | Wrong `pathType` or hostname mismatch | `PathPrefix` + correct `Host:` header |

## Gateway API vs Ingress (the obvious slide)
| | Ingress | Gateway API |
|---|---|---|
| Status | Frozen | Active development |
| Granularity | One object | GatewayClass / Gateway / *Route |
| Multi-team | Hard | Native (RBAC by kind) |
| Non-HTTP | Annotations | TLSRoute, GRPCRoute, TCPRoute |
| Vendor lock-in | High (annotations) | Low (typed fields) |

## DevOps Best Practices
- Adopt Gateway API for **new** clusters; migrate gradually.
- Use **`ReferenceGrant`** for cross-namespace routing.
- Pin CRDs to a stable channel version.

## Production Considerations
- Choose a controller that matches your needs (Envoy, NGINX, Cilium, AWS LB
  Controller, Istio).
- Use **AWS Load Balancer Controller** + Gateway API on EKS for ALB integration.
- Apply traffic-splitting / canary via `BackendRef` weights.

## Optional Advanced Enhancements
- Show **canary** with two weighted backendRefs.
- Combine with **mTLS** via TLSRoute.
- GRPCRoute for gRPC services.
