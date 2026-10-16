#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Triage the LPC `set()` keys that have no literal trace in data/world/*.ucl.

`audit_ucl_key_loss.py` reports raw absence, which over-counts: some keys are
rendered under a different UCL field, and some are handled in Elixir code rather
than in data.  This script classifies each absent key into:

  A. converted-under-alias  -> present in .ucl under another name  (no work)
  B. engine-implemented     -> appears in lib/**/*.ex or data/*.ucl (no work)
  C. truly-missing          -> nowhere at all  -> the real work list

Usage: python scripts/triage_lost_keys.py
"""
import os
import re
import json
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
CORPUS = r"C:\files\git\mud\d"

# key -> the UCL field the converter emits instead
ALIAS = {
    "exits": "room_exits",
    "objects": "characters",
    "inquiry": "inquiries",
    "set_name": "aliases",
    "short": "name",
    "long": "description",
    "chat_msg": "chats",
    "chat_chance": "chat_chance",
    "weight": "weight",          # set_weight(6000) -> meta.weight
    "food_supply": "food",
    "armor_prop/armor": "armor",
}

SET_RE = re.compile(r'\bset\s*\(\s*"([^"]+)"')


def read(path, enc="utf-8"):
    with open(path, encoding=enc, errors="replace") as fh:
        return fh.read()


def main():
    zones = sorted(f[:-4] for f in os.listdir(WORLD) if f.endswith(".ucl"))
    src = Counter()
    for z in zones:
        d = os.path.join(CORPUS, z)
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for fn in files:
                if fn.endswith(".c"):
                    try:
                        txt = read(os.path.join(root, fn), enc="gbk")
                    except Exception:
                        continue
                    for m in SET_RE.finditer(txt):
                        src[m.group(1)] += 1

    ucl_blob = "\n".join(read(os.path.join(WORLD, f)) for f in os.listdir(WORLD)
                          if f.endswith(".ucl"))
    # Elixir sources: only struct fields (`:key`) and quoted literals count.
    # Substring matching against the whole blob is worthless here -- "level",
    # "power", "resource" occur incidentally everywhere.
    fields = set()
    literals = set()
    for root, _, files in os.walk(os.path.join(ROOT, "lib")):
        for fn in files:
            if not fn.endswith((".ex", ".eex")):
                continue
            txt = read(os.path.join(root, fn))
            fields.update(re.findall(r":([a-z_][a-z0-9_]*)\b", txt))
            literals.update(re.findall(r'"([^"\n]{1,40})"', txt))
    # other data files (verbs.ucl, *.help, *.json) also count as "engine side"
    data_lits = set()
    for fn in os.listdir(os.path.join(ROOT, "data")):
        p = os.path.join(ROOT, "data", fn)
        if os.path.isfile(p) and fn.endswith((".ucl", ".help", ".json")):
            data_lits.update(re.findall(r'"([^"\n]{1,40})"', read(p)))

    a, b, c = {}, {}, {}
    for k, n in src.items():
        if k in ucl_blob or k.split("/")[-1] in ucl_blob:
            continue
        if k in ALIAS and ALIAS[k] in ucl_blob:
            a[k] = n
            continue
        if k in fields or k in literals or k in data_lits:
            b[k] = n
            continue
        c[k] = n

    print(f"distinct set() keys in corpus : {len(src)}")
    print(f"A. converted-under-alias      : {len(a)}  ({sum(a.values())} occ)")
    print(f"B. engine-implemented         : {len(b)}  ({sum(b.values())} occ)")
    print(f"C. TRULY MISSING              : {len(c)}  ({sum(c.values())} occ)")
    print("\n-- C. truly missing, top 60 --")
    for k, n in sorted(c.items(), key=lambda kv: -kv[1])[:60]:
        print(f"  {k:34s}{n}")
    print("\n-- A. alias hits (sample) --")
    for k, n in sorted(a.items(), key=lambda kv: -kv[1])[:12]:
        print(f"  {k:34s}{n}   -> {ALIAS.get(k)}")

    os.makedirs(os.path.join(ROOT, "tmp"), exist_ok=True)
    with open(os.path.join(ROOT, "tmp", "lost_key_triage.json"), "w", encoding="utf-8") as fh:
        json.dump({"alias": a, "engine": b, "missing": c}, fh, ensure_ascii=False, indent=1)
    print("\nwrote tmp/lost_key_triage.json")


if __name__ == "__main__":
    main()
