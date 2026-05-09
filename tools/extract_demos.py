#!/usr/bin/env python3
"""
Extract per-demo runnable code from demos/NN-name.md files into demos/NN-name/.

For each `demos/NN-name.md`:
  - Create folder demos/NN-name/
  - DEMO.md          = the original markdown (instructor guide)
  - README.md        = short "how to run this demo" blurb (auto-generated unless
                       the markdown extracts an explicit README.md)
  - commands.sh      = all `bash`/`sh` code blocks concatenated, executable
  - <extracted>      = every file referenced as `path/to/file` followed by a fenced
                       code block. Paths starting with "demos/<x>/" are stripped.
  - sample-app deps  = if the demo references the sample app, missing files from
                       demos/sample-app/ are copied in (app.py, requirements.txt,
                       tests/, plus Dockerfile for docker/k8s demos)
"""
from __future__ import annotations
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMOS = ROOT / "demos"
SAMPLE = DEMOS / "sample-app"

FILE_HEADER = re.compile(
    r"^`("
    r"[A-Za-z0-9_./\-]+\.[A-Za-z0-9_+]+"
    r"|Dockerfile(?:\.[A-Za-z0-9_-]+)?|Makefile|CODEOWNERS|LICENSE"
    r"|\.env(?:\.[A-Za-z0-9_-]+)?|\.dockerignore|\.gitignore"
    r")`(?:\s+(?:[—\-:(].*|\([^)]*\).*))?\s*$"   # allow trailing " — desc" / " (desc)"
)
FENCE = re.compile(r"^```([A-Za-z0-9_+-]*)\s*$")

SAMPLE_FILES = ["app.py", "requirements.txt", "requirements-dev.txt", "tests/test_app.py"]
DOCKER_LIKE = ("docker", "kubernetes", "kind", "ingress", "gateway", "scal",
               "configmap", "secret", "persistent", "registr", "jfrog", "eks",
               "cicd", "end-to-end", "production", "observability", "logging")


def parse_md(md_path: Path):
    full = md_path.read_text()
    # Restrict file extraction to the "## Complete Code" section ONLY.
    # Stops backticked filenames inside Expected Output / Walkthrough from being treated as files.
    m = re.search(r"^## Complete Code\s*$", full, re.MULTILINE)
    if not m:
        return
    start = m.end()
    next_section = re.search(r"^## (?!Complete Code)", full[start:], re.MULTILINE)
    end = start + next_section.start() if next_section else len(full)
    section = full[start:end]
    lines = section.splitlines()
    i, n = 0, len(lines)
    while i < n:
        m = FILE_HEADER.match(lines[i].strip())
        if not m:
            i += 1
            continue
        path = m.group(1)
        j = i + 1
        while j < n and lines[j].strip() == "":
            j += 1
        if j >= n or not FENCE.match(lines[j]):
            i += 1
            continue
        k = j + 1
        body = []
        while k < n and lines[k].strip() != "```":
            body.append(lines[k])
            k += 1
        if k >= n:
            i = j + 1
            continue
        content = "\n".join(body) + "\n"
        norm = re.sub(r"^demos/[^/]+/", "", path).lstrip("/").replace("..", "")
        yield norm, content
        i = k + 1


SHELL_RE = re.compile(
    r"\b(kubectl|docker|git|curl|aws|eksctl|helm|kind|make|python3?|pip|pytest|"
    r"uvicorn|terraform|ssh|scp|chmod|chown|export|cd|mkdir|rm|cp|mv|ls|cat|echo|"
    r"sudo|az|gcloud|jq|yq|gh|openssl|tar|wget|nc|ping|systemctl|apt|brew|"
    r"sed|awk|grep|find|xargs|env|source|true|false|base64|kustomize|kubeseal|"
    r"htpasswd|trivy|cosign|act|actionlint|hadolint|kubeval|conftest|opa|tee)\b"
)


def rewrite_paths(text: str) -> str:
    """Rewrite stale `demos/<x>/...` paths so commands.sh runs from inside the
    demo folder. Each demo's commands.sh has cwd = demos/<stem>/, so any
    `demos/<anything>/` prefix should be stripped.
    """
    # Special: drop entire lines that are pure no-ops after stripping
    out_lines = []
    for line in text.splitlines():
        original = line

        # `cd demos/<x>/<rest>` -> `cd <rest>`; `cd demos/<x>` -> drop
        line = re.sub(
            r"\bcd\s+demos/[A-Za-z0-9_.-]+/([^\s;&|]+)",
            r"cd \1",
            line,
        )
        line = re.sub(
            r"\bcd\s+demos/[A-Za-z0-9_.-]+(?=\s|$|;|&|\|)",
            "cd .",
            line,
        )

        # `mkdir -p demos/<x>/<rest>` -> `mkdir -p <rest>`; `mkdir -p demos/<x>` -> no-op
        line = re.sub(
            r"\bmkdir(\s+-p)?\s+demos/[A-Za-z0-9_.-]+/",
            r"mkdir\1 ",
            line,
        )
        line = re.sub(
            r"\bmkdir(\s+-p)?\s+demos/[A-Za-z0-9_.-]+(?=\s|$|;|&|\|)",
            r"mkdir\1 .",
            line,
        )

        # Strip remaining `demos/<x>/` path prefixes (cp/git add/etc.)
        # Keep `demos/sample-app/...` AS empty too (sample-app is pre-copied in)
        line = re.sub(r"\bdemos/[A-Za-z0-9_.-]+/", "", line)

        # Comment out git operations against the parent repo (we're inside a demo subdir)
        if re.match(r"\s*git\s+(add|commit|push|init)\b", line):
            line = "# " + line.lstrip() + "  # parent-repo op — review & run manually"

        # Drop pure no-ops left over from path stripping
        if re.match(r"\s*(mkdir(\s+-p)?\s+\.|cd\s+\.)\s*(&&|;)?\s*$", line):
            continue
        # Drop `cd .` chained at start: "cd . && something" -> "something"
        line = re.sub(r"^(\s*)cd\s+\.\s*&&\s*", r"\1", line)
        # Drop `mkdir -p .` chained at start
        line = re.sub(r"^(\s*)mkdir(\s+-p)?\s+\.\s*&&\s*", r"\1", line)

        # Comment out cp lines that became no-ops or self-copies
        m = re.match(r"\s*cp(?:\s+-r)?\s+(\S+)\s*$", line)  # cp with one arg = broken
        if m:
            line = "# " + original.lstrip() + "  # source path stripped — sample-app is pre-copied"
        m = re.match(r"\s*cp(?:\s+-r)?\s+(\S+)\s+(\S+)\s*$", line)
        if m and m.group(1) == m.group(2):
            line = "# " + original.lstrip() + "  # no-op after path rewrite"

        # Comment lines that contain <placeholder> tokens — bash interprets `<x`
        # as a redirect and chokes. These are documentation, not runnable.
        if not line.lstrip().startswith("#"):
            if re.search(r"<[A-Za-z][A-Za-z0-9_-]*>", line) and not re.search(r"<<-?\s*['\"]?[A-Z]+", line):
                line = "# " + line.lstrip() + "  # contains <placeholder> — edit before running"

        out_lines.append(line)
    return "\n".join(out_lines)


def extract_bash(md_path: Path) -> str:
    full = md_path.read_text()
    # Strip out the "## Complete Code" section — code blocks there are file contents,
    # not commands to run.
    m = re.search(r"^## Complete Code\s*$", full, re.MULTILINE)
    if m:
        start = m.end()
        next_section = re.search(r"^## (?!Complete Code)", full[start:], re.MULTILINE)
        end = start + next_section.start() if next_section else len(full)
        full = full[:m.start()] + full[end:]
    lines = full.splitlines()
    i, n = 0, len(lines)
    in_block = False
    blocks: list[str] = []
    cur: list[str] = []
    while i < n:
        if not in_block:
            m = FENCE.match(lines[i])
            # Only accept EXPLICIT bash/sh/shell fences. Empty-language fences
            # are usually file contents, ASCII diagrams, or output samples.
            if m and m.group(1) in ("bash", "sh", "shell", "console"):
                in_block = True
                cur = []
            i += 1
            continue
        if lines[i].strip() == "```":
            blocks.append("\n".join(cur))
            in_block = False
            i += 1
            continue
        cur.append(lines[i])
        i += 1

    cleaned: list[str] = []
    for b in blocks:
        kept = []
        for ln in b.splitlines():
            stripped = ln.strip()
            # Drop interactive-output lines like "NAME    READY   STATUS"
            # and lines that look like pasted output (no shell verb, no leading $)
            if stripped.startswith("$ "):
                # treat as a command — strip the prompt
                kept.append(ln.replace("$ ", "", 1))
                continue
            if not stripped or stripped.startswith("#"):
                kept.append(ln)
                continue
            if (SHELL_RE.search(stripped)
                    or stripped.startswith(("PYTHONPATH", "VERSION", "APP_", "AWS_", "ENVIRONMENT"))
                    or re.match(r"^[A-Z_][A-Z0-9_]*=", stripped)):
                kept.append(ln)
                continue
            # Output-looking line — drop it
        text = "\n".join(kept).strip()
        if not text or not any(SHELL_RE.search(l) for l in text.splitlines()):
            continue
        # Auto-close any unterminated heredocs in this block
        heredocs = re.findall(r"<<-?\s*['\"]?([A-Z][A-Z0-9_]*)['\"]?", text)
        for delim in heredocs:
            if not re.search(rf"^{delim}\s*$", text, re.MULTILINE):
                text += f"\n{delim}\n"
        # Auto-close unterminated for/while/if/case blocks (count opens vs closes,
        # only count keywords that begin a statement — skip if inside comments)
        def code_lines(body):
            return "\n".join(l for l in body.splitlines() if not l.lstrip().startswith("#"))
        code = code_lines(text)
        opens = len(re.findall(r"(?:^|;|\bthen\b|\bdo\b)\s*(?:for|while|until)\b[^\n]*?;\s*do\b|^\s*do\s*$|;\s*do\s*$", code, re.MULTILINE))
        # simpler: count standalone `do` and `done`
        opens = len(re.findall(r"(?:^|;|&&|\|\|)\s*do\b", code))
        closes = len(re.findall(r"(?:^|;|&&|\|\|)\s*done\b", code))
        text += "\ndone" * max(0, opens - closes)
        ifs = len(re.findall(r"(?:^|;|&&|\|\|)\s*if\b", code))
        fis = len(re.findall(r"(?:^|;|&&|\|\|)\s*fi\b", code))
        text += "\nfi" * max(0, ifs - fis)
        cases = len(re.findall(r"(?:^|;|&&|\|\|)\s*case\b\s+\S+\s+in\b", code))
        esacs = len(re.findall(r"(?:^|;|&&|\|\|)\s*esac\b", code))
        text += "\nesac" * max(0, cases - esacs)
        cleaned.append(text)
    if not cleaned:
        return ""
    return "\n\n# --- next block ---\n\n".join(cleaned).rstrip() + "\n"


def needs_sample_app(md_text: str) -> bool:
    return ("sample-app" in md_text or "from app import" in md_text or
            "uvicorn app:app" in md_text or
            "(re-used)" in md_text or "(reused)" in md_text or
            ("app.py" in md_text and ("FastAPI" in md_text or "fastapi" in md_text or "uvicorn" in md_text)))


def auto_readme(stem: str, has_compose: bool, has_dockerfile: bool, has_yaml: bool,
                has_workflow: bool, has_commands: bool) -> str:
    title = stem.split("-", 1)[1].replace("-", " ").title()
    parts = [
        f"# Demo {stem.split('-')[0]} — {title}",
        "",
        "Runnable artifacts for this demo. Full instructor narrative in [DEMO.md](DEMO.md).",
        "",
        "## How to run",
        "",
    ]
    if has_compose:
        parts += ["```bash",
                  "docker compose up -d --build",
                  "docker compose ps",
                  "docker compose logs -f",
                  "docker compose down -v   # cleanup (also wipes volumes)",
                  "```", ""]
    if has_dockerfile and not has_compose:
        parts += ["```bash",
                  "docker build -t demo-app:local .",
                  "docker run --rm -p 8000:8000 demo-app:local",
                  "```", ""]
    if has_yaml and not has_compose:
        parts += ["```bash",
                  "# Requires a running Kubernetes cluster — see demo 20 for kind setup.",
                  "kubectl apply -f .",
                  "kubectl get all",
                  "kubectl delete -f .   # cleanup",
                  "```", ""]
    if has_workflow:
        parts += ["```bash",
                  "# GitHub Actions — push to a GitHub repo to run.",
                  "# Validate locally:  pipx install actionlint && actionlint .github/workflows/*.yaml",
                  "```", ""]
    if has_commands:
        parts += ["```bash",
                  "# Step-by-step shell commands extracted from the demo.",
                  "# READ FIRST — some commands are interactive or destructive.",
                  "bash commands.sh",
                  "```", ""]
    parts += ["See [DEMO.md](DEMO.md) for the full walkthrough."]
    return "\n".join(parts) + "\n"


def main() -> int:
    md_files = sorted(p for p in DEMOS.glob("[0-9][0-9]-*.md") if p.stem != "00-OVERVIEW")
    summary = []
    for md in md_files:
        stem = md.stem
        outdir = DEMOS / stem
        outdir.mkdir(exist_ok=True)
        (outdir / "DEMO.md").write_text(md.read_text())

        extracted: dict[str, bool] = {}
        for rel, content in parse_md(md):
            target = outdir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
            extracted[rel] = True
            if rel.endswith(".sh"):
                target.chmod(0o755)

        bash = extract_bash(md)
        bash = rewrite_paths(bash)
        has_commands = False
        if bash.strip():
            cmds = outdir / "commands.sh"
            cmds.write_text(
                "#!/usr/bin/env bash\n"
                f"# Extracted commands from {md.name}\n"
                "# REVIEW BEFORE RUNNING — some commands are interactive or destructive.\n"
                "# Run blocks individually rather than the whole script if unsure.\n"
                "set -euo pipefail\n\n" + bash
            )
            cmds.chmod(0o755)
            has_commands = True

        md_text = md.read_text()
        # Only copy sample-app deps if the demo did NOT extract its own app.py
        if needs_sample_app(md_text) and "app.py" not in extracted:
            for sf in SAMPLE_FILES:
                src = SAMPLE / sf
                dst = outdir / sf
                if not dst.exists() and src.exists():
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)
            if any(k in stem for k in DOCKER_LIKE):
                for sf in ["Dockerfile", ".dockerignore"]:
                    src = SAMPLE / sf
                    dst = outdir / sf
                    if not dst.exists() and src.exists():
                        shutil.copy2(src, dst)

        if "README.md" not in extracted:
            files = list(outdir.rglob("*"))
            has_compose = any(f.name in ("compose.yaml", "compose.yml",
                                         "docker-compose.yaml", "docker-compose.yml")
                              for f in files)
            has_dockerfile = any(f.name == "Dockerfile" for f in files)
            has_yaml = any(f.suffix in (".yaml", ".yml")
                           and "workflows" not in str(f)
                           and "compose" not in f.name
                           for f in files)
            has_workflow = (outdir / ".github" / "workflows").exists()
            (outdir / "README.md").write_text(
                auto_readme(stem, has_compose, has_dockerfile, has_yaml,
                            has_workflow, has_commands)
            )

        total = sum(1 for _ in outdir.rglob("*") if _.is_file())
        summary.append(f"{stem}: extracted={len(extracted)} commands.sh={has_commands} total={total}")
    print("\n".join(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
