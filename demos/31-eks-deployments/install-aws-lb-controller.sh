#!/usr/bin/env bash
set -e
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
  --cluster=$CLUSTER --region=$REGION \
  --namespace=kube-system --name=aws-load-balancer-controller \
  --role-name=AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 3. Helm install
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
