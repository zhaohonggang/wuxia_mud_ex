#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit: which LPC `set("key", ...)` keys never made it into data/world/*.ucl.

Companion to scripts/analyze_comments_txt.py.  The .comments.txt sidecars only
record branch *conditions* (83% of them with no body at all), so they understate
the real data loss.  This script goes back to the authoritative LPC corpus and
diffs the key vocabulary.

Usage:  python scripts/audit_ucl_key_loss.py [corpus_root] [world_dir]
"""
import os
import re
import sys
import json
from collections import Counter

CORPUS = sys.argv[1] if len(sys.argv) > 1 else r"C:\files\git\mud\d"
WORLD = sys.argv[2] if len(sys.argv) > 2 else "data/world"

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
import lpc_converter as L  # noqa: E402

# set() keys that the converter renders under a different UCL field name.
ALIAS = {
    "exits": "room_exits",
    "objects": "characters",
    "inquiry": "inquiries",
    "set_name": "aliases",
    "short": "name",
}

SET_RE = re.compile(r'\bset\s*\(\s*"([^"]+)"')


def main():
    zones = sorted(f[:-4] for f in os.listdir(WORLD) if f.endswith(".ucl"))
    src = Counter()
    nfiles = 0
    for z in zones:
        d = os.path.join(CORPUS, z)
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for fn in files:
                if not fn.endswith(".c"):
                    continue
                nfiles += 1
                try:
                    txt = L._to_utf8(open(os.path.join(root, fn), "rb").read())
                except Exception:
                    continue
                for m in SET_RE.finditer(txt):
                    src[m.group(1)] += 1

    blob = "\n".join(
        open(os.path.join(WORLD, f), encoding="utf-8", errors="replace").read()
        for f in os.listdir(WORLD)
        if f.endswith(".ucl")
    )

    def present(k):
        if k in blob:
            return True
        if k in ALIAS and ALIAS[k] in blob:
            return True
        return k.split("/")[-1] in blob

    missing = [(k, c) for k, c in src.most_common() if not present(k)]
    print(f"corpus .c files scanned : {nfiles}")
    print(f"distinct set() keys     : {len(src)}")
    print(f"keys absent from .ucl   : {len(missing)} distinct, "
          f"{sum(c for _, c in missing)} occurrences")
    print()
    for k, c in missing[:80]:
        print(f"  {k:34s}{c}")

    os.makedirs("tmp", exist_ok=True)
    with open(os.path.join("tmp", "ucl_key_loss.json"), "w", encoding="utf-8") as fh:
        json.dump({"distinct_keys": len(src), "absent": dict(missing)},
                  fh, ensure_ascii=False, indent=1)
    print("\nwrote tmp/ucl_key_loss.json")


if __name__ == "__main__":
    main()
