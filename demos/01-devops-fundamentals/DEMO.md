# Demo 01 — DevOps Fundamentals

## How to Run

All files needed by this demo are already in this folder. Run from inside it:

```bash
chmod +x loop.sh
./loop.sh
```

## Prerequisites

- Lab VM with `bash`, `python3`, `git`. Nothing else.

## Learning Objectives

- Define DevOps in plain language.
- Contrast traditional siloed IT with a DevOps culture.
- Identify the phases of the DevOps lifecycle and the tool category for each.
- Walk students through one tiny end-to-end "DevOps loop" to make it concrete.

## Concepts Covered

- Culture vs tooling
- Dev vs Ops responsibility silos
- The DevOps "infinity" lifecycle: Plan → Code → Build → Test → Release → Deploy → Operate → Monitor → (back to Plan)
- Automation, repeatability, fast feedback, shared ownership

## Architecture

A whiteboard / slide-driven demo plus a tiny end-to-end loop on the lab VM:

```
   ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
   │  Code   ├───►│ git push ├───►│ CI build ├───►│  Deploy  │
   └─────────┘    └──────────┘    └──────────┘    └────┬─────┘
                                                       │
                                                       ▼
   ┌──────────────── Monitor & Feedback ──────────────────┐
   │  HTTP probe / log line tells us it's live ───────────┼──► back to Code
   └──────────────────────────────────────────────────────┘
```

## Walkthrough

Walk students through each `PHASE`:
1. **Plan**: someone (PM, eng) decided what to build.
2. **Code**: developer writes `app.py`.
3. **Build**: compile/package — here, byte-compile.
4. **Test**: validate behaviour before shipping.
5. **Release**: tag an immutable version (`1.0.<timestamp>`).
6. **Deploy**: run the artifact in an environment.
7. **Operate**: keep it running.
8. **Monitor**: collect signals (logs/metrics).
9. **Feedback**: take what monitoring tells us back to **Plan**.

## Expected Output

```
=== PLAN ===
Goal: ship a tiny service that prints a heartbeat.
=== CODE ===
import time, os
...
=== BUILD ===
syntax OK
=== TEST ===
smoke test passed
=== RELEASE ===
tagged release: 1.0.1739999999
=== DEPLOY ===
[heartbeat] version=1.0.1739999999 ts=1739999999
[heartbeat] version=1.0.1739999999 ts=1740000001
=== OPERATE ===
PID=12345 running
=== MONITOR ===
--- last 3 log lines ---
=== FEEDBACK ===
If heartbeat missing -> open ticket, plan fix, loop.
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `python3: command not found` | Wrong VM image | `apt-get install python3` |
| Heartbeat never prints | `flush=True` removed → buffered stdout | Keep `flush=True` |
| Script keeps running | `kill` skipped on `set -e` exit | Add `trap "kill $APP_PID" EXIT` |

## Best Practices

- Every phase should be **automated and repeatable**.
- Prefer **immutable releases** (a versioned artifact, not "edited the server").
- **Short feedback loops** — minutes, not weeks.
- **Shared ownership** — devs see the dashboards, ops reads the code.

## Production Considerations

- Replace `loop.sh` with: GitHub → GitHub Actions → Docker registry → K8s →
  Prometheus + Grafana + PagerDuty.
- Add SLOs, error budgets, blue/green or canary deploys.
- Capture lead time, deploy frequency, MTTR, change-fail rate (DORA metrics).

## Optional Advanced Enhancements

- Have students whiteboard their current employer's "loop" and identify the
  longest-feedback-loop step. That step is the candidate for automation.
- Introduce DORA metrics and ask students to estimate them for the demo loop.

## Instructor Notes

- Resist the urge to dive into tools. Spend 10 minutes on **culture**.
- Common confusion: students think DevOps == Jenkins or DevOps == "an engineer
  who does both." Correct: DevOps is the *practice* of removing silos; the
  engineer is one outcome.
- Use the metaphor: dev = "I built a car." ops = "I drive it." DevOps = "we own
  the car together, including the tow truck."
- Show the loop *before* showing any tool. Then map tools onto loop phases.

## Real-World Relevance

Every modern engineering org — banks, retailers, SaaS companies — uses DevOps
practices to ship safely and quickly. Companies like Netflix, Amazon, Etsy
deploy thousands of times per day. Without DevOps you get the classic
"throw it over the wall" outage cycle.
