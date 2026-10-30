#!/usr/bin/env python3
"""
B3 reconciliation probe (corrected).

The first survey counted "bare" init/greeting branches from data/world/*.comments.txt,
but the sidecar is STALE: the converter emits greeting/init data via extract_greetings /
build_enter_init even when the sidecar still flags the branch "bare". Example: fengqi.c
is flagged bare in foshan.comments.txt yet foshan.ucl already has its greetings.

This script reconciles sidecar vs the ACTUAL UCL:
  For each NPC/room in a zone's comments.txt that has a bare `greeting` / `init` branch,
  locate its UCL block (characters "<id>" { ... } / room "<id>" { ... }) and check whether
  the data is actually present.

Output per zone:
  g_side   : bare greeting branches in sidecar
  g_done   : of those, already present in UCL (false positive -> not backlog)
  g_missing: bare in sidecar AND absent in UCL (true B3 backlog)
  i_side / i_done / i_missing : same for init
"""
import glob
import os
import re

BASE = os.path.join(os.path.dirname(__file__), "..")
DATA_WORLD = os.path.join(BASE, "data", "world")

BRANCH_RE = re.compile(r"^# ==== CONDITIONAL BRANCHES \((init|greeting|create)\) ====$")
BODY_RE = re.compile(r"^\s*#.*→\s*(.*)$")
GEN_RE = re.compile(r"^# Generated from .*?([^/\\]+)\.c by LPCConverter")
# UCL block opener for a named character/room/npc (no ^ anchor: search anywhere,
# advance idx past each non-matching block without requiring a line start)
BLOCK_RE = re.compile(r'\b(characters|room|items|npc)\s+"([^"]+)"\s*\{')


def find_ucl_block(text, name):
    """Return the substring of `text` for block `name`, or None. Brace-balanced.
    Tries hyphen<->underscore variants: comments.txt keeps the .c filename (hyphens),
    but UCL ids are normalized to underscores (e.g. ren-yingying.c -> ren_yingying)."""
    for cand in {name, name.replace("-", "_"), name.replace("_", "-")}:
        blk = _find_block_once(text, cand)
        if blk is not None:
            return blk
    return None


def _find_block_once(text, name):
    idx = 0
    n = len(text)
    while True:
        m = BLOCK_RE.search(text, idx)
        if not m:
            return None
        if m.group(2) == name:
            start = m.end() - 1  # at the '{'
            depth = 0
            i = start
            while i < n:
                c = text[i]
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        return text[start + 1 : i]
                i += 1
            return text[start + 1 :]
        idx = m.end()


def has_greetings(block):
    # greetings = [ ... non-empty ... ]
    m = re.search(r"greetings\s*=\s*\[", block)
    if not m:
        return False
    # crude: ensure there is a { line = ... } after it before the closing ]
    after = block[m.end():]
    return "line =" in after


def has_init(block):
    m = re.search(r"\binit\s*=\s*\{", block)
    if not m:
        return False
    after = block[m.end():]
    # present if any of the three keys appear before the block's closing
    return ("greet_delay" in after) or ("add_actions" in after) or ("heartbeat" in after)


def survey_comments(path):
    """Return dict: name -> {'greeting': bool_bare, 'init': bool_bare}."""
    res = {}
    current = None
    name = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            gm = GEN_RE.match(line.strip())
            if gm:
                name = gm.group(1)
                current = None
                continue
            bm = BRANCH_RE.match(line.rstrip("\n"))
            if bm:
                current = bm.group(1)
                continue
            if current is None or name is None:
                continue
            if line.startswith("# ====") and "CONDITIONAL BRANCHES" not in line:
                current = None
                continue
            bodym = BODY_RE.match(line.rstrip("\n"))
            if bodym and current in ("greeting", "init"):
                if bodym.group(1).strip() == "":
                    res.setdefault(name, {})
                    res[name][current] = True
    return res


def main():
    comments_files = sorted(glob.glob(os.path.join(DATA_WORLD, "*.comments.txt")))
    grand = {"greeting": [0, 0, 0], "init": [0, 0, 0]}
    missing_list = []
    for cf in comments_files:
        zone = os.path.basename(cf).replace(".comments.txt", "").replace(".comments", "")
        ucl_path = os.path.join(DATA_WORLD, zone + ".ucl")
        if not os.path.exists(ucl_path):
            continue
        with open(ucl_path, encoding="utf-8", errors="replace") as fh:
            ucl = fh.read()
        bare = survey_comments(cf)
        if not bare:
            continue
        g_side = g_done = g_missing = 0
        i_side = i_done = i_missing = 0
        for name, flags in bare.items():
            block = find_ucl_block(ucl, name)
            if "greeting" in flags:
                g_side += 1
                if block and has_greetings(block):
                    g_done += 1
                else:
                    g_missing += 1
                    missing_list.append((zone, name, "greeting"))
            if "init" in flags:
                i_side += 1
                if block and has_init(block):
                    i_done += 1
                else:
                    i_missing += 1
                    missing_list.append((zone, name, "init"))
        if g_side or i_side:
            print(f"{zone:<14} greeting side={g_side:>3} done={g_done:>3} missing={g_missing:>3}"
                  f" | init side={i_side:>3} done={i_done:>3} missing={i_missing:>3}")
            grand["greeting"][0] += g_side
            grand["greeting"][1] += g_done
            grand["greeting"][2] += g_missing
            grand["init"][0] += i_side
            grand["init"][1] += i_done
            grand["init"][2] += i_missing
    print("-" * 78)
    print(f"{'TOTAL':<14} greeting side={grand['greeting'][0]:>3} done={grand['greeting'][1]:>3} "
          f"missing={grand['greeting'][2]:>3}"
          f" | init side={grand['init'][0]:>3} done={grand['init'][1]:>3} missing={grand['init'][2]:>3}")
    print()
    print(f"B3 TRUE backlog (sidecar bare AND absent in UCL) = "
          f"{grand['greeting'][2] + grand['init'][2]} "
          f"(greeting {grand['greeting'][2]} + init {grand['init'][2]})")
    print()
    print("Missing (zone / id / type):")
    for z, n, t in missing_list:
        print(f"  {z:<12} {n:<22} {t}")


if __name__ == "__main__":
    main()
