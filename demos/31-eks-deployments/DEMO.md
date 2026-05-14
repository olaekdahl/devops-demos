# Demo 31 — EKS Deployments

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Configure AWS CLI
aws configure          # AKID/SAK/us-west-2/json

# 2. Create the cluster (5-10 min)
eksctl create cluster -f single-node-cluster.yaml

# 3. kubeconfig is auto-set, verify:
kubectl get nodes

# 4. Install LBC (provides real LoadBalancer Services / ALB Ingress)
bash install-aws-lb-controller.sh

# 5. Pull secret for Artifactory (from Demo 30)
ARTIFACTORY_URL=... ARTIFACTORY_USER=... ARTIFACTORY_TOKEN=... \
  bash ../30-jfrog-artifactory/pull-secret.sh

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

## Prerequisites

- AWS CLI configured (`aws configure`) with credentials for your AWS account.
- `eksctl` ≥ 0.180, `kubectl` ≥ 1.30, `helm` (for LBC install).

## Learning Objectives

- Provision an EKS cluster with `eksctl`.
- Configure `kubectl` against EKS.
- Deploy the FastAPI app and expose via a LoadBalancer.

## Concepts Covered

- EKS managed control plane vs self-managed nodes
- IAM Roles for Service Accounts (IRSA) — preview
- AWS Load Balancer Controller (LBC) for `LoadBalancer` Services / Ingress
- `aws eks update-kubeconfig`

## Architecture

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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `eksctl create cluster` fails on quota | New AWS account quotas | Request limit increase or use a different instance |
| Service stuck `<pending>` | LBC not installed | Run install script |
| LB DNS resolves but 504 | Targets not yet registered | Wait ~30s; check target group health |
| Nodes not joining | IAM role missing perms | `eksctl utils nodegroup-health-info` |

## Best Practices

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


## Real-World Relevance

EKS is the most-used managed Kubernetes service in regulated enterprises. The
basic lifecycle (create cluster → deploy → expose) is identical regardless of
cloud provider; tooling differs.
