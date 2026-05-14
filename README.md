# DevOps Fundamentals — Hands-On Demos

Hands-on demos covering DevOps culture → Git/GitHub → GitHub Actions CI/CD → Docker → Kubernetes → JFrog Artifactory → AWS EKS → observability, troubleshooting, anti-patterns, and software supply chain security.

## Layout

```
demos/
  README.md              # Index of all demos
  sample-app/            # Shared FastAPI app reused across demos
  NN-topic/              # One self-contained folder per demo (40 of them)
    DEMO.md              #   leads with "How to Run", then explanation
    <code files>         #   workflows / manifests / Dockerfiles / app code
tools/
  check_diagrams.py      # Validates ASCII box diagrams in DEMO.md files
.gitignore
```

## Quick start

Each demo folder is self-contained. To run a demo, `cd` into it and follow the **How to Run** section at the top of its `DEMO.md`. Example:

```bash
cd demos/18-docker-compose
docker compose up -d --build
```

To run the shared sample app on its own:

```bash
cd demos/sample-app
make install && make run     # http://localhost:8000
```

## Prerequisites by demo group

| Demos | Tools |
|---|---|
| 01–05 | git, gh CLI |
| 06–13 | git, GitHub repo, optionally `act` / `actionlint` |
| 14–18 | Docker / Docker Compose |
| 19–28 | Docker, `kind`, `kubectl` |
| 29–32 | Docker, `kubectl`, `eksctl`, AWS CLI v2, JFrog account |
| 33–38 | All of the above + `helm` |
| 39–40 | `cosign`, `syft`, GitHub repo with Actions enabled |

See [demos/README.md](demos/README.md) for the full demo index.
