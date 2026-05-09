# Demo 02 — Git Fundamentals

## Learning Objectives
- Initialize a Git repo and configure identity.
- Stage, commit, view history, branch, merge, and resolve a conflict.
- Understand the working tree, index (staging area), and local repo.

## Concepts Covered
- `git init`, `git config`, `git add`, `git commit`, `git status`, `git log`,
  `git diff`, `git branch`, `git switch`/`checkout`, `git merge`, `.gitignore`.
- Three Git "areas": working directory → staging → repository.

## Quick Start
Run the demo end-to-end:

```bash
cd demos/02-git-fundamentals
mkdir -p demos/02-git-fundamentals && cd demos/02-git-fundamentals

# 1. Identity (once per machine)
git config --global user.name  "Lab Admin"
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
echo "Hello, students!" >> README.md
git commit -am "add greeting"
git log --oneline --graph --all

# 6. Merge fast-forward
git switch main
git merge feature/greeting
git branch -d feature/greeting

# 7. Force a merge conflict (great teaching moment)
git switch -c feature/a
sed -i 's/students/devops engineers/' README.md
git commit -am "rename audience to devops engineers"

git switch main
git switch -c feature/b
sed -i 's/students/cloud engineers/' README.md
git commit -am "rename audience to cloud engineers"

git switch main
git merge feature/a            # ok
git merge feature/b            # CONFLICT
# Resolve manually, then:
git add README.md
git commit                      # editor opens with merge message
```

## Real-World Relevance
Git underlies virtually all modern software collaboration. Even one-developer
projects benefit from history, blame, bisect, and reproducible builds anchored
to commit SHAs.

## Demo Architecture
```
 working tree  --git add-->  staging  --git commit-->  local repo  --git push-->  remote
   (files)                   (index)                  (.git/ dir)             (GitHub)
```

## Instructor Notes
- Students often confuse `git add` with "save". Clarify: **save** writes to disk,
  **add** stages, **commit** records.
- Show `.git/` directory contents briefly so students know it's "just files".
- Demonstrate the conflict on purpose — it's the most-feared Git scenario.

## Prerequisites
- Git installed (`git --version` ≥ 2.40).

## Folder Structure
```
demos/02-git-fundamentals/
  README.md   (created during demo)
```

## Complete Code

The demo is the command sequence itself. No source code beyond a tiny README.

## Step-by-Step Walkthrough

```bash
mkdir -p demos/02-git-fundamentals && cd demos/02-git-fundamentals

# 1. Identity (once per machine)
git config --global user.name  "Lab Admin"
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
echo "Hello, students!" >> README.md
git commit -am "add greeting"
git log --oneline --graph --all

# 6. Merge fast-forward
git switch main
git merge feature/greeting
git branch -d feature/greeting

# 7. Force a merge conflict (great teaching moment)
git switch -c feature/a
sed -i 's/students/devops engineers/' README.md
git commit -am "rename audience to devops engineers"

git switch main
git switch -c feature/b
sed -i 's/students/cloud engineers/' README.md
git commit -am "rename audience to cloud engineers"

git switch main
git merge feature/a            # ok
git merge feature/b            # CONFLICT
# Resolve manually, then:
git add README.md
git commit                      # editor opens with merge message
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

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| `Author identity unknown` | Skipped `git config user.email` | Run config commands |
| Conflict markers `<<<<<<<` left in file after commit | Forgot to edit out markers | `git checkout -p` or rewrite, recommit |
| `fatal: not a git repository` | Wrong cwd | `cd` to repo root or `git init` |
| Pushed wrong file | Forgot `.gitignore` | `git rm --cached <file>`, add to `.gitignore`, recommit |

## DevOps Best Practices
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
