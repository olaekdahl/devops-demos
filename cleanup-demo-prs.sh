#!/usr/bin/env bash
# cleanup-demo-prs.sh — Wipe demo-generated branches and PRs.
#
# DESTRUCTIVE. Closes every open PR (except those targeting protected branches
# you list as KEEP), deletes every remote branch except KEEP, and prunes every
# local branch except KEEP.
#
# Usage:
#   ./cleanup-demo-prs.sh           # dry-run (shows what would happen)
#   ./cleanup-demo-prs.sh --yes     # actually do it
#   ./cleanup-demo-prs.sh --yes --keep main --keep develop
#
# Requires: git, gh (authenticated).

set -euo pipefail
cd "$(dirname "$0")"

DRY_RUN=1
KEEP=()

while (( $# )); do
  case "$1" in
    -y|--yes)  DRY_RUN=0; shift ;;
    -k|--keep) KEEP+=("${2:?--keep needs a value}"); shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *)         echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Default keep list
[[ ${#KEEP[@]} -eq 0 ]] && KEEP=(main)

command -v gh >/dev/null || { echo "gh CLI required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }

# Build a regex of branches to keep
keep_regex="^($(IFS='|'; echo "${KEEP[*]}"))$"

run() {
  if (( DRY_RUN )); then
    echo "DRY-RUN: $*"
  else
    echo "+ $*"
    "$@"
  fi
}

echo "Keep list: ${KEEP[*]}"
(( DRY_RUN )) && echo "(dry-run — pass --yes to actually delete)"
echo

# 1. Move to a kept branch first so we can delete others
SAFE_BRANCH="${KEEP[0]}"
current="$(git branch --show-current || true)"
if [[ "$current" != "$SAFE_BRANCH" ]]; then
  if (( DRY_RUN )); then
    echo "DRY-RUN: git checkout $SAFE_BRANCH"
  else
    git checkout "$SAFE_BRANCH" --quiet
  fi
fi

# 2. Close all open PRs (also deletes their head branches when --delete-branch is set)
echo "── Open PRs ──"
mapfile -t PRS < <(gh pr list --state open --json number,headRefName --jq '.[] | "\(.number)\t\(.headRefName)"')
if (( ${#PRS[@]} == 0 )); then
  echo "  (none)"
else
  for entry in "${PRS[@]}"; do
    num="${entry%%$'\t'*}"
    head="${entry##*$'\t'}"
    if [[ "$head" =~ $keep_regex ]]; then
      echo "  skip PR #$num (head=$head is in keep list)"
      continue
    fi
    run gh pr close "$num" --delete-branch --comment "Closed by cleanup-demo-prs.sh"
  done
fi
echo

# 3. Fetch + prune to drop refs to deleted remote branches
run git fetch --all --prune --quiet || true

# 4. Delete remaining remote branches
echo "── Remote branches ──"
mapfile -t REMOTE_BRANCHES < <(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/**' \
  | sed 's|^origin/||' | grep -vE '^(HEAD|origin)?$' | sort -u)
for b in "${REMOTE_BRANCHES[@]}"; do
  [[ -z "$b" ]] && continue
  if [[ "$b" =~ $keep_regex ]]; then
    echo "  keep origin/$b"
    continue
  fi
  run git push origin --delete "$b"
done
echo

# 5. Delete local branches
echo "── Local branches ──"
mapfile -t LOCAL_BRANCHES < <(git for-each-ref --format='%(refname:short)' refs/heads)
for b in "${LOCAL_BRANCHES[@]}"; do
  if [[ "$b" =~ $keep_regex ]]; then
    echo "  keep $b"
    continue
  fi
  run git branch -D "$b"
done
echo

# 6. Final prune
run git remote prune origin >/dev/null 2>&1 || true

echo "Done."
(( DRY_RUN )) && echo "Re-run with --yes to apply."
