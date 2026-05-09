#!/usr/bin/env bash
# Extracted commands from 31-eks-deployments.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

#!/usr/bin/env bash
CLUSTER=devops-cluster
REGION=us-west-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Download IAM policy and create it (idempotent)
curl -sSLo iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json 2>/dev/null || true

# 2. Create IRSA service account
eksctl create iamserviceaccount \
  --namespace=kube-system --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \

# 3. Helm install
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

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