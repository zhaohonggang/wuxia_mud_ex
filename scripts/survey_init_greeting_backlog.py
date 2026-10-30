#!/usr/bin/env python3
"""
Survey the P4 `init` / `greeting` (and `create`, for reference) conditional-branch
backlog across data/world/*.comments.txt.

The LPC->UCL converter left sidecar comments of the form:
    # ==== CONDITIONAL BRANCHES (init) ====
      # if ( interactive(ob = this_player()) && !is_fighting() )  ->  <BODY>

When <BODY> after the arrow is empty/whitespace, the converter dropped the
then-branch and the UCL has no action/台词池 — that is a "bare" branch that
still needs source-tracing backfill (B3 / data-world-comments-progress §8 P4).

This script counts, per zone (.comments.txt stem) and per branch type:
  - sections : how many NPC/room branch sections of this type exist
  - bare     : how many have an empty body (still need backfill)
  - non_bare : how many already have a reconstructed body

Output: a per-zone table + grand totals, so B3 can be sliced smallest-zone-first.
"""
import glob
import os
import re
import sys

DATA_WORLD = os.path.join(os.path.dirname(__file__), "..", "data", "world")

BRANCH_RE = re.compile(r"^# ==== CONDITIONAL BRANCHES \((init|greeting|create)\) ====$")
# A body line: "  # <lpc>  →  <body>" — body is whatever follows the Unicode arrow '→'
BODY_RE = re.compile(r"^\s*#.*→\s*(.*)$")


def survey_file(path):
    counts = {"init": [0, 0], "greeting": [0, 0], "create": [0, 0]}
    current = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = BRANCH_RE.match(line.rstrip("\n"))
            if m:
                current = m.group(1)
                counts[current][0] += 1  # section count
                continue
            # Only inspect body lines while inside a tracked branch section.
            if current is None:
                continue
            # A new section marker of any kind ends the current branch context.
            if line.startswith("# ===="):
                # Could be another CONDITIONAL BRANCHES or UNHANDLED — reset.
                if "CONDITIONAL BRANCHES" in line:
                    # handled on next loop iteration; keep current until re-matched
                    pass
                else:
                    current = None
                continue
            bm = BODY_RE.match(line.rstrip("\n"))
            if bm:
                body = bm.group(1).strip()
                if body == "":
                    counts[current][1] += 1  # bare
    return counts


def main():
    files = sorted(glob.glob(os.path.join(DATA_WORLD, "*.comments.txt")))
    grand = {"init": [0, 0], "greeting": [0, 0], "create": [0, 0]}
    rows = []
    for f in files:
        stem = os.path.splitext(os.path.basename(f))[0].replace(".comments", "")
        c = survey_file(f)
        total_sec = c["init"][0] + c["greeting"][0] + c["create"][0]
        if total_sec == 0:
            continue
        for k in ("init", "greeting", "create"):
            grand[k][0] += c[k][0]
            grand[k][1] += c[k][1]
        rows.append((stem, c["init"], c["greeting"], c["create"]))

    # Sort by (init_bare + greeting_bare) ascending — smallest backlog first.
    def sortkey(r):
        return r[1][1] + r[2][1]

    rows.sort(key=sortkey)

    print(f"{'zone':<16}{'init(sec/bare)':>16}{'greeting(sec/bare)':>22}{'create(sec/bare)':>22}")
    print("-" * 76)
    for stem, ci, cg, cc in rows:
        print(f"{stem:<16}{ci[0]:>8}/{ci[1]:<6}{cg[0]:>14}/{cg[1]:<6}{cc[0]:>16}/{cc[1]:<6}")
    print("-" * 76)
    print(f"{'TOTAL':<16}{grand['init'][0]:>8}/{grand['init'][1]:<6}"
          f"{grand['greeting'][0]:>14}/{grand['greeting'][1]:<6}"
          f"{grand['create'][0]:>16}/{grand['create'][1]:<6}")
    print()
    print(f"B3 open backlog (init_bare + greeting_bare) = "
          f"{grand['init'][1] + grand['greeting'][1]}")


if __name__ == "__main__":
    main()
