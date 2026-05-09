#!/usr/bin/env bash
# Extracted commands from 39-supply-chain-security.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# 0) Prerequisites
cosign version                   # ≥ 2.4
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

# 6) ── LIVE ATTACK 1: expression injection ──────────────
cp .github/SHOULD-FAIL/bad-injection.yaml .github/workflows/
# git add . && git commit -m "demo: add vulnerable workflow" -s && git push  # parent-repo op — review & run manually
# Watch CodeQL + actionlint flag it; the PR can never merge.

# 7) ── LIVE ATTACK 2: mutable tag hijack ────────────────
# Show that even if attacker repoints `actions/checkout@v4`, our pinned-by-SHA
# workflow ignores them. Open the actionlint output for SHOULD-FAIL/bad-mutable-tag.

# 8) ── LIVE ATTACK 3: typosquat ────────────────────────
echo "requets==2.31.0" >> requirements.txt    # note the missing 'q'

# 9) Cleanup demo artifacts (do NOT delete the released image — it's signed proof)
git checkout .github/workflows/ requirements.txt

# --- next block ---

# 0) Prerequisites
cosign version                   # ≥ 2.4
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

# 6) ── LIVE ATTACK 1: expression injection ──────────────
cp .github/SHOULD-FAIL/bad-injection.yaml .github/workflows/
# git add . && git commit -m "demo: add vulnerable workflow" -s && git push  # parent-repo op — review & run manually
# Watch CodeQL + actionlint flag it; the PR can never merge.

# 7) ── LIVE ATTACK 2: mutable tag hijack ────────────────
# Show that even if attacker repoints `actions/checkout@v4`, our pinned-by-SHA
# workflow ignores them. Open the actionlint output for SHOULD-FAIL/bad-mutable-tag.

# 8) ── LIVE ATTACK 3: typosquat ────────────────────────
echo "requets==2.31.0" >> requirements.txt    # note the missing 'q'

# 9) Cleanup demo artifacts (do NOT delete the released image — it's signed proof)
git checkout .github/workflows/ requirements.txt