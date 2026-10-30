#!/usr/bin/env python3
"""
Classify the B3 missing greeting/init NPCs by complexity, to decide backfill strategy.

For each missing (zone, id, type) from reconcile_init_greeting_backlog.py:
  - locate the .c source via the comments.txt "Generated from .../<id>.c" line
  - read the greeting()/init() function body
  - flag CONDITIONAL if it branches on player state (if/query gender/class/job,
    command(kick/move), switch, RANK_D, environment, message)
  - else SIMPLE (a flat say()/switch-pool of lines -> static greetings pool)
Also report whether the .c source is reachable (else CANNOT backfill).
"""
import glob
import os
import re

import reconcile_init_greeting_backlog as R

MUD = os.path.join(os.path.dirname(__file__), "..", "..", "mud", "d")
DATA_WORLD = os.path.join(os.path.dirname(__file__), "..", "data", "world")

GEN_RE = re.compile(r"^# Generated from (.+?\.c) by LPCConverter")
# TRUE conditional: branches on player STATE or performs SIDE-EFFECTS beyond saying a line.
TRUE_COND_PAT = re.compile(
    r'query\("(?:gender|class|job|family|age)"|command\("kick|->move\(|'
    r'message\(\s*"vision|->set\(|add_money|command\("go |receive_damage|'
    r'command\("kill|set_temp|set\("', re.IGNORECASE)
# Normal (backfillable) patterns: generic guard + respect title + say/switch pool.
GUARD_PAT = re.compile(r'interactive|is_fighting|RANK_D|query_respect|switch\s*\(', re.IGNORECASE)


def find_c_path(zone, npc_id):
    cf = os.path.join(DATA_WORLD, zone + ".comments.txt")
    if not os.path.exists(cf):
        return None
    with open(cf, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = GEN_RE.match(line.strip())
            if m:
                # candidate name from path
                base = os.path.basename(m.group(1))[:-2]  # strip .c
                if base == npc_id or base == npc_id.replace("_", "-") or base == npc_id.replace("-", "_"):
                    return m.group(1)
    return None


def extract_func(src, func_name):
    """Return the body of `void func_name(...) { ... }` as a string, or None."""
    m = re.search(r"void\s+" + re.escape(func_name) + r"\s*\([^)]*\)\s*\{", src)
    if not m:
        return None
    start = m.end() - 1
    depth = 0
    i = start
    n = len(src)
    while i < n:
        c = src[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return src[start + 1 : i]
        i += 1
    return src[start + 1 :]


def main():
    # reuse reconcile's missing list by running it via import side-effects? Simpler: re-detect.
    missing = []
    # Re-run reconcile's scan logic minimally:
    comments_files = sorted(glob.glob(os.path.join(DATA_WORLD, "*.comments.txt")))
    for cf in comments_files:
        zone = os.path.basename(cf).replace(".comments.txt", "").replace(".comments", "")
        ucl_path = os.path.join(DATA_WORLD, zone + ".ucl")
        if not os.path.exists(ucl_path):
            continue
        ucl = open(ucl_path, encoding="utf-8", errors="replace").read()
        bare = R.survey_comments(cf)
        for name, flags in bare.items():
            block = R.find_ucl_block(ucl, name)
            if "greeting" in flags and not (block and R.has_greetings(block)):
                missing.append((zone, name, "greeting"))
            if "init" in flags and not (block and R.has_init(block)):
                missing.append((zone, name, "init"))

    print(f"{'zone':<10}{'id':<22}{'type':<9}{'c_src':<10}{'complexity'}")
    print("-" * 60)
    simple = cond = noc = 0
    for zone, npc_id, typ in missing:
        cpath = find_c_path(zone, npc_id)
        if not cpath or not os.path.exists(cpath):
            print(f"{zone:<10}{npc_id:<22}{typ:<9}{'NO':<10}UNREACHABLE")
            noc += 1
            continue
        src = open(cpath, encoding="utf-8", errors="replace").read()
        body = extract_func(src, "greeting") if typ == "greeting" else extract_func(src, "init")
        if body is None:
            # maybe the function is named differently; treat whole file for greeting keywords
            body = src
        is_true_cond = bool(TRUE_COND_PAT.search(body or ""))
        has_guard = bool(GUARD_PAT.search(body or ""))
        if is_true_cond:
            tag = "CONDITIONAL*"
        elif has_guard:
            tag = "POOL(guard+respect)"
        else:
            tag = "POOL(plain)"
        if is_true_cond:
            cond += 1
        else:
            simple += 1
        print(f"{zone:<10}{npc_id:<22}{typ:<9}{'yes':<10}{tag}")
    print("-" * 60)
    print(f"TOTAL={len(missing)}  SIMPLE={simple}  CONDITIONAL={cond}  NO_SRC={noc}")


if __name__ == "__main__":
    main()
