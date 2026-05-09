BUG 1 -> use @v5 (pinned to a real major)
BUG 2 -> use heredoc 'EOF' (single quotes) to disable expansion if not desired,
         or just trust the shell to expand $USER at runtime — the bug here
         was assuming $USER inside heredoc would be the GitHub user.
BUG 3 -> add tests/ directory and tests, or remove pytest step.
         Use `set -e` (Actions does this by default for `run:` since 2024)
         and `if: ${{ !cancelled() }}` to ensure subsequent steps still run when needed.
BUG 4 -> never `set -x` with secrets; even masking can fail when split or transformed.
BUG 5 -> echo "version=1.2.3" >> "$GITHUB_OUTPUT"
