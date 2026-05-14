# Demo 33 — Production Pipeline Concepts

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
git add . && git commit -m "ci: production pipeline" && git push
```

## Prerequisites

- Demo 32 understood.
- `cosign`, `syft`, `trivy` available (or installed via actions).

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

## Architecture

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

## Walkthrough

1. Walk through each job and explain the "why".
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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Trivy blocks legit deps | Unfixed CVE | Use `ignore-unfixed: true` or pin a patched version |
| Cosign sign fails | Missing `id-token: write` | Add to `permissions:` |
| Conftest deny | Used `:latest` somewhere | Remove tag, use SHA |
| Canary doesn't auto-promote | Manual gate not satisfied | Approve the environment |

## Best Practices

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


## Real-World Relevance

Real organizations are audited (SOC 2, ISO, PCI). They also get attacked. A
hardened pipeline reduces both risk and audit pain.
