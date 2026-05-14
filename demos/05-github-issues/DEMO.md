# Demo 05 — GitHub Issues

## How to Run

This demo runs entirely in the **GitHub UI**. There are no files to apply. Steps:

1. Open your `devops-<initials>` repo on GitHub → **Issues → New issue**.
2. Title: `Add usage instructions to README`. File the issue and note its number (e.g. `#7`).
3. From your local shell, fix it:

```bash
git switch -c docs/usage-instructions
cat >> README.md <<'EOF'

## Running the Application
1. Clone the repo.
2. Run `python3 app.py`.
EOF
git add README.md
git commit -m "docs: add usage instructions

Fixes #7"
git push -u origin docs/usage-instructions
```

4. Open the PR on GitHub. Merge it. The issue auto-closes because of the `Fixes #7` keyword.

## Prerequisites

- Demo 03 + 04 complete.

## Learning Objectives

- Use Issues to track bugs, features, tasks.
- Link commits and PRs to Issues so they auto-close.
- Use labels, assignees, and milestones.

## Concepts Covered

- Issue lifecycle: open → in progress → closed
- Closing keywords: `Fixes #N`, `Closes #N`, `Resolves #N`
- Lightweight project management inside the source repo
- Issue templates (preview)

## Architecture

```
  GitHub UI                          Local
  ─────────                          ─────
  New Issue #7  ─── triggers issue.yaml workflow (later, Demo 7)
       ▲
       │ "Fixes #7"
       │
  PR / commit ◄── git push from VS Code
```

## Walkthrough

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

## Expected Output

- Issue header changes from green **Open** to purple **Closed** with text:
  `learning-labs closed this in #8 a few seconds ago`.
- Repo's Issues tab now shows `0 Open / 1 Closed`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Issue didn't close after merge | Closing keyword not in commit on default branch | Push another commit to `main`: `git commit --allow-empty -m "Closes #7"` |
| Wrong issue closed | Number typo in commit | Reopen the issue manually |
| Closing keyword in PR body but PR not merged | Keyword needs the *merged* commit/PR | Merge the PR |

## Best Practices

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


## Real-World Relevance

Issues + PRs + Actions form the "GitHub-native" project workflow used by many
small/medium teams instead of separate Jira instances. Larger teams sync
GitHub Issues to Jira/Linear via webhooks.
