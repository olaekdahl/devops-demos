# Demo 05 — GitHub Issues

## Learning Objectives
- Use Issues to track bugs, features, tasks.
- Link commits and PRs to Issues so they auto-close.
- Use labels, assignees, and milestones.

## Concepts Covered
- Issue lifecycle: open → in progress → closed
- Closing keywords: `Fixes #N`, `Closes #N`, `Resolves #N`
- Lightweight project management inside the source repo
- Issue templates (preview)

## Quick Start
Almost entirely a **GitHub UI** demo. Steps:

1. In the repo on GitHub: **Issues → New issue** → pick the *Bug report* template (file in `.github/ISSUE_TEMPLATE/bug_report.yml`).
2. File the issue, add labels (`bug`, `priority/high`).
3. Create a fix branch and PR; reference the issue with `Fixes #N` in the PR body.
4. Merging the PR auto-closes the issue.

```bash
cd demos/05-github-issues
git add .github/ISSUE_TEMPLATE/ && git commit -m "chore: issue templates" && git push
```

## Real-World Relevance
Issues + PRs + Actions form the "GitHub-native" project workflow used by many
small/medium teams instead of separate Jira instances. Larger teams sync
GitHub Issues to Jira/Linear via webhooks.

## Demo Architecture
```
  GitHub UI                          Local
  ─────────                          ─────
  New Issue #7  ─── triggers issue.yaml workflow (later, Demo 7)
       ▲
       │ "Fixes #7"
       │
  PR / commit ◄── git push from VS Code
```

## Instructor Notes
- Show that the closing keyword ONLY works when the commit/PR lands on the
  default branch.
- The workflow that runs on issue creation is shown in **Demo 07** — preview
  it here so students see end-to-end.

## Prerequisites
- Demo 03 + 04 complete.

## Folder Structure
Same repo as Demo 03/04.

## Complete Code

No file changes needed beyond a `README.md` edit + a commit message.

## Step-by-Step Walkthrough

### 1. Create an Issue (UI)
- Repo → **Issues** → **New issue**
- Title: `Add usage instructions to README`
- Body:
  ```
  Add detailed instructions on how to run the application locally.
  ```
- Click **Submit new issue**. Note the number, e.g. `#7`.

### 2. Resolve it
```bash
cd demos/03-github-fundamentals
git switch -c docs/usage-instructions

cat >> README.md <<'EOF'

## Running the Application
```bash
git clone https://github.com/<account>/devops-<initials>.git
cd devops-<initials>
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000
```
EOF

git add README.md
git commit -m "Fixes #7: add usage instructions to README"
git push -u origin docs/usage-instructions
```

Open a PR (Demo 04 flow) and merge to `main`. Watch Issue **#7** auto-close
the moment the commit lands on `main`.

### 3. Labels & milestones (UI)
- Add labels `documentation`, `good first issue` on the closed issue.
- Create a milestone `Day 1 cleanup`, attach the issue.

## Expected Output
- Issue header changes from green **Open** to purple **Closed** with text:
  `learning-labs closed this in #8 a few seconds ago`.
- Repo's Issues tab now shows `0 Open / 1 Closed`.

## Common Failure Scenarios
| Symptom | Cause | Fix |
|---|---|---|
| Issue didn't close after merge | Closing keyword not in commit on default branch | Push another commit to `main`: `git commit --allow-empty -m "Closes #7"` |
| Wrong issue closed | Number typo in commit | Reopen the issue manually |
| Closing keyword in PR body but PR not merged | Keyword needs the *merged* commit/PR | Merge the PR |

## DevOps Best Practices
- Reference an issue from every commit/PR — gives traceability later.
- Use **issue templates** (`.github/ISSUE_TEMPLATE/*.yml`) to capture reproduction steps.
- Triage labels: `bug`, `enhancement`, `chore`, `priority/p1`.
- Keep the **active** issue list short — close ruthlessly.

## Production Considerations
- For compliance, link Issues → PRs → deployment artifacts in audit reports.
- Sync GitHub Issues ↔ Jira via official integration if your PM lives there.
- Use **GitHub Projects (v2)** for kanban/roadmap views without leaving GitHub.

## Optional Advanced Enhancements
- Add `.github/ISSUE_TEMPLATE/bug_report.yml` with a structured form.
- Wire `actions/github-script` to auto-label new issues by keyword.
- Have a workflow comment on stale issues after 30 days (`actions/stale`).
