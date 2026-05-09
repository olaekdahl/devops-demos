# BCG DevOps — WA3647-03 Instructor Demos

Hands-on demos for the **WA3647-03 DevOps Fundamentals** course (3-day
instructor-led). 38 demos covering DevOps culture → Git/GitHub → GitHub Actions
CI/CD → Docker → Kubernetes → JFrog Artifactory → AWS EKS → observability,
troubleshooting, and anti-patterns.

## Layout

```
demos/
  00-OVERVIEW.md         # Index + conventions
  sample-app/            # Shared FastAPI app reused across demos
  NN-topic/              # One folder per demo (38 of them)
    DEMO.md              #   instructor narrative
    README.md            #   how-to-run cheat-sheet
    commands.sh          #   all shell commands, executable
    <code files>         #   workflows / manifests / Dockerfiles / app code
tools/
  extract_demos.py       # Regenerates demo folders from the NN-*.md sources
.gitignore
```

## Quick start

```bash
# Run the shared sample app
cd demos/sample-app
make install && make run     # http://localhost:8000

# Run any demo
cd demos/18-docker-compose
docker compose up -d --build
```

## Regenerate demo folders

The folders under `demos/NN-topic/` are produced by `tools/extract_demos.py`
from the `demos/NN-topic.md` source files. After editing a `.md`:

```bash
python3 tools/extract_demos.py
```

## Prerequisites by demo group

| Demos | Tools |
|---|---|
| 01–05 | git, gh CLI |
| 06–13 | git, GitHub repo, optionally `act`/`actionlint` |
| 14–18 | Docker / Docker Compose |
| 19–28 | Docker, `kind`, `kubectl` |
| 29–32 | Docker, `kubectl`, `eksctl`, AWS CLI v2, JFrog account |
| 33–38 | All of the above + `helm` |

See [demos/00-OVERVIEW.md](demos/00-OVERVIEW.md) for the full demo index.
