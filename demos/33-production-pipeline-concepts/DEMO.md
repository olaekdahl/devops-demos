# Demo 33 — Production Pipeline Concepts

## Learning Objectives
- Identify the differences between a teaching pipeline (Demo 32) and a real
  production pipeline.
- Add the critical missing pieces: SAST/SCA/container scan, SBOM, signing,
  policy gates, progressive delivery, automated rollback.

## Concepts Covered
- Defense in depth in the CI/CD chain
- Supply-chain security (SLSA, SBOMs, signing)
- Progressive delivery (canary, blue/green)
- Policy as code (OPA / Conftest)
- Observability hooks at each stage

## Quick Start
Push the workflow and observe the full quality → build → policy → canary → promote pipeline.

```bash
cd demos/33-production-pipeline-concepts
git add . && git commit -m "ci: production pipeline" && git push
```

Watch in the **Actions** tab. Approve the `production` environment when prompted. The `rollback-on-failure` job runs only when an upstream job fails — to demo it, push a commit that intentionally breaks the trivy scan or policy check.

## Real-World Relevance
Real organizations are audited (SOC 2, ISO, PCI). They also get attacked. A
hardened pipeline reduces both risk and audit pain.

## Demo Architecture
```
   PR ─►  lint  ─►  unit tests  ─►  SAST (semgrep)  ─►  SCA (pip-audit)
                                                            │
                                                            ▼
                                build & SBOM (syft)  ─►  scan (trivy)
                                                            │
                                                            ▼
                                  sign (cosign) ─►  push to registry
                                                            │
                                                            ▼
                                  policy check (OPA/conftest on YAML)
                                                            │
                                                            ▼
                                deploy → CANARY (10%) → SLO check → 100%
                                                                       │
                                                                       ▼
                                                                  on failure: ROLLBACK
```

## Instructor Notes
- This demo is mostly about **showing what production looks like**, then
  layering 1–2 features onto Demo 32 to make it tangible.
- Pick one or two enhancements to actually run (SBOM + cosign sign, plus
  Trivy scan blocks).

## Prerequisites
- Demo 32 understood.
- `cosign`, `syft`, `trivy` available (or installed via actions).

## Folder Structure
```
demos/33-production-pipeline-concepts/
  .github/workflows/prod.yaml
  policies/no-latest-tag.rego
```

## Complete Code

`policies/no-latest-tag.rego`
```rego
# Conftest / OPA policy: refuse manifests that reference :latest images.
package main

deny[msg] {
  input.kind == "Deployment"
  some i
  c := input.spec.template.spec.containers[i]
  endswith(c.image, ":latest")
  msg := sprintf("container %q uses :latest tag (forbidden)", [c.name])
}
```

`.github/workflows/prod.yaml`
```yaml
name: Production-grade pipeline

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  packages: write
  id-token: write              # cosign keyless via OIDC

env:
  IMAGE: ghcr.io/${{ github.repository_owner }}/devops-app

jobs:

  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }

      - name: Lint
        run: pip install flake8 && flake8 app.py --max-line-length=120

      - name: Unit tests
        run: |
          pip install -r requirements.txt pytest httpx
          PYTHONPATH=$(pwd) pytest -v tests/

      - name: SAST (semgrep)
        uses: returntocorp/semgrep-action@v1
        with: { config: 'p/python' }

      - name: SCA — dependency vulns
        run: pip install pip-audit && pip-audit -r requirements.txt

  build:
    needs: quality
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.push.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }}
          provenance: true
          sbom: true

      - name: Container scan (block on HIGH/CRITICAL)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}@${{ steps.push.outputs.digest }}
          severity: HIGH,CRITICAL
          exit-code: '1'
          ignore-unfixed: true

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE }}@${{ steps.push.outputs.digest }}
          format: spdx-json

      - name: Cosign keyless sign
        uses: sigstore/cosign-installer@v3
      - run: cosign sign --yes ${{ env.IMAGE }}@${{ steps.push.outputs.digest }}

  policy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install conftest
        run: |
          curl -sSLo conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/download/v0.55.0/conftest_0.55.0_Linux_x86_64.tar.gz
          tar -xzf conftest.tar.gz && sudo mv conftest /usr/local/bin/
      - name: Validate manifests
        run: conftest test deployment.yaml -p policies/

  deploy-canary:
    needs: [build, policy]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: |
          echo "Deploy 10% traffic to image @ ${{ needs.build.outputs.digest }}"
          # In real life: Argo Rollouts / Flagger AnalysisTemplate watches SLOs.
          echo "Canary running for 5 minutes; SLO probes succeed → promote."

  promote:
    needs: deploy-canary
    runs-on: ubuntu-latest
    steps:
      - run: echo "Shifting to 100% — promotion complete"

  rollback-on-failure:
    if: failure()
    needs: [deploy-canary, promote]
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "Auto-rollback to previous ReplicaSet"
          # kubectl rollout undo deployment/devops-app
```

## Step-by-Step Walkthrough
1. Walk students through each job and explain the "why".
2. Run the workflow with a clean image — should pass.
3. Inject a vulnerable dep (e.g., add `requests==2.20.0` to requirements) — Trivy
   blocks; rest of the pipeline is gated.
4. Change manifest to `image: foo:latest` — conftest job fails.
5. Show the cosign signature in GHCR's UI.

## Expected Output
On a clean PR:
```
✅ quality (lint, tests, SAST, SCA)
✅ build (image, SBOM, signed)
✅ policy
✅ deploy-canary (10%)
✅ promote (100%)
```

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Trivy blocks legit deps | Unfixed CVE | Use `ignore-unfixed: true` or pin a patched version |
| Cosign sign fails | Missing `id-token: write` | Add to `permissions:` |
| Conftest deny | Used `:latest` somewhere | Remove tag, use SHA |
| Canary doesn't auto-promote | Manual gate not satisfied | Approve the environment |

## DevOps Best Practices
- **Shift left**: SAST/SCA happen on every PR.
- **Sign every image**, verify on admission (Sigstore policy controller).
- **Policy as code** — manifests pass conftest before deploy.
- **Progressive delivery** with auto-rollback on SLO breach.

## Production Considerations
- Adopt **SLSA Level 3+** provenance; cosign attestations.
- Use **Argo Rollouts** + Prometheus AnalysisTemplates for SLO-aware canaries.
- Use **Kyverno** or **OPA Gatekeeper** to enforce policies in-cluster.
- **Audit & retention**: store SBOMs and signatures for years.

## Optional Advanced Enhancements
- Verify cosign signature in cluster via `policy-controller`.
- Generate **VEX statements** to express which CVEs do NOT affect your image.
- Add **DORA dashboard** export at the end of every deploy.
