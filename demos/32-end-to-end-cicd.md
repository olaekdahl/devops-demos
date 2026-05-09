# Demo 32 — End-to-End CI/CD (Capstone)

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

## Real-World Relevance
This is the canonical "deploy to Kubernetes from CI" pipeline used by thousands
of services. Substitute "JFrog → ECR" and you have the AWS-native version;
"EKS → GKE" gives you the GCP version. The shape doesn't change.

## Demo Architecture
```
   git push (main)
        │
        ▼
   GitHub Actions
   ┌──────────────────────────────────────────────┐
   │ 1. lint   ─►  2. test ─►  3. build+push  ─►  4. deploy(EKS)  ─► 5. smoke
   │                              │                  │
   │                              ▼                  ▼
   │                       JFrog Artifactory   `kubectl apply`
   │                       <repo>/devops:SHA   to devops-cluster
   └──────────────────────────────────────────────┘
```

## Instructor Notes
- This demo lives at the end of Day 3. Block out 60–90 min for it.
- Have students individually run it from THEIR repos against the SAME EKS
  cluster (use distinct namespaces or initials in image names to avoid clashes).
- Show how a failing test halts the whole pipeline before deploying.

## Prerequisites
- Demos 21, 27, 30, 31 understood.
- EKS cluster from Demo 31 already running.
- GitHub repo with these secrets configured:
  - `AWS_ACCESS_KEY`, `AWS_SECRET_KEY` (or use OIDC role)
  - `ARTIFACTORY_URL`, `ARTIFACTORY_USER`, `ARTIFACTORY_TOKEN`

## Folder Structure
```
demos/32-end-to-end-cicd/
  app.py, requirements.txt, tests/test_app.py
  Dockerfile
  deployment.yaml
  .github/workflows/cicd-eks.yaml
```

## Complete Code

Re-use `app.py`, `requirements.txt`, `tests/test_app.py`, `Dockerfile` from
sample-app + Demo 15.

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
        - name: jfrog-pull-secret
      containers:
        - name: app
          image: __IMAGE__              # replaced at deploy time with full ref
          imagePullPolicy: Always
          ports: [{ containerPort: 8000 }]
          readinessProbe:
            httpGet: { path: /health, port: 8000 }
          livenessProbe:
            httpGet: { path: /health, port: 8000 }
            initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: devops-app-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector: { app: devops-app }
  ports: [{ port: 80, targetPort: 8000 }]
```

`.github/workflows/cicd-eks.yaml`
```yaml
name: CI/CD to EKS

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write             # if you adopt OIDC; not needed for access-key auth

env:
  AWS_REGION:    us-west-2
  CLUSTER_NAME:  devops-cluster
  REPO_PATH:     devops-docker-local        # Artifactory repo
  IMAGE_NAME:    ${{ github.actor }}-devops # unique per student

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false                  # NEVER cancel an in-flight prod deploy

jobs:

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt pytest httpx
      - run: PYTHONPATH=$(pwd) pytest -v tests/

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.tag.outputs.image }}
    steps:
      - uses: actions/checkout@v4
      - id: tag
        run: |
          TAG="${{ github.sha }}"
          IMG="${{ secrets.ARTIFACTORY_URL }}/${{ env.REPO_PATH }}/${{ env.IMAGE_NAME }}:${TAG}"
          echo "image=$IMG" >> "$GITHUB_OUTPUT"
      - uses: docker/setup-buildx-action@v3
      - name: Login to JFrog Artifactory
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.ARTIFACTORY_URL }}
          username: ${{ secrets.ARTIFACTORY_USER }}
          password: ${{ secrets.ARTIFACTORY_TOKEN }}
      - name: Build & push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.tag.outputs.image }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production            # add manual approval in Settings → Environments
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY }}
          aws-region:            ${{ env.AWS_REGION }}

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Ensure pull secret exists
        run: |
          kubectl create secret docker-registry jfrog-pull-secret \
            --docker-server="${{ secrets.ARTIFACTORY_URL }}" \
            --docker-username="${{ secrets.ARTIFACTORY_USER }}" \
            --docker-password="${{ secrets.ARTIFACTORY_TOKEN }}" \
            --docker-email="ci@example.com" \
            --dry-run=client -o yaml | kubectl apply -f -

      - name: Render manifest with image tag
        run: |
          sed "s|__IMAGE__|${{ needs.build-and-push.outputs.image }}|g" \
            deployment.yaml > rendered.yaml
          cat rendered.yaml

      - name: Apply
        run: |
          kubectl apply -f rendered.yaml
          kubectl rollout status deployment/devops-app --timeout=180s

      - name: Smoke test
        run: |
          # wait up to 2 min for the LB DNS to populate
          for i in $(seq 1 24); do
            DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            [ -n "$DNS" ] && break
            sleep 5
          done
          echo "App at: http://$DNS"
          for i in $(seq 1 30); do
            if curl -sf "http://$DNS/health" > /dev/null; then
              curl -s "http://$DNS/health" | tee health.json
              exit 0
            fi
            sleep 5
          done
          echo "smoke test failed"
          kubectl describe deploy devops-app
          exit 1
```

## Step-by-Step Walkthrough

```bash
# 1. Verify EKS is running (Demo 31)
kubectl get nodes

# 2. Set GitHub secrets in your repo:
#    AWS_ACCESS_KEY, AWS_SECRET_KEY,
#    ARTIFACTORY_URL, ARTIFACTORY_USER, ARTIFACTORY_TOKEN

# 3. Configure GitHub Environment 'production' with required reviewers (yourself)

# 4. Push the workflow + manifests
cd demos/32-end-to-end-cicd
git add . && git commit -m "feat: end-to-end pipeline" && git push origin main

# 5. Watch the pipeline in the Actions tab
#    test → build-and-push → (manual approval) → deploy → smoke

# 6. Verify in cluster
kubectl get deploy,svc,pods
DNS=$(kubectl get svc devops-app-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$DNS/version
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

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `unauthorized` pushing to JFrog | Wrong secret value | Re-add ARTIFACTORY_TOKEN |
| `Could not connect to the cluster` | AWS creds wrong / region typo | Re-check `AWS_*` secrets and region |
| `ImagePullBackOff` after deploy | Pull secret missing in target namespace | Workflow already creates it; check namespace |
| Smoke test times out | NLB target unhealthy | `kubectl describe svc`; ensure readiness probe path correct |

## DevOps Best Practices
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

## Tear Down (don't skip!)
```bash
# Remove K8s resources
kubectl delete deploy devops-app
kubectl delete svc devops-app-lb        # destroys the NLB

# Destroy EKS cluster
eksctl delete cluster -f ../31-eks/single-node-cluster.yaml
```

## Optional Advanced Enhancements
- Add a **dev** environment that auto-deploys on PRs (preview environments).
- Drive deploys via **Argo CD** with the workflow only updating an image tag in a manifest repo.
- Add **DORA metric** export at the end of each deploy.
- Add **Slack notification** on success/failure.
