# Demo 24 — Gateway API

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
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

## Prerequisites

- Demo 23 cluster + sample-app + web-svc deployed.

## Learning Objectives

- Install the Gateway API CRDs and a conformant implementation.
- Author `GatewayClass`, `Gateway`, `HTTPRoute`.
- Articulate how Gateway API improves on Ingress.

## Concepts Covered

- Three roles: **infra provider** (GatewayClass), **cluster operator**
  (Gateway), **app developer** (HTTPRoute).
- Cross-namespace routing via `ReferenceGrant`.
- Typed routes: `HTTPRoute`, `TLSRoute`, `GRPCRoute`, `TCPRoute`, `UDPRoute`.

## Architecture

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

## Expected Output

```
$ kubectl get gateway
NAME          CLASS   ADDRESS    PROGRAMMED   AGE
public-http   envoy   10.96.x.y  True         15s

$ curl -H 'Host: devops.local' http://127.0.0.1:8081/api/health
{"status":"OK","message":"The application is healthy!"}
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `no matches for kind "Gateway"` | CRDs not installed | Run `install.sh` step 1 |
| Route shows `Accepted=False` | Listener not allowing namespace | `allowedRoutes.namespaces.from: All` |
| Route `ResolvedRefs=False` | Backend Service missing | Apply Service first |
| 404 on `/api` | Wrong `pathType` or hostname mismatch | `PathPrefix` + correct `Host:` header |

## Best Practices

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


## Real-World Relevance

Gateway API is the Kubernetes-project-blessed replacement for Ingress. Modern
controllers (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric, AWS LB
Controller) all support it. New projects should prefer Gateway API.
