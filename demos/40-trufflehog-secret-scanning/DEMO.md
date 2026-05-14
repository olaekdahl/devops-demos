# Demo 40 — TruffleHog Secret Scanning

## How to Run

Run this demo from inside this folder:

```bash
# 1) Create a temporary file with intentionally fake sensitive values.
P1='xo'
P2='xb-123456789012-123456789012-12345678901234567890123456789012'
printf 'SLACK_BOT_TOKEN=%s%s\n' "$P1" "$P2" > /tmp/trufflehog-demo-leak.txt

# 2) Scan the file with TruffleHog (Docker image).
docker run --rm -v /tmp:/scan -w /scan \
  ghcr.io/trufflesecurity/trufflehog:3.95.3 \
  filesystem . --results=verified,unknown --fail
```

## Prerequisites

- Docker
- A GitHub repository with Actions enabled

## Learning Objectives

- Detect hardcoded credentials and sensitive material before merge.
- Run TruffleHog automatically on pull requests.
- Understand diff-based PR scanning (`base` → `head`) to catch only new leaks.

## Workflow in this Demo

- `.github/workflows/trufflehog.yaml` runs on pull requests.
- The workflow checks out full git history, then scans the PR diff with TruffleHog.
- The job fails if verified/unknown secrets are detected.

## Expected Output

When scanning the intentionally leaky `/tmp/trufflehog-demo-leak.txt`, TruffleHog should report findings and exit non-zero because `--fail` is set.

## Best Practices

- Keep generated or intentionally vulnerable files out of the repository.
- Scan pull requests, not just default branches.
- Pair TruffleHog with secret rotation playbooks so findings can be remediated quickly.
