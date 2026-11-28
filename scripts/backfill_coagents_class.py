#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UG-05 #749 续：kungfu/class 真身文件的 coagents 回填（按 NPC 中文名定位 UCL 块）。"""
import re
import sys
from pathlib import Path

LPC_RE = re.compile(r'set\("coagents",\s*\(\{([\s\S]*?)\}\)\);')
ENTRY_RE = re.compile(r'\[\s*"startroom"\s*:\s*"([^"]+)"\s*,\s*"id"\s*:\s*"([^"]+)"\s*\]')
NAME_RE = re.compile(r'set_name\((?:\w+\s+)?"([^"]+?)"\s*(?:NOR)?\s*(?:,\s*\(\{)?')
CHAR_RE = re.compile(r'characters "([\w]+)" \{')

def lpc_info(rel):
    text = Path(r"C:/files/git/mud/" + rel).read_text(encoding='utf-8', errors='replace')
    lines = [l for l in text.split("\n") if not l.lstrip().startswith("//")]
    body = "\n".join(lines)
    entries = []
    for m in LPC_RE.finditer(body):
        for e in ENTRY_RE.finditer(m.group(1)):
            entries.append((e.group(1), e.group(2)))
    nm = NAME_RE.search(body)
    name = nm.group(1).strip() if nm else None
    return name, entries

def norm_room(sr):
    room = sr.strip().removesuffix(".c")
    # LPC 占位（xxxx*）或非 /d/ 路径 → 留空（无条件通知，不伪造房间）
    if not room.startswith("/d/") or re.fullmatch(r"x+", room.split("/")[-1] or "x"):
        return None
    m = re.match(r"^/d/([^/]+)/(.+)$", room)
    if not m:
        return None
    # 房间 key 取 basename（转换器规则）
    return f"{m.group(1)}:{m.group(2).replace('-', '_').rsplit('/', 1)[-1]}"

def process(apply=False):
    root = Path(r"C:/files/git/mud/kungfu/class")
    ucls = {u: u.read_text(encoding='utf-8') for u in sorted(Path("data/world").glob("*.ucl"))}
    changed_files = {}
    report = []
    total = 0

    for f in sorted(root.rglob("*.c")):
        try:
            name, entries = lpc_info(f.relpath if False else str(f).replace("\\", "/").replace("C:/files/git/mud/", ""))
        except OSError:
            continue
        if not entries or not name:
            continue
        rel = str(f).replace("\\", "/").replace("C:/files/git/mud/", "")
        # 已回填的按 id 跳过
        first_id = entries[0][1]
        if any(re.search(r'id = "' + re.escape(first_id) + r'" startroom', t) for t in ucls.values()):
            continue

        rows = []
        for sr, cid in entries:
            r = norm_room(sr)
            rows.append(f'    {{ id = "{cid}" startroom = "{r}" }}' if r else f'    {{ id = "{cid}" }}')
        block_txt = "  coagents = [\n" + ",\n".join(rows) + "\n  ]\n"

        # 在所有 UCL 找 name = "<中文名>" 的 characters 块
        hits = []
        for u, t in ucls.items():
            for cm in CHAR_RE.finditer(t):
                blk_start = cm.end()
                # 块边界：下一个 characters 块（借用块之间没有 Generated header）
                nxt_m = re.search(r'\n    characters "', t[blk_start:])
                nxt = blk_start + nxt_m.start() if nxt_m else len(t)
                blk = t[blk_start:nxt]
                if re.search(r'name = "' + re.escape(name) + r'"', blk[:500]):
                    hits.append((u, cm, blk, nxt))
        if len(hits) != 1:
            report.append((f"AMBIGUOUS x{len(hits)}", rel, name))
            continue
        u, cm, blk, nxt = hits[0]
        if "coagents" in blk:
            report.append(("ALREADY", rel, name))
            continue
        pos = blk.rfind("\n    }")
        if pos == -1:
            report.append(("BLOCK_SHAPE", rel, name))
            continue
        seg2 = blk[:pos] + "\n" + block_txt + blk[pos:]
        t = ucls[u]
        new_t = t[:cm.start()] + t[cm.start():cm.end()] + seg2 + t[nxt if nxt != -1 else len(t):]
        # 重建：原 cm.start() 到 nxt 区段替换
        new_t = t[:cm.end()] + seg2 + t[nxt if nxt != -1 else len(t):]
        if apply:
            u.write_text(new_t, encoding='utf-8', newline='\n')
        ucls[u] = new_t
        changed_files[u.name] = changed_files.get(u.name, 0) + 1
        total += 1
        print(f"{rel}: {name} -> {u.name} ({len(entries)} coagents)")

    print(f"\nTOTAL: {total}" + ("" if apply else "  (DRY RUN)"))
    if report:
        print("\n-- WARN --")
        for row in report:
            print(" | ".join(str(x) for x in row))

if __name__ == "__main__":
    process("--apply" in sys.argv)
