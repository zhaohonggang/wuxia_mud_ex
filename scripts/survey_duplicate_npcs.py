#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UG-09 survey：同一 (zone, characters key) 的重复定义块。"""
import re
import sys
from pathlib import Path
from collections import defaultdict

WORLD = Path("data/world")
BLOCK_RE = re.compile(r'(?<![\w_])characters "([\w]+)" \{')

def survey_file(ucl):
    text = ucl.read_text(encoding="utf-8")
    seen = defaultdict(list)
    for m in BLOCK_RE.finditer(text):
        nm = re.search(r'name = "([^"]*)"', text[m.end():m.end() + 2000])
        seen[m.group(1)].append(nm.group(1) if nm else "?")
    return {k: v for k, v in seen.items() if len(v) > 1}

def main():
    total = 0
    for ucl in sorted(WORLD.glob("*.ucl")):
        for key, names in sorted(survey_file(ucl).items()):
            total += 1
            same = "SAME" if len(set(names)) == 1 else "DIFF"
            print(f"{ucl.stem}:{key}  x{len(names)}  {same}  names={names}")
    print(f"\nTOTAL duplicate (zone,key): {total}")

if __name__ == "__main__":
    sys.exit(main())
