#!/usr/bin/env bash
# Extracted commands from 31-eks-deployments.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail


# 1. Configure AWS CLI (lab values)
aws configure          # AKID/SAK/us-west-2/json

# 2. Create the cluster (5-10 min)
eksctl create cluster -f single-node-cluster.yaml

# 3. kubeconfig is auto-set, verify:
kubectl get nodes

# 4. Install LBC (provides real LoadBalancer Services / ALB Ingress)
bash install-aws-lb-controller.sh

# 5. Pull secret for Artifactory (from Demo 30)
ARTIFACTORY_URL=... ARTIFACTORY_USER=... ARTIFACTORY_TOKEN=... \

# 6. Deploy app + Service
kubectl apply -f deployment.yaml -f service-lb.yaml
kubectl rollout status deployment/devops-app

# 7. Get LB DNS name
kubectl get svc devops-app-lb
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$DNS/health"
curl http://$DNS/health

# 8. TEAR DOWN (important — costs money)
eksctl delete cluster -f single-node-cluster.yaml

# --- next block ---


# 1. Configure AWS CLI (lab values)
aws configure          # AKID/SAK/us-west-2/json

# 2. Create the cluster (5-10 min)
eksctl create cluster -f single-node-cluster.yaml

# 3. kubeconfig is auto-set, verify:
kubectl get nodes

# 4. Install LBC (provides real LoadBalancer Services / ALB Ingress)
bash install-aws-lb-controller.sh

# 5. Pull secret for Artifactory (from Demo 30)
ARTIFACTORY_URL=... ARTIFACTORY_USER=... ARTIFACTORY_TOKEN=... \

# 6. Deploy app + Service
kubectl apply -f deployment.yaml -f service-lb.yaml
kubectl rollout status deployment/devops-app

# 7. Get LB DNS name
kubectl get svc devops-app-lb
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$DNS/health"
curl http://$DNS/health

# 8. TEAR DOWN (important — costs money)
eksctl delete cluster -f single-node-cluster.yaml