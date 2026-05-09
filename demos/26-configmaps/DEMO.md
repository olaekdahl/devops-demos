# Demo 26 — ConfigMaps

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
kubectl apply -f configmap.yaml -f deployment.yaml
kubectl rollout status deployment/devops-app

# Inspect injected env
POD=$(kubectl get pod -l app=devops-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- env | grep -E 'APP_NAME|ENVIRONMENT'

# Inspect mounted file
kubectl exec $POD -- cat /etc/motd

# Hit the app's /env endpoint — values flow through to FastAPI
kubectl port-forward $POD 8000:8000 &
curl localhost:8000/env
kill %1

# Update the file-style config; mounted file updates within ~60s,
# but env vars don't.
kubectl create configmap devops-app-config \
  --from-literal=APP_NAME="DevOps Demo App" \
  --from-literal=ENVIRONMENT=production \
  --from-file=motd.txt=<(echo "PRODUCTION MOTD") \
  --dry-run=client -o yaml | kubectl apply -f -

sleep 65
kubectl exec $POD -- cat /etc/motd                       # updated
kubectl exec $POD -- env | grep ENVIRONMENT              # still 'staging'

# To pick up env var change: bump config-hash annotation, then
sed -i 's/config-hash: "v1"/config-hash: "v2"/' deployment.yaml
kubectl apply -f deployment.yaml
kubectl rollout status deployment/devops-app
```

## Prerequisites

- Deployment from Demo 21.

## Learning Objectives

- Store non-secret config in a ConfigMap.
- Inject it as env vars and as mounted files.
- Trigger a rollout when config changes.

## Concepts Covered

- ConfigMap data shapes: key/value, multi-line files
- `envFrom` vs individual `valueFrom`
- `volumeMounts` for file-style config (e.g., `nginx.conf`)
- Rollout pattern: hash the config into an annotation

## Architecture

```
   ConfigMap "devops-app-config"
        │ key: APP_NAME, ENVIRONMENT
        │ file: nginx.conf
        ├── envFrom ──► Pod env
        └── mounted ──► /etc/nginx/nginx.conf
```

## Expected Output

```
$ kubectl exec $POD -- env | grep ENVIRONMENT
ENVIRONMENT=staging

$ curl localhost:8000/env
{"app_name":"DevOps Demo App","environment":"staging","secret_key":"not-set"}
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Env vars unchanged after CM edit | K8s doesn't restart on env-from changes | Bump `config-hash` annotation |
| Mounted file unchanged | `subPath` mounts disable auto-update | Drop `subPath` and mount the directory |
| `key not found` mounting | Wrong key name | `kubectl describe cm devops-app-config` |
| Pod crashes — required env var missing | Typo in CM keys | Validate before applying |

## Best Practices

- Keep ConfigMaps small. Big config? Use a Git-managed file + GitOps.
- One ConfigMap per concern: `app-config`, `feature-flags`, `nginx-config`.
- Use **kustomize** or Helm to template per-environment ConfigMaps.
- Check in YAML; never edit in cluster directly.

## Production Considerations

- Use a **config-hash** annotation pattern (kustomize hashes automatically).
- For hot-reload of mounted files, the app must watch them.
- For per-env values, prefer separate overlays over `if env == prod` logic.

## Optional Advanced Enhancements

- Add a sidecar that watches a mounted file and SIGHUPs the main container.
- Use **External Secrets Operator** to sync from AWS Parameter Store / Secrets Manager.
- Show how Helm value files generate ConfigMaps per environment.

## Instructor Notes

- Updating a ConfigMap **does not** restart pods. Demonstrate with mounted
  files (which DO update on disk after a few seconds) vs env vars (which DON'T).
- Use a config-hash annotation on the Pod template to force rollouts.

## Real-World Relevance

12-factor apps externalize config. ConfigMaps + Secrets are the Kubernetes-
native answer. Same image, different ConfigMap → different environment.
