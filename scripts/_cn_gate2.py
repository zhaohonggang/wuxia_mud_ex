#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_cn_gate2.py — 精确统计『门条件 -> return notify_fail』的配对，找出可机械补齐的类。"""
import re
import collections
from pathlib import Path

SRC = Path("C:/files/git/mud/kungfu/skill")

# 每条语句窗口：从 if (...) 到大括号/分号结束，找其中的 notify_fail
GATES = {
    "me_is_fighting": re.compile(r"if\s*\(\s*(?:!\s*)?me\s*->\s*is_fighting\s*\(\s*\)"),
    "me_or_target_fighting": re.compile(r"if\s*\(\s*me\s*->\s*is_fighting\s*\(\s*\)\s*\|\|\s*(?:target|victim)"),
    "target_is_fighting": re.compile(r"if\s*\(\s*(?:target|victim)\s*->\s*is_fighting\s*\(\s*\)"),
    "me_is_busy": re.compile(r"if\s*\(\s*(?:!\s*)?me\s*->\s*is_busy\s*\(\s*\)"),
    "target_is_busy": re.compile(r"if\s*\(\s*(?:target|victim)\s*->\s*is_busy\s*\(\s*\)"),
    "not_living": re.compile(r"if\s*\(\s*!\s*living\s*\(\s*(?:target|victim)"),
}

cnt = collections.Counter()
perfile = collections.defaultdict(set)
cjk = re.compile(r"[\u4e00-\u9fff]")

for c in SRC.rglob("*.c"):
    raw = c.read_text(encoding="utf-8", errors="replace")
    for name, rx in GATES.items():
        for m in rx.finditer(raw):
            # find the notify_fail within the next ~200 chars
            win = raw[m.start():m.start() + 240]
            nf = re.search(r'notify_fail\s*\(\s*"([^"]*)"', win)
            if nf and cjk.search(nf.group(1)):
                cnt[name] += 1
                perfile[name].add(str(c.relative_to(SRC)))

print("门条件 -> notify_fail 配对计数（含中文文案）：")
for k, v in cnt.most_common():
    print(f"  {k}: {v} 句 / {len(perfile[k])} 文件")
