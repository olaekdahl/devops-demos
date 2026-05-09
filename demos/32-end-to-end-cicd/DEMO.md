# Demo 32 — End-to-End CI/CD (Capstone)

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Verify EKS is running (Demo 31)
kubectl get nodes

# 2. Set GitHub secrets in your repo:
#    AWS_ACCESS_KEY, AWS_SECRET_KEY,
#    ARTIFACTORY_URL, ARTIFACTORY_USER, ARTIFACTORY_TOKEN

# 3. Configure GitHub Environment 'production' with required reviewers (yourself)

# 4. Push the workflow + manifests
git add . && git commit -m "feat: end-to-end pipeline" && git push origin main

# 5. Watch the pipeline in the Actions tab
#    test → build-and-push → (manual approval) → deploy → smoke

# 6. Verify in cluster
kubectl get deploy,svc,pods
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$DNS/version
```

## Prerequisites

- Demos 21, 27, 30, 31 understood.
- EKS cluster from Demo 31 already running.
- GitHub repo with these secrets configured:
  - `AWS_ACCESS_KEY`, `AWS_SECRET_KEY` (or use OIDC role)
  - `ARTIFACTORY_URL`, `ARTIFACTORY_USER`, `ARTIFACTORY_TOKEN`

## Learning Objectives

- Build a complete pipeline: code → unit test → Docker image → JFrog
  Artifactory → EKS deploy.
- Use **environments** for staged promotion.
- Tear everything down cleanly.

## Concepts Covered

- Putting **all** prior demos together.
- GitHub Actions cross-stage artifact: image tag in JFrog.
- `aws eks update-kubeconfig` from CI.
- `kubectl apply -f deployment.yaml` with image tag substitution.

## Architecture

```
   git push (main)
        │
        ▼
   GitHub Actions
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ 1. lint  ─►  2. test  ─►  3. build+push  ─►  4. deploy(EKS)  ─► 5. smoke│
   │                              │                  │                       │
   │                              ▼                  ▼                       │
   │                       JFrog Artifactory   `kubectl apply`               │
   │                       <repo>/devops:SHA   to devops-cluster             │
   └─────────────────────────────────────────────────────────────────────────┘
```

## Expected Output

Pipeline:
```
✅ test               (45s)
✅ build-and-push     (90s)   image: <artifactory>/<repo>/oe-devops:<sha>
🟡 deploy             (waiting for review...)
   ► approve
✅ deploy             (60s)
✅ smoke              (15s)   {"status":"OK","message":"The application is healthy!"}
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unauthorized` pushing to JFrog | Wrong secret value | Re-add ARTIFACTORY_TOKEN |
| `Could not connect to the cluster` | AWS creds wrong / region typo | Re-check `AWS_*` secrets and region |
| `ImagePullBackOff` after deploy | Pull secret missing in target namespace | Workflow already creates it; check namespace |
| Smoke test times out | NLB target unhealthy | `kubectl describe svc`; ensure readiness probe path correct |

## Best Practices

- **Tag images with the git SHA**, not `latest`.
- Render manifests at deploy time with the **actual image SHA**.
- Gate prod deploys with a **GitHub Environment + reviewers**.
- Use `cache-from`/`cache-to` to keep Docker builds fast.
- Run `kubectl rollout status --timeout` so the job fails fast on stuck rollouts.

## Production Considerations

- Replace AWS access keys with **OIDC federation** (`aws-actions/configure-aws-credentials` + `role-to-assume`).
- Use **Helm** or **kustomize** instead of `sed`-templating.
- Add **canary** rollouts (Argo Rollouts/Flagger) and automated rollback on SLO breach.
- Deploy via **GitOps** (Argo CD) — CI builds & pushes; Argo applies from Git.
- Add **post-deploy verification**: synthetic monitor, smoke suite, anomaly detection.

## Optional Advanced Enhancements

- Add a **dev** environment that auto-deploys on PRs (preview environments).
- Drive deploys via **Argo CD** with the workflow only updating an image tag in a manifest repo.
- Add **DORA metric** export at the end of each deploy.
- Add **Slack notification** on success/failure.

## Instructor Notes

- This demo lives at the end of Day 3. Block out 60–90 min for it.
- Have students individually run it from THEIR repos against the SAME EKS
  cluster (use distinct namespaces or initials in image names to avoid clashes).
- Show how a failing test halts the whole pipeline before deploying.

## Real-World Relevance

This is the canonical "deploy to Kubernetes from CI" pipeline used by thousands
of services. Substitute "JFrog → ECR" and you have the AWS-native version;
"EKS → GKE" gives you the GCP version. The shape doesn't change.
