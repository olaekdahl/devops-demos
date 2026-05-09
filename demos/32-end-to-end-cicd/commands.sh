#!/usr/bin/env bash
# Extracted commands from 32-end-to-end-cicd.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# 1. Verify EKS is running (Demo 31)
kubectl get nodes

# 2. Set GitHub secrets in your repo:
#    AWS_ACCESS_KEY, AWS_SECRET_KEY,
#    ARTIFACTORY_URL, ARTIFACTORY_USER, ARTIFACTORY_TOKEN

# 3. Configure GitHub Environment 'production' with required reviewers (yourself)

# 4. Push the workflow + manifests
# git add . && git commit -m "feat: end-to-end pipeline" && git push origin main  # parent-repo op — review & run manually

# 5. Watch the pipeline in the Actions tab
#    test → build-and-push → (manual approval) → deploy → smoke

# 6. Verify in cluster
kubectl get deploy,svc,pods
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$DNS/version

# --- next block ---

# Remove K8s resources
kubectl delete deploy devops-app
kubectl delete svc devops-app-lb        # destroys the NLB

# Destroy EKS cluster
eksctl delete cluster -f ../31-eks/single-node-cluster.yaml