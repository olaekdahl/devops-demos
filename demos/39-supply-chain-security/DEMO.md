# Demo 39 — Supply Chain Security for a Global Consulting Firm

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 0) Prerequisites
cosign version                   # ≥ 2.4
syft   version                   # ≥ 1.0
gh     auth status               # logged in to GitHub
docker version                   # ≥ 25

# 1) Push the demo to a fresh repo
gh repo create firm/supply-chain-demo --private --source=. --push

# 2) In GitHub UI: Settings → Environments → New environment "release"
#    Add 'Required reviewers' = your sec-team. This is the credential gate.

# 3) Watch CI run on push
gh run watch

# 4) Cut a release. The release.yaml workflow will PAUSE for approval.
git tag v1.0.0 && git push origin v1.0.0
gh run watch                     # approve in UI when prompted

# 5) Verify the release like a customer would
DIGEST=$(gh api /users/$(gh api /user -q .login)/packages/container/supply-chain-demo/versions \
         | jq -r '.[0].name')
bash scripts/verify-release.sh ghcr.io/firm/supply-chain-demo@$DIGEST

# 6) ── LIVE ATTACK 1: expression injection ──────────────
cp .github/SHOULD-FAIL/bad-injection.yaml .github/workflows/
git add . && git commit -m "demo: add vulnerable workflow" -s && git push
# Watch CodeQL + actionlint flag it; the PR can never merge.

# 7) ── LIVE ATTACK 2: mutable tag hijack ────────────────
# Show that even if attacker repoints `actions/checkout@v4`, our pinned-by-SHA
# workflow ignores them. Open the actionlint output for SHOULD-FAIL/bad-mutable-tag.

# 8) ── LIVE ATTACK 3: typosquat ────────────────────────
echo "requets==2.31.0" >> requirements.txt    # note the missing 'q'
bash scripts/detect-typosquat.sh              # exits 1, blocks the PR

# 9) Cleanup demo artifacts (do NOT delete the released image — it's signed proof)
git checkout .github/workflows/ requirements.txt
```

## Prerequisites

- A GitHub repository (private is fine) you can push to.
- `gh` CLI authenticated, `cosign` ≥ 2.4, `syft` ≥ 1.0, `docker` ≥ 25, `jq`.
- Optional: `slsa-verifier` for offline SLSA attestation checks.

## Learning Objectives

- Articulate the supply-chain attack surface of a CI/CD pipeline.
- Implement **defense in depth**: trigger control → SHA pinning → least-privilege tokens → environment isolation → signing + SBOM + SLSA provenance → consumer-side verification.
- Detect and remediate three real classes of attack live: a **mutable-tag hijack**, a **GitHub Actions expression-injection**, and a **typosquatted dependency**.
- Verify a published image with `cosign verify` and inspect its SBOM and provenance.

## Concepts Covered

- Supply chain attack patterns (SolarWinds, axios npm, LiteLLM PyPI, typosquatted Trivy)
- Pinning by **40-char commit SHA** for actions, **`@sha256:` digest** for images
- Two-phase checkout for `pull_request_target`
- `permissions:` least-privilege per workflow
- GitHub **protected environments** for production credentials (CI vs. prod isolation)
- **Sigstore Cosign** keyless signing (OIDC, no long-lived keys)
- **SBOM** generation (SPDX) + cosign attestation
- **SLSA build provenance** (level 3, `slsa-framework/slsa-github-generator`)
- **CODEOWNERS** as a review gate for `.github/`
- **Renovate** with `pinDigests` + `minimumReleaseAge` cooldown
- **OpenSSF Scorecard**, **actionlint**, **CodeQL**, **StepSecurity Harden-Runner**, **dependency-review-action**, **govulncheck**, **trivy** image scanning
- Signed commits (DCO / `Signed-off-by` enforcement)

## Architecture

```
   Contributor
        │
        ▼
   ┌──────────────────── Pull Request ─────────────────────┐
   │ CODEOWNERS gate → security review required on .github/│
   └───────────────────────────┬───────────────────────────┘
                               │
                               ▼
   ┌──────────────────── PR-time controls ────────────────┐
   │  • dependency-review (vulns + license policy)        │
   │  • actionlint + CodeQL on workflows                  │
   │  • govulncheck / pip-audit / trivy fs                │
   └───────────────────────────┬──────────────────────────┘
                               │ merge to main
                               ▼
   ┌──────────────── Build job (least-privilege) ─────────┐
   │  permissions: contents:read                          │
   │  StepSecurity Harden-Runner: audit egress            │
   │  build-push-action@<SHA>  →  trivy image scan        │
   └───────────────────────────┬──────────────────────────┘
                               │ tag v*.*.*
                               ▼
   ┌──────────── Release env (manual approval) ───────────┐
   │  cosign sign (keyless OIDC)                          │
   │  Syft SBOM (SPDX) + cosign attest                    │
   │  SLSA Level 3 build provenance                       │
   └───────────────────────────┬──────────────────────────┘
                               │ push
                               ▼
   registry: ghcr.io/firm/app@sha256:…
                               │ pull
                               ▼
   ┌──────────────────── Client cluster ──────────────────┐
   │  Sigstore policy-controller: cosign verify on admit  │
   └──────────────────────────────────────────────────────┘
```

## Expected Output

`verify-release.sh` (truncated):
```
==> 1/4 Verify Cosign keyless signature
[
  {
    "critical": { "identity": { "docker-reference": "ghcr.io/firm/supply-chain-demo" },
                  "image":    { "docker-manifest-digest": "sha256:..." },
                  "type":     "cosign container image signature" },
    "optional": { "Issuer":  "https://token.actions.githubusercontent.com",
                  "Subject": "https://github.com/firm/supply-chain-demo/.github/workflows/release.yaml@refs/tags/v1.0.0" }
  }
]
==> 2/4 Verify SBOM attestation exists and is SPDX
"ghcr.io/firm/supply-chain-demo"
==> 3/4 Verify SLSA build provenance (level 3)
"https://slsa-framework.github.io/github-actions-buildtypes/workflow/v1"
==> 4/4 Optional: scan for new CVEs since release
0 HIGH/CRITICAL vulnerabilities
✅ Image ghcr.io/firm/supply-chain-demo@sha256:... is verified.
```

`detect-typosquat.sh`:
```
⚠ Possible typosquat candidates (HUMAN REVIEW REQUIRED):
   'requets'  ←→  popular 'requests'   (edit distance 1)
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `cosign verify`: `no matching signatures` | Image was built outside our workflow, or you forgot OIDC config | Confirm the image was built by `release.yaml`; check `--certificate-identity-regexp` matches your org |
| `release.yaml` stuck on `Waiting for approval` | Working as intended — protected env | Designated approver clicks "Review deployments" in GitHub UI |
| `actions/dependency-review-action` only reports, never fails | `fail-on-severity` missing or set too low | Set `fail-on-severity: high` |
| Trivy passes locally, fails in CI | DB out of date locally | `trivy image --download-db-only` before scanning |
| Renovate opens too many PRs | Cooldown/grouping not applied | Confirm `minimumReleaseAge` and `groupName` in `renovate.json5` |
| `cosign sign` errors `id-token: missing` | Workflow forgot `permissions: id-token: write` | Add it under that job |
| SLSA reusable workflow can't push | Need `packages: write` on the **caller** job's permissions | Add it (see `release.yaml`) |
| `harden-runner` blocks legitimate egress | Audit mode finished — switched to block too early | Stay in `audit` until you have a stable allow-list, then switch to `egress-policy: block` |

## Best Practices

- **Pin everything by digest** — actions by 40-char SHA, base images by `@sha256:`. Use Renovate to keep current.
- **Least privilege at the workflow root** — start with `permissions: {}`, opt jobs in.
- **Two-environment model** — `ci` env for build creds, `release` env (with manual approval) for production creds.
- **Sign + attest + verify** — Cosign + SBOM + SLSA Level 3 must all succeed *before* anyone trusts the image.
- **CODEOWNERS for `.github/`** — non-negotiable. Anyone editing CI must get sec-team review.
- **Cooldown new releases** — 5 days is a reasonable default; the axios/LiteLLM/`utfave` poisonings were all detected within hours-to-days.
- **Block, don't warn** — every scanner above runs with `exit-code: 1`. Warnings get ignored.

## Production Considerations

- **Centralize policies** with Org Rulesets (GitHub) or OPA/Conftest so 200+ repos can't drift.
- **Forward CI logs** to your SIEM (Splunk/Datadog) — Actions Data Stream coming in 2026.
- **Adopt OIDC federation** to AWS/GCP/Azure (no long-lived cloud keys in CI).
- **Use a private Renovate runner** with a fine-grained GitHub App, not a PAT.
- **Audit your SBOMs** — feed them into a vuln management platform (Dependency-Track, Anchore Enterprise) for ongoing CVE matching long after release.
- **Annual third-party audit** — Trail of Bits, NCC, ADA Logics. Publish the report.
- **Maintain a `SECURITY-INSIGHTS.yml`** (OpenSSF) and refresh it quarterly.
- **Enforce DCO / signed commits** via repo rule.
- **Tag immutability** in repo settings: once `v1.0.0` is published it cannot be moved.

## Optional Advanced Enhancements

- **Sigstore policy-controller** in every client cluster — refuse to schedule unsigned pods (`policy/cosign-verify.yaml`).
- **Reusable workflows** (`workflows/release.yaml` becomes `firm/.github/workflows/release.yaml@<sha>`) so 200 repos share one hardened pipeline.
- **GUAC** to graph all your SBOMs and provenance and answer "which clients have log4j?" in seconds.
- **Tetragon / Falco** runtime monitoring on the build runners themselves — catches a compromised CI step exfiltrating secrets in real time.
- **Hermetic builds** with Bazel + `--config=remote` and a private artifact mirror so build hosts have no internet at all (StepSecurity Harden-Runner `egress-policy: block` with explicit allow-list).
- **Annual purple-team exercise** — your red team plants a typosquatted dep and expression-injection PR. Measure detection time.


## Real-World Relevance

A global software delivery organization ships software into thousands of customer environments — banks,
hospitals, governments. A **single compromised CI build** that pushes a malicious image to a customer's
production cluster is a SolarWinds-class incident: regulatory fines (GDPR, SOX, HIPAA), client lawsuits,
loss of professional license, reputational collapse. Cyber-insurance carriers now **require** SBOM + signing
before underwriting. Many federal/EU contracts demand SLSA Level 3 attestations.

This demo gives engineers a **drop-in starter pack** they can adapt for new delivery environments on day one.
