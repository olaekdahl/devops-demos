# Demo 32 — End To End Cicd

Runnable artifacts for this demo. Full instructor narrative in [DEMO.md](DEMO.md).

## How to run

```bash
docker build -t demo-app:local .
docker run --rm -p 8000:8000 demo-app:local
```

```bash
# Requires a running Kubernetes cluster — see demo 20 for kind setup.
kubectl apply -f .
kubectl get all
kubectl delete -f .   # cleanup
```

```bash
# GitHub Actions — push to a GitHub repo to run.
# Validate locally:  pipx install actionlint && actionlint .github/workflows/*.yaml
```

```bash
# Step-by-step shell commands extracted from the demo.
# READ FIRST — some commands are interactive or destructive.
bash commands.sh
```

See [DEMO.md](DEMO.md) for the full walkthrough.
