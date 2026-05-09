# Demo 23 — Ingress

## Learning Objectives
- Install ingress-nginx in a Kind cluster.
- Route HTTP traffic by host and path to multiple Services.
- Add basic TLS.

## Concepts Covered
- Ingress vs Service — Ingress is **L7 HTTP/S** routing.
- Ingress controller (nginx, Traefik, AWS ALB, GCE LB) reads Ingress objects.
- `host:` and `path:` rules.
- TLS termination at the ingress.

## Quick Start
Run the demo end-to-end:

```bash
cd demos/23-ingress

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

## Real-World Relevance
Almost every cloud-native HTTP app sits behind an Ingress. One LoadBalancer →
one ingress controller → many services, organized by hostname/path.

## Demo Architecture
```
   client ──HTTPS──► ingress-nginx (LB / NodePort)
                          │
                ┌─────────┼──────────┐
                │ /api    │ /web     │ /admin
                ▼         ▼          ▼
           api-svc    web-svc    admin-svc
```

## Instructor Notes
- Without an ingress controller, an Ingress object does nothing. Install one
  first.
- Show two route rules sharing one host to make path routing concrete.
- For TLS, generate a self-signed cert live; explain cert-manager for prod.

## Prerequisites
- Kind cluster from Demo 20 with `extraPortMappings` 80→8080.
- Sample app Service (Demo 22).

## Folder Structure
```
demos/23-ingress/
  install-ingress-nginx.sh
  app2-deployment.yaml          # second app for path-based routing
  ingress.yaml
  ingress-tls.yaml
  tls/                          # self-signed cert files (generated)
```

## Complete Code

`install-ingress-nginx.sh`
```bash
#!/usr/bin/env bash
set -e
# Official Kind-friendly manifest for ingress-nginx.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

`app2-deployment.yaml`  — a second tiny app to route `/web` to
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: web-app, labels: { app: web-app } }
spec:
  replicas: 2
  selector: { matchLabels: { app: web-app } }
  template:
    metadata: { labels: { app: web-app } }
    spec:
      containers:
        - name: web
          image: nginx:alpine
          ports: [{ containerPort: 80 }]
---
apiVersion: v1
kind: Service
metadata: { name: web-svc }
spec:
  selector: { app: web-app }
  ports: [{ port: 80, targetPort: 80 }]
```

`ingress.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devops-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx           # which controller handles this
  rules:
    - host: devops.local            # add to /etc/hosts: 127.0.0.1 devops.local
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: devops-app-svc       # from Demo 22
                port: { number: 80 }
          - path: /web
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port: { number: 80 }
```

`ingress-tls.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: devops-ingress-tls }
spec:
  ingressClassName: nginx
  tls:
    - hosts: [devops.local]
      secretName: devops-tls
  rules:
    - host: devops.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: devops-app-svc, port: { number: 80 } }
```

## Step-by-Step Walkthrough

```bash
cd demos/23-ingress

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

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| 404 from nginx | Path doesn't match any rule; or `pathType: Exact` | Use `Prefix` |
| Ingress address `<pending>` forever | Controller not installed | Install ingress-nginx |
| Connection refused on host | Kind missing `extraPortMappings` | Recreate cluster with the multi-node config |
| Service backend not found | Service name typo or wrong namespace | `kubectl get svc -A` |

## DevOps Best Practices
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
