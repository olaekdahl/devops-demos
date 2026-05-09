#!/usr/bin/env bash
# Extracted commands from 23-ingress.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
# Official Kind-friendly manifest for ingress-nginx.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \

# --- next block ---


# 1. Install ingress-nginx

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
kubectl create secret tls devops-tls \
kubectl apply -f ingress-tls.yaml
curl -k https://devops.local:8443/health         # Kind also forwards 443→8443

# 8. Cleanup
kubectl delete -f ingress.yaml -f app2-deployment.yaml