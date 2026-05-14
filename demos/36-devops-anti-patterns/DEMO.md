# Demo 36 — DevOps Anti-Patterns

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
cat anti-patterns.md
```

## Prerequisites

- Demos 1–32 complete.

## Learning Objectives

- Recognize and articulate the most common DevOps anti-patterns.
- For each, describe the *fix* and the principle it violates.

## Concepts Covered

- "Snowflake" servers
- Manual prod deploys
- Long-lived branches
- Secrets in code/repos
- Single environment ("we test in prod")
- Skipping tests on red builds
- One-pipeline-per-team monoliths
- "It works on my machine"
- Zero rollback plan
- Tribal knowledge / no runbooks

## Architecture

A facilitated discussion, plus 1 quick *live demo of a bad pattern + the fix*
for each.

## Walkthrough

For each anti-pattern, do:
1. Show the **bad** version (10 sec).
2. Discuss: "What goes wrong?"
3. Show the **good** version.
4. Name the principle.

## Expected Output

A quick consensus on the top 3 anti-patterns most present in their orgs.

## Production Considerations

- Track **DORA** metrics; share them transparently.
- Run **gameday** drills (chaos engineering) to validate runbooks.
- Use **post-incident reviews** without blame.

## Optional Advanced Enhancements

- Bring an anti-pattern from your job and debug it as a group.
- Read "The Phoenix Project" / "Accelerate" excerpts.
- Workshop: rewrite a "snowflake setup" doc into Terraform.


## Real-World Relevance

Most outages and security incidents trace back to one of these anti-patterns.
Pattern recognition is half the fight.
