# Demo 27 — Kubernetes Secrets

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
kubectl apply -f secret-opaque.yaml

# (For Capstone) create an image-pull secret too
ARTIFACTORY_URL=... USER=... TOKEN=... bash pull-secret.sh

kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')

# Env var injection
kubectl exec $POD -- printenv SECRET_KEY

# File mount
kubectl exec $POD -- ls -l /etc/creds/
kubectl exec $POD -- cat /etc/creds/db.password

# Inspect the stored Secret (base64 — show the lack of encryption)
kubectl get secret app-creds -o yaml
echo c3VwZXItc2VjcmV0LWRvLW5vdC1wcmludA== | base64 -d
```

## Prerequisites

- Demo 21.

## Learning Objectives

- Create Secrets and use them as env vars and mounted files.
- Understand that **base64 ≠ encryption**.
- Use `imagePullSecrets` for private registries.

## Concepts Covered

- Secret types: `Opaque`, `kubernetes.io/dockerconfigjson`, `kubernetes.io/tls`
- `kubectl create secret` shortcuts
- Mounted secret files have permissions 0444 by default
- Encryption-at-rest (KMS) vs Sealed Secrets / SOPS / External Secrets

## Architecture

```
   Secret "app-creds"  (Opaque, base64-stored in etcd)
        │
        ├── env: SECRET_KEY ──► Pod
        └── mount: /etc/creds/db.password
   Secret "jfrog-pull-secret" (dockerconfigjson)
        └── imagePullSecrets ──► used by kubelet to pull private image
```

## Expected Output

```
$ kubectl exec $POD -- printenv SECRET_KEY
super-secret-do-not-print

$ kubectl exec $POD -- ls -l /etc/creds/
total 4
-r--------    1 root  root  12 Apr  9 10:00 db.password

$ kubectl get secret app-creds -o yaml | grep SECRET_KEY
  SECRET_KEY: c3VwZXItc2VjcmV0LWRvLW5vdC1wcmludA==
$ echo c3VwZXItc2VjcmV0LWRvLW5vdC1wcmludA== | base64 -d
super-secret-do-not-print           ◄ ANYONE WITH RBAC CAN READ THIS
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` from private registry | Wrong/missing `imagePullSecrets` | Recreate via `pull-secret.sh` and reference in pod spec |
| Env var empty | Wrong `key` in `secretKeyRef` | Match key exactly (case-sensitive) |
| Secret keys not updated in pod | Same as ConfigMap — env doesn't refresh | Roll the deployment |
| `forbidden: User cannot get resource "secrets"` | RBAC denies | Grant via Role/RoleBinding |

## Best Practices

- Treat Secrets as **sensitive** even though they're "just base64".
- Use **least privilege RBAC** for secret access.
- Never `kubectl create secret` from a shell with the value visible — use
  `--from-file` from a file you immediately delete.
- Rotate frequently.

## Production Considerations

- Enable **KMS encryption-at-rest** (EKS does this by default).
- Use **External Secrets Operator** to source from AWS Secrets Manager / Vault.
- **Sealed Secrets** or **SOPS** to commit encrypted secrets to Git safely.
- Audit secret access with audit logging + CloudTrail.

## Optional Advanced Enhancements

- Install **External Secrets Operator** and sync from AWS SSM Parameter Store.
- Use **Vault Agent Injector** to inject secrets as files without K8s Secret objects.
- Adopt **CSI Secret Store** to mount cloud-secret-store secrets directly.

## Instructor Notes

- Run `echo "supersecret" | base64` and show that students can decode trivially.
  **Base64 is encoding, not encryption.**
- Secrets are stored in etcd. By default not encrypted at rest. Cloud providers
  enable KMS encryption (EKS does by default since 2023).
- Avoid showing real secret values on screen — use placeholders.

## Real-World Relevance

Every K8s app uses Secrets — DB credentials, API keys, registry pull secrets,
TLS certificates. Doing it wrong = breach.
