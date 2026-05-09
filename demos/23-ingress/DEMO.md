# Demo 23 — Ingress

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Install ingress-nginx
bash install-ingress-nginx.sh

# 2. Add the host alias on your machine
echo "127.0.0.1 devops.local" | sudo tee -a /etc/hosts

# 3. Make sure the ClusterIP Service from Demo 22 exists
kubectl get svc devops-app-svc

# 4. Deploy the second app
kubectl apply -f app2-deployment.yaml

# 5. Apply the Ingress
kubectl apply -f ingress.yaml
kubectl get ingress

# 6. Hit it (Kind exposes ingress on host :8080 thanks to extraPortMappings)
curl http://devops.local:8080/api/health
curl http://devops.local:8080/web/

# 7. TLS (self-signed)
mkdir -p tls
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout tls/tls.key -out tls/tls.crt \
  -subj "/CN=devops.local" -days 30
kubectl create secret tls devops-tls \
  --cert=tls/tls.crt --key=tls/tls.key
kubectl apply -f ingress-tls.yaml
curl -k https://devops.local:8443/health         # Kind also forwards 443→8443

# 8. Cleanup
kubectl delete -f ingress.yaml -f app2-deployment.yaml
```

## Prerequisites

- Kind cluster from Demo 20 with `extraPortMappings` 80→8080.
- Sample app Service (Demo 22).

## Learning Objectives

- Install ingress-nginx in a Kind cluster.
- Route HTTP traffic by host and path to multiple Services.
- Add basic TLS.

## Concepts Covered

- Ingress vs Service — Ingress is **L7 HTTP/S** routing.
- Ingress controller (nginx, Traefik, AWS ALB, GCE LB) reads Ingress objects.
- `host:` and `path:` rules.
- TLS termination at the ingress.

## Architecture

```
   client ──HTTPS──► ingress-nginx (LB / NodePort)
                          │
                ┌─────────┼──────────┐
                │ /api    │ /web     │ /admin
                ▼         ▼          ▼
           api-svc    web-svc    admin-svc
```

## Expected Output

```
$ kubectl get ingress
NAME             CLASS   HOSTS           ADDRESS     PORTS   AGE
devops-ingress   nginx   devops.local    localhost   80      30s

$ curl http://devops.local:8080/api/health
{"status":"OK","message":"The application is healthy!"}

$ curl -k https://devops.local:8443/health
{"status":"OK","message":"The application is healthy!"}
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 404 from nginx | Path doesn't match any rule; or `pathType: Exact` | Use `Prefix` |
| Ingress address `<pending>` forever | Controller not installed | Install ingress-nginx |
| Connection refused on host | Kind missing `extraPortMappings` | Recreate cluster with the multi-node config |
| Service backend not found | Service name typo or wrong namespace | `kubectl get svc -A` |

## Best Practices

- One ingress controller per cluster (or per environment).
- Use `ingressClassName` explicitly — multiple controllers can coexist.
- Use **cert-manager** + Let's Encrypt for automated TLS in prod.
- Annotate with rate limits / auth as needed; nginx supports many annotations.

## Production Considerations

- Front the controller with a real cloud LB (ALB/NLB).
- Use **WAF** (AWS WAF, Cloudflare) in front of the LB.
- Centralize observability: ingress logs are gold for traffic analysis.
- Consider **Gateway API** (Demo 24) — the strategic successor to Ingress.

## Optional Advanced Enhancements

- Add `nginx.ingress.kubernetes.io/limit-rps: "10"` and demonstrate.
- Add basic auth via `auth-type: basic` annotation.
- Compare nginx vs Traefik vs HAProxy ingress controllers.

## Instructor Notes

- Without an ingress controller, an Ingress object does nothing. Install one
  first.
- Show two route rules sharing one host to make path routing concrete.
- For TLS, generate a self-signed cert live; explain cert-manager for prod.

## Real-World Relevance

Almost every cloud-native HTTP app sits behind an Ingress. One LoadBalancer →
one ingress controller → many services, organized by hostname/path.
