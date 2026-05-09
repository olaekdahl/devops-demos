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
