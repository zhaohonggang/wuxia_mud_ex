#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UG-06 clone_lib 跨区借用 NPC 的 carry 裸引用回填。

clone_lib.ucl 里借用 NPC 的块头注释：`# LPC 跨区借用：id 前缀是来源区`，
characters key 形如 `gaibang_6dai` —— 前缀即来源 zone。
把 carry 中不带前缀的 `items.<key>.id` 改写为 `<prefix>.items.<key>.id`；
若该 zone 没有该物品键，则按全 zone 唯一定义回退（与引擎规则一致）；
多区歧义或无定义则保留并报告。
"""
import re
import sys
from pathlib import Path

UCL = Path("data/world/clone_lib.ucl")

# ex 侧各 zone 的 items key 集合（从 loader 输出难以拿到，改用文本扫描）
def collect_zone_keys():
    zones = {}
    for u in Path("data/world").glob("*.ucl"):
        zone = u.stem
        keys = set()
        for m in re.finditer(r'items "([\w-]+)" \{', u.read_text(encoding="utf-8")):
            keys.add(m.group(1).replace("-", "_"))
        zones.setdefault(zone, set()).update(keys)
    return zones

ZONE_KEYS = collect_zone_keys()

# 仅处理当前 survey 仍失败的键（未失败的引用不动）
TARGET_KEYS = {
    "armor1", "beixin", "bi", "blade1", "cloth1", "cloth2", "cloth4",
    "fuchen", "greenrobe", "greyrobe", "hat", "staff", "tiejiang", "yayifu",
}

BLOCK_RE = re.compile(r'(    characters "(\w+)" \{)')
CARRY_RE = re.compile(r'(carry = \[\n)((?:.*?\n)*?)(  \])')
REF_RE = re.compile(r'\{ id = items\.([\w]*)\.id \}')

def process(report, apply):
    text = UCL.read_text(encoding="utf-8")
    out = []
    last = 0
    changed = 0
    for m in BLOCK_RE.finditer(text):
        key = m.group(2)
        nxt = text.find("    characters \"", m.end())
        block = text[m.end():nxt if nxt != -1 else len(text)]
        cm = CARRY_RE.search(block)
        if not cm or "_" not in key:
            continue
        prefix = key.split("_", 1)[0]
        if prefix not in ZONE_KEYS:
            continue
        body = cm.group(2)

        def repl(rm):
            nonlocal changed
            k = rm.group(1)
            if k not in TARGET_KEYS:
                return rm.group(0)
            if prefix in ZONE_KEYS and k in ZONE_KEYS[prefix]:
                changed += 1
                return "{ id = %s.items.%s.id }" % (prefix, k)
            defining = [z for z, ks in ZONE_KEYS.items() if k in ks]
            if len(defining) == 1:
                changed += 1
                report.append(("GLOBAL_UNIQUE", key, k, defining[0]))
                return "{ id = %s.items.%s.id }" % (defining[0], k)
            report.append(("UNRESOLVED", key, k, str(defining)))
            return rm.group(0)

        new_body = REF_RE.sub(repl, body)
        if changed:
            new_block = block[:cm.start(2)] + new_body + block[cm.end(2):]
            out.append(text[last:m.end()])
            out.append(new_block)
            last = nxt if nxt != -1 else len(text)
    out.append(text[last:])
    if changed and apply:
        UCL.write_text("".join(out), encoding="utf-8", newline="\n")
    return changed

def main():
    apply = "--apply" in sys.argv
    report = []
    n = process(report, apply)
    print(f"rewrote: {n}" + ("" if apply else "  (DRY RUN)"))
    for row in report:
        print(" | ".join(str(x) for x in row))

if __name__ == "__main__":
    main()
