# Demo 02 — Git Fundamentals

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
# 1. Identity (once per machine)
git config --global user.name  "Demo User"
git config --global user.email "labadmin@example.com"

# 2. Initialize
git init
git branch -m main          # rename default branch to main

# 3. First commit
echo "# Hello Git" > README.md
git status                  # README.md is "untracked"
git add README.md
git status                  # now "staged"
git commit -m "initial commit"
git log --oneline

# 4. Ignoring files
echo "venv/"        >> .gitignore
echo "__pycache__/" >> .gitignore
git add .gitignore && git commit -m "add gitignore"

# 5. Branching
git switch -c feature/greeting
echo "Hello, team!" >> README.md
git commit -am "add greeting"
git log --oneline --graph --all

# 6. Merge fast-forward
git switch main
git merge feature/greeting
git branch -d feature/greeting

# 7. Force a merge conflict (great teaching moment)
git switch -c feature/a
sed -i 's/team/devops engineers/' README.md
git commit -am "rename audience to devops engineers"

git switch main
git switch -c feature/b
sed -i 's/team/cloud engineers/' README.md
git commit -am "rename audience to cloud engineers"

git switch main
git merge feature/a            # ok
git merge feature/b            # CONFLICT
# Resolve manually, then:
git add README.md
git commit                      # editor opens with merge message
```

## Prerequisites

- Git installed (`git --version` ≥ 2.40).

## Learning Objectives

- Initialize a Git repo and configure identity.
- Stage, commit, view history, branch, merge, and resolve a conflict.
- Understand the working tree, index (staging area), and local repo.

## Concepts Covered

- `git init`, `git config`, `git add`, `git commit`, `git status`, `git log`,
  `git diff`, `git branch`, `git switch`/`checkout`, `git merge`, `.gitignore`.
- Three Git "areas": working directory → staging → repository.

## Architecture

```
 working tree  --git add-->  staging  --git commit-->  local repo  --git push-->  remote
   (files)                   (index)                  (.git/ dir)             (GitHub)
```

## Expected Output

After the conflict resolution, `git log --oneline --graph --all` should look
like:
```
*   c0ffee0 (HEAD -> main) Merge branch 'feature/b'
|\
| * d00d111 (feature/b) rename audience to cloud engineers
* | b00fa11 (feature/a) rename audience to devops engineers
|/
* a11ce00 add gitignore
* 1234abc initial commit
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Author identity unknown` | Skipped `git config user.email` | Run config commands |
| Conflict markers `<<<<<<<` left in file after commit | Forgot to edit out markers | `git checkout -p` or rewrite, recommit |
| `fatal: not a git repository` | Wrong cwd | `cd` to repo root or `git init` |
| Pushed wrong file | Forgot `.gitignore` | `git rm --cached <file>`, add to `.gitignore`, recommit |

## Best Practices

- **Small, frequent commits** with imperative subject lines: `add health route`.
- **Branch per change**, even when working alone — reviewable units.
- **Never commit secrets** — use `.gitignore` and pre-commit hooks.
- Use `git pull --rebase` to keep linear history (team agreement).

## Production Considerations

- Adopt a branching model (trunk-based, GitFlow, GitHub flow). For most teams,
  trunk-based with short-lived feature branches is simplest.
- Enforce signed commits and protected branches in real repos.
- Pre-commit hooks (`pre-commit` framework) for lint/format/secret-scan.

## Optional Advanced Enhancements

- Show `git bisect` to find the commit that broke a test.
- Show `git reflog` and recover a "lost" commit.
- Introduce `git rebase -i` for cleaning up local history before pushing.


## Real-World Relevance

Git underlies virtually all modern software collaboration. Even one-developer
projects benefit from history, blame, bisect, and reproducible builds anchored
to commit SHAs.
