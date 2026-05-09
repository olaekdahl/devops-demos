# DevOps Fundamentals — Instructor Demos (WA3647-03)

These demos accompany the **WA3647-03 DevOps Fundamentals** course. They are
designed for **live classroom delivery** by an instructor. Production-realistic,
but simplified for teaching: minimal files, lots of comments, intentional
failures so students see real troubleshooting.

## Shared sample application

Most demos starting at #9 use the same FastAPI app from the lab (`app.py`). The
canonical copy lives in [sample-app/](sample-app/) — `make install && make run`
to try it. The extractor (`tools/extract_demos.py`) automatically copies it
into demos that need it, so each demo folder is **fully self-contained and
runnable**.

## Per-demo folder layout

Each `NN-topic/` folder contains:

| File | Purpose |
|---|---|
| `DEMO.md` | Full instructor narrative (objectives, walkthrough, failure modes, best practices) |
| `README.md` | Short "how to run this" cheat-sheet |
| `commands.sh` | All shell commands from the demo, concatenated and executable |
| code files | Workflows, manifests, Dockerfiles, app code — extracted from `DEMO.md` |
| `app.py`, `tests/`, `requirements*.txt`, `Dockerfile` | Sample-app artifacts (when relevant) |

> **To regenerate everything from the markdown sources** run:
> `python3 tools/extract_demos.py`

## Conventions

- All YAML, Dockerfile, Python is current as of 2025/2026.
- `actions/checkout@v4`, `actions/setup-python@v5`, `python:3.12-slim`, `kubectl` ≥ 1.30, Kubernetes Gateway API v1, AWS CLI v2, `eksctl` latest.
- `<initials>` placeholders → instructor replaces with their initials live.
- Every demo file is **self-contained** — full code inside, no "see other file."

## Demo Index

| # | File | Topic |
|---|------|-------|
| 1 | [01-devops-fundamentals/](01-devops-fundamentals/) | What DevOps is and why |
| 2 | [02-git-fundamentals/](02-git-fundamentals/) | Git CLI essentials |
| 3 | [03-github-fundamentals/](03-github-fundamentals/) | Repos, remotes, PAT |
| 4 | [04-pull-requests/](04-pull-requests/) | Branching + PR review |
| 5 | [05-github-issues/](05-github-issues/) | Issues + commit linking |
| 6 | [06-github-actions-basics/](06-github-actions-basics/) | First workflow |
| 7 | [07-workflow-triggers/](07-workflow-triggers/) | push/PR/schedule/manual |
| 8 | [08-cicd-pipelines/](08-cicd-pipelines/) | End-to-end CI/CD |
| 9 | [09-unit-testing/](09-unit-testing/) | pytest in CI |
| 10 | [10-matrix-builds/](10-matrix-builds/) | `strategy.matrix` |
| 11 | [11-parallel-jobs/](11-parallel-jobs/) | Independent jobs |
| 12 | [12-sequential-pipelines/](12-sequential-pipelines/) | `needs:` |
| 13 | [13-secrets-management/](13-secrets-management/) | Repo / env / OIDC |
| 14 | [14-docker-fundamentals/](14-docker-fundamentals/) | Namespaces/cgroups, images vs containers |
| 15 | [15-docker-build-process/](15-docker-build-process/) | Layers + cache |
| 16 | [16-docker-networking/](16-docker-networking/) | bridge/host/user-defined |
| 17 | [17-docker-debugging/](17-docker-debugging/) | logs / exec / inspect |
| 18 | [18-docker-compose/](18-docker-compose/) | Multi-container apps |
| 19 | [19-kubernetes-fundamentals/](19-kubernetes-fundamentals/) | Why K8s, control plane |
| 20 | [20-kind-local-clusters/](20-kind-local-clusters/) | Local dev cluster |
| 21 | [21-kubernetes-deployments/](21-kubernetes-deployments/) | Pods/RS/Deploy |
| 22 | [22-kubernetes-services/](22-kubernetes-services/) | ClusterIP/NodePort/LB |
| 23 | [23-ingress/](23-ingress/) | NGINX Ingress |
| 24 | [24-gateway-api/](24-gateway-api/) | GatewayClass/Gateway/HTTPRoute |
| 25 | [25-scaling-workloads/](25-scaling-workloads/) | Manual + HPA |
| 26 | [26-configmaps/](26-configmaps/) | Env + mounted config |
| 27 | [27-secrets-k8s/](27-secrets-k8s/) | Secret types + mounting |
| 28 | [28-persistent-storage/](28-persistent-storage/) | PV/PVC/StorageClass |
| 29 | [29-container-registries/](29-container-registries/) | Registry concepts |
| 30 | [30-jfrog-artifactory/](30-jfrog-artifactory/) | Push/pull via Artifactory |
| 31 | [31-eks-deployments/](31-eks-deployments/) | `eksctl` + deploy |
| 32 | [32-end-to-end-cicd/](32-end-to-end-cicd/) | Capstone pipeline |
| 33 | [33-production-pipeline-concepts/](33-production-pipeline-concepts/) | Real prod pipelines |
| 34 | [34-troubleshooting-pipelines/](34-troubleshooting-pipelines/) | Debugging Actions |
| 35 | [35-troubleshooting-kubernetes/](35-troubleshooting-kubernetes/) | `kubectl` toolbox |
| 36 | [36-devops-anti-patterns/](36-devops-anti-patterns/) | What NOT to do |
| 37 | [37-observability-basics/](37-observability-basics/) | Metrics/logs/traces |
| 38 | [38-logging-and-monitoring/](38-logging-and-monitoring/) | Stack walkthrough |
