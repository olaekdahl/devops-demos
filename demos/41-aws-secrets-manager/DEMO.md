# Demo 41 — AWS Secrets Manager for JFrog Pull Secrets

Instead of committing or `kubectl create`-ing a `dockerconfigjson` Secret
(Demos 27 / 31), store JFrog Artifactory credentials in **AWS Secrets Manager**
and let **External Secrets Operator (ESO)** materialize the Kubernetes
`jfrog-pull-secret` automatically.

## How to Run

All files needed by this demo are already in this folder. Run from inside it.
Assumes an EKS cluster from Demo 31 (`devops-cluster` in `us-west-2`, OIDC enabled).

```bash
# 1. Provision the AWS secret + IAM policy + IRSA service account
ARTIFACTORY_URL=mycompany.jfrog.io \
ARTIFACTORY_USER=<your-username> \
ARTIFACTORY_TOKEN=<your-api-key-or-password> \
ARTIFACTORY_EMAIL=<your-email> \
  bash setup-aws-secret.sh

# 2. Install External Secrets Operator (reuses the IRSA service account)
bash install-external-secrets.sh

# 3. Wire ESO to AWS Secrets Manager and project the pull secret
kubectl apply -f secretstore.yaml
kubectl apply -f externalsecret.yaml

# 4. Verify ESO synced the K8s Secret from AWS
kubectl get externalsecret jfrog-pull-secret
kubectl get secret jfrog-pull-secret -o jsonpath='{.type}'; echo
# kubernetes.io/dockerconfigjson

# 5. Deploy the app that consumes the pull secret
kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app

# 6. Rotate the credential in AWS — ESO refreshes the K8s Secret automatically
aws secretsmanager put-secret-value \
  --secret-id devops/jfrog-pull-secret \
  --secret-string '{"server":"mycompany.jfrog.io","username":"u","password":"NEW","email":"demo@example.com"}'

# 7. Tear down
kubectl delete -f deployment.yaml -f externalsecret.yaml -f secretstore.yaml
aws secretsmanager delete-secret --secret-id devops/jfrog-pull-secret --force-delete-without-recovery
```

## Prerequisites

- Demo 31 cluster up (`eksctl create cluster -f ../31-eks-deployments/single-node-cluster.yaml`).
- `aws` CLI configured, `eksctl`, `kubectl`, `helm`, `jq`.
- OIDC provider enabled on the cluster (Demo 31 enables it via `iam.withOIDC: true`).

## Learning Objectives

- Store registry credentials in **AWS Secrets Manager** rather than in Git or a K8s Secret.
- Use **IRSA** so the operator — not the pod — holds AWS permissions.
- Project an AWS secret into a Kubernetes `dockerconfigjson` Secret via **ExternalSecret**.
- Rotate credentials in AWS and have the cluster pick up the change automatically.

## Concepts Covered

- AWS Secrets Manager: `create-secret`, `put-secret-value`, ARN-scoped IAM.
- External Secrets Operator: `ClusterSecretStore`, `ExternalSecret`, `target.template`.
- IRSA (IAM Roles for Service Accounts) on EKS.
- Refresh interval and `creationPolicy: Owner` semantics.

## Architecture

```
   AWS Secrets Manager
      devops/jfrog-pull-secret  {server, username, password, email}
            │
            ▼  (IRSA-bound role; ARN-scoped GetSecretValue)
   External Secrets Operator  (in external-secrets ns)
            │
            ▼  refreshes every 1h (or on AWS change)
   ExternalSecret  ──►  Secret jfrog-pull-secret (dockerconfigjson)
                                    │
                                    ▼
                          Deployment.imagePullSecrets
                                    │
                                    ▼
                          kubelet pulls from JFrog
```

## Expected Output

```
$ kubectl get externalsecret jfrog-pull-secret
NAME                STORE                 REFRESH INTERVAL   STATUS         READY
jfrog-pull-secret   aws-secrets-manager   1h                 SecretSynced   True

$ kubectl get secret jfrog-pull-secret
NAME                TYPE                             DATA   AGE
jfrog-pull-secret   kubernetes.io/dockerconfigjson   1      20s
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ExternalSecret` stuck in `SecretSyncedError` | IRSA role can't read the AWS secret | Re-run [setup-aws-secret.sh](setup-aws-secret.sh); confirm `eksctl create iamserviceaccount` succeeded |
| `WebIdentityErr: AccessDenied` in ESO logs | OIDC provider missing on cluster | Re-create cluster with `iam.withOIDC: true` or run `eksctl utils associate-iam-oidc-provider --approve` |
| K8s `Secret` not created | `ClusterSecretStore` region mismatch | Edit `region:` in [secretstore.yaml](secretstore.yaml) to match `REGION` used by the setup script |
| `ImagePullBackOff` | Image ref still uses old/wrong registry | Update `image:` in [deployment.yaml](deployment.yaml) |
| Wrong JSON shape in pull secret | Field names in AWS secret don't match `remoteRef.property` | Re-run setup script (it writes `server/username/password/email`) |

## Best Practices

- Scope IAM policies to the **specific secret ARN**, not `*`.
- Use **IRSA**, not node IAM roles, so only the operator gets the permission.
- Keep `refreshInterval` short enough to honor rotation SLAs, long enough to
  avoid hitting AWS API limits (default 1h is usually fine).
- Treat the projected K8s `Secret` as read-only — let ESO own it
  (`creationPolicy: Owner`).

## Production Considerations

- Enable **automatic rotation** on the AWS secret (Lambda rotator) and let ESO
  pick up rotated values.
- Use **separate AWS secrets per environment** (`devops/dev/...`, `devops/prod/...`).
- Audit access via **CloudTrail** on `secretsmanager:GetSecretValue`.
- Restrict who can `kubectl get secret jfrog-pull-secret` via RBAC — base64 is not encryption.

## Optional Advanced Enhancements

- Swap AWS Secrets Manager for **SSM Parameter Store** (cheaper for small values)
  by changing `provider.aws.service` to `ParameterStore`.
- Use **PushSecret** (also ESO) to flow values the other direction.
- Adopt **CSI Secrets Store + AWS provider** to mount secrets as files without
  ever creating a K8s `Secret` object.

## Real-World Relevance

In production, registry pull credentials, DB passwords, and API keys belong in
a managed secret store with rotation and auditing. ESO is the standard way to
bridge that store into Kubernetes without baking credentials into manifests or
Helm values.
