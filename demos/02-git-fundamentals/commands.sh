#!/usr/bin/env bash
# Extracted commands from 02-git-fundamentals.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

cd .

# 1. Identity (once per machine)
git config --global user.name  "Lab Admin"
git config --global user.email "labadmin@example.com"

# 2. Initialize
# git init  # parent-repo op — review & run manually
git branch -m main          # rename default branch to main

# 3. First commit
echo "# Hello Git" > README.md
git status                  # README.md is "untracked"
# git add README.md  # parent-repo op — review & run manually
git status                  # now "staged"
# git commit -m "initial commit"  # parent-repo op — review & run manually
git log --oneline

# 4. Ignoring files
echo "venv/"        >> .gitignore
echo "__pycache__/" >> .gitignore
# git add .gitignore && git commit -m "add gitignore"  # parent-repo op — review & run manually

# 5. Branching
git switch -c feature/greeting
echo "Hello, students!" >> README.md
# git commit -am "add greeting"  # parent-repo op — review & run manually
git log --oneline --graph --all

# 6. Merge fast-forward
git switch main
git merge feature/greeting
git branch -d feature/greeting

# 7. Force a merge conflict (great teaching moment)
git switch -c feature/a
sed -i 's/students/devops engineers/' README.md
# git commit -am "rename audience to devops engineers"  # parent-repo op — review & run manually

git switch main
git switch -c feature/b
sed -i 's/students/cloud engineers/' README.md
# git commit -am "rename audience to cloud engineers"  # parent-repo op — review & run manually

git switch main
git merge feature/a            # ok
git merge feature/b            # CONFLICT
# Resolve manually, then:
# git add README.md  # parent-repo op — review & run manually
# git commit                      # editor opens with merge message  # parent-repo op — review & run manually