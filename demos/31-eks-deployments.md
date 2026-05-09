# Demo 31 — EKS Deployments

## Learning Objectives
- Provision an EKS cluster with `eksctl` (matches Lab 5.1).
- Configure `kubectl` against EKS.
- Deploy the FastAPI app and expose via a LoadBalancer.

## Concepts Covered
- EKS managed control plane vs self-managed nodes
- IAM Roles for Service Accounts (IRSA) — preview
- AWS Load Balancer Controller (LBC) for `LoadBalancer` Services / Ingress
- `aws eks update-kubeconfig`

## Quick Start
Run the demo end-to-end:

```bash
cd demos/31-eks-deployments

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
  bash ../30-jfrog/pull-secret.sh

# 6. Deploy app + Service
kubectl apply -f deployment.yaml -f service-lb.yaml
kubectl rollout status deployment/devops-app

# 7. Get LB DNS name
kubectl get svc devops-app-lb
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$DNS/health"
sleep 30   # give NLB time to register targets
curl http://$DNS/health

# 8. TEAR DOWN (important — costs money)
eksctl delete cluster -f single-node-cluster.yaml
```

## Real-World Relevance
EKS is the most-used managed Kubernetes service in regulated enterprises. The
basic lifecycle (create cluster → deploy → expose) is identical regardless of
cloud provider; tooling differs.

## Demo Architecture
```
   eksctl  ──► CloudFormation ──► EKS control plane (managed)
                              │
                              └─► Node group (EC2 t3.medium x N)

   kubectl apply ──► Deployment + Service(type=LoadBalancer)
                                            │
                                            ▼
                       AWS Load Balancer Controller
                                            │
                                            ▼
                                 NLB / ALB created
                                            │
                                            ▼
                                   Internet client
```

## Instructor Notes
- EKS creation takes 5–10 minutes. Start it, then teach concepts while it builds.
- Lab grants long-lived AWS access keys; production uses IAM Roles + OIDC.
- Cost: t3.medium ≈ $0.04/h. **Tear down** clusters after class.

## Prerequisites
- AWS CLI configured (`aws configure`) — using lab access keys.
- `eksctl` ≥ 0.180, `kubectl` ≥ 1.30, `helm` (for LBC install).

## Folder Structure
```
demos/31-eks-deployments/
  single-node-cluster.yaml          (lab matches this)
  install-aws-lb-controller.sh
  deployment.yaml
  service-lb.yaml
```

## Complete Code

`single-node-cluster.yaml` (matches Lab 5.1)
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: devops-cluster
  region: us-west-2
nodeGroups:
  - name: single-node-group
    instanceType: t3.medium
    desiredCapacity: 1
    minSize: 1
    maxSize: 1
    amiFamily: AmazonLinux2
iam:
  withOIDC: true                        # required for IRSA / LBC
```

`install-aws-lb-controller.sh`
```bash
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
```

`deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: devops-app }
spec:
  replicas: 2
  selector: { matchLabels: { app: devops-app } }
  template:
    metadata: { labels: { app: devops-app } }
    spec:
      imagePullSecrets:
        - name: jfrog-pull-secret           # see Demo 30
      containers:
        - name: app
          image: <artifactory-url>/<repo>/<initials>-devops:1.0.0
          ports: [{ containerPort: 8000 }]
          readinessProbe:
            httpGet: { path: /health, port: 8000 }
```

`service-lb.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-lb
  annotations:
    # Provision an internet-facing NLB
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector: { app: devops-app }
  ports:
    - port: 80
      targetPort: 8000
```

## Step-by-Step Walkthrough
```bash
cd demos/31-eks-deployments

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
  bash ../30-jfrog/pull-secret.sh

# 6. Deploy app + Service
kubectl apply -f deployment.yaml -f service-lb.yaml
kubectl rollout status deployment/devops-app

# 7. Get LB DNS name
kubectl get svc devops-app-lb
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$DNS/health"
sleep 30   # give NLB time to register targets
curl http://$DNS/health

# 8. TEAR DOWN (important — costs money)
eksctl delete cluster -f single-node-cluster.yaml
```

## Expected Output
```
$ kubectl get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
ip-192-168-12-34.us-west-2.compute.internal   Ready    <none>   3m    v1.30.0

$ kubectl get svc devops-app-lb
NAME             TYPE          CLUSTER-IP     EXTERNAL-IP                                    PORT(S)
devops-app-lb   LoadBalancer   10.100.x.y     k8s-default-devopsap-...elb.us-west-2.amazonaws.com   80:30123/TCP

$ curl http://k8s-default-devopsap-...elb.us-west-2.amazonaws.com/health
{"status":"OK","message":"The application is healthy!"}
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `eksctl create cluster` fails on quota | New AWS account quotas | Request limit increase or use a different instance |
| Service stuck `<pending>` | LBC not installed | Run install script |
| LB DNS resolves but 504 | Targets not yet registered | Wait ~30s; check target group health |
| Nodes not joining | IAM role missing perms | `eksctl utils nodegroup-health-info` |

## DevOps Best Practices
- Provision clusters via IaC (`eksctl` config, Terraform, or CDK).
- **OIDC + IRSA** instead of node IAM roles for app permissions.
- Tag clusters and resources for cost allocation.
- Use **Managed Node Groups** (or Karpenter) for autoscaling.

## Production Considerations
- Multi-AZ node groups; private subnets for nodes; NAT gateway for egress.
- Enable **EKS Cluster Logging** to CloudWatch for control-plane logs.
- Use **AWS LB Controller** + ALB Ingress (not classic ELB).
- Add **Karpenter** for fast, cost-aware node scaling.
- Backups via **Velero** to S3.

## Optional Advanced Enhancements
- Replace `eksctl` with **Terraform EKS module** for reproducibility.
- Adopt **Karpenter** for spot-instance autoscaling.
- Install **kube-prometheus-stack** for monitoring (Demos 37–38).
