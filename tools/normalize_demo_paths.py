#!/usr/bin/env python3
"""
Normalize demo folder paths inside demos/NN-*.md to match real folder stems.

Builds a mapping NN -> canonical-stem from existing markdown filenames
(e.g. "01" -> "01-devops-fundamentals"), then in EVERY markdown file rewrites
any  `demos/NN-<old-name>/...`  to  `demos/<canonical-stem>/...`.
Also fixes bare `cd demos/NN-<x>` and similar.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

DEMOS = Path(__file__).resolve().parents[1] / "demos"


def main() -> int:
    canon: dict[str, str] = {}
    for p in DEMOS.glob("[0-9][0-9]-*.md"):
        if p.stem == "00-OVERVIEW":
            continue
        nn = p.stem[:2]
        canon[nn] = p.stem
    print(f"Canonical mapping: {len(canon)} demos")

    pat = re.compile(r"\bdemos/(\d{2})-[A-Za-z0-9_-]+(?=[/\s`)\]]|$)")

    changes_total = 0
    files_changed = 0
    for p in sorted(DEMOS.glob("[0-9][0-9]-*.md")):
        text = p.read_text()

        def repl(m: re.Match) -> str:
            nn = m.group(1)
            target = canon.get(nn)
            if not target:
                return m.group(0)
            return f"demos/{target}"

        new_text, n = pat.subn(repl, text)
        if n:
            p.write_text(new_text)
            files_changed += 1
            changes_total += n
            print(f"  {p.name}: {n} replacement(s)")
    print(f"Done. {changes_total} replacements across {files_changed} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
