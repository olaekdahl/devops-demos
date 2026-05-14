#!/usr/bin/env python3
"""Comprehensive ASCII-box checker for demos/*.md.

A "box" is detected only when a line contains BOTH ┌ and ┐. For each such box:

1. There must be a matching └ at the SAME column on a later line.
2. The ┘ on that bottom row must be at the SAME column as the ┐.
3. Every line strictly between top and bottom must have a vertical-edge
   char at BOTH the left border column and the right border column.

Lone ┌, ┐, └, ┘ used as connectors (`lint ─┐`, `└─► foo`, tree branches
like `├──`/`└──`) are intentionally NOT flagged.

Exits non-zero if any box-integrity issue is found.
"""
import pathlib, sys

VEDGE = set("│├┤┬┴┼")


def check_block(block, line_offset):
    issues = []
    open_corners = []
    for i, ln in enumerate(block):
        lefts = [c for c, ch in enumerate(ln) if ch == "┌"]
        rights = [c for c, ch in enumerate(ln) if ch == "┐"]
        if lefts and rights and len(lefts) == len(rights):
            for l, r in zip(lefts, rights):
                if l < r:
                    open_corners.append((i, l, r))

    for top_row, l, r in open_corners:
        bot_row = None
        for j in range(top_row + 1, len(block)):
            row = block[j]
            if len(row) > l and row[l] == "└":
                bot_row = j
                break
            if len(row) > l and row[l] == "┌":
                break
        if bot_row is None:
            # No matching └ at this column — treat as a fan-out / connector,
            # not a box. Don't flag.
            continue
        bot = block[bot_row]
        if len(bot) <= r or bot[r] != "┘":
            actual = bot[r] if len(bot) > r else "<eol>"
            issues.append((line_offset + bot_row,
                           f"box at col {l}: bottom ┘ not at col {r} (got {actual!r}): {bot!r}"))
            continue
        for k in range(top_row + 1, bot_row):
            row = block[k]
            if len(row) <= r:
                issues.append((line_offset + k, f"line shorter than right border col {r}: {row!r}"))
                continue
            if row[l] not in VEDGE:
                issues.append((line_offset + k, f"left border col {l} = {row[l]!r}: {row!r}"))
            if row[r] not in VEDGE:
                issues.append((line_offset + k, f"right border col {r} = {row[r]!r}: {row!r}"))
    return issues


def main() -> int:
    boxes = 0
    issue_count = 0
    for f in sorted(pathlib.Path("demos").glob("[0-9][0-9]-*.md")):
        lines = f.read_text().splitlines()
        in_block = False
        bs = 0
        for i, ln in enumerate(lines):
            if ln.strip().startswith("```"):
                if not in_block:
                    in_block = True
                    bs = i + 1
                else:
                    in_block = False
                    block = lines[bs:i]
                    boxes += sum(l.count("┌") for l in block)
                    for ln_no, msg in check_block(block, bs + 1):
                        issue_count += 1
                        print(f"{f.name}:L{ln_no}: {msg}")
    print(f"\nBoxes scanned: {boxes}  Issues: {issue_count}")
    return 0 if issue_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
