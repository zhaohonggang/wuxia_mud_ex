#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UG-05 #749：LPC coagents（帮手助战）全量回填。

对全库 `set("coagents", ({ ([ "startroom" : "/d/zone/room", "id" : "npc id" ]) ... }))`
的 NPC 文件，按 UCL 块头 `# Generated from <path>.c` 精确定位 characters 块，
把 coagents 数组回填为：

    coagents = [
      { id = "ouyang feng" startroom = "baituo:dating" },
    ]

（格式对齐 #986 丐帮 li/lu 既有回填；startroom 归一为 ex `zone:room_key`，
room 路径段 `-`→`_`。）已有 coagents 的块跳过。
"""
import re
import sys
from pathlib import Path

WORLD = Path("data/world")
LPC_COAGENT_RE = re.compile(
    r'set\("coagents",\s*\(\{([\s\S]*?)\}\)\);'
)
ENTRY_RE = re.compile(
    r'\[\s*"startroom"\s*:\s*"([^"]+)"\s*,\s*"id"\s*:\s*"([^"]+)"\s*\]'
    r'|\[\s*"id"\s*:\s*"([^"]+)"\s*,\s*"startroom"\s*:\s*"([^"]+)"\s*\]'
)
CHAR_KEY_RE = re.compile(r'(\w+)\.c\b')


def lpc_coagents(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    # 去掉整行 // 注释（含 //** 的注释块）
    lines = []
    for line in text.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        lines.append(line)
    body = "\n".join(lines)
    entries = []
    for m in LPC_COAGENT_RE.finditer(body):
        for e in ENTRY_RE.finditer(m.group(1)):
            if e.group(1):
                startroom, cid = e.group(1), e.group(2)
            else:
                cid, startroom = e.group(3), e.group(4)
            entries.append((startroom, cid))
    return entries


def normalize_startroom(lpc_room: str):
    room = lpc_room.strip().removesuffix(".c")
    m = re.match(r"^/d/([^/]+)/(.+)$", room)
    if not m:
        return None
    zone, room_key = m.group(1), m.group(2).replace("-", "_")
    return f"{zone}:{room_key}"


def process(apply=False):
    report = []
    rewritten = 0
    files = [p for p in Path("/c/files/git/mud/d").rglob("*.c") if "/c/files/git/mud" ]
    # Windows: 用 Path 无法直接 rglob /c/...，改用字符串根
    root = Path(r"C:/files/git/mud/d")
    files = [p for p in root.rglob("*.c")]

    # 先收集所有 (lpc_path -> entries)
    plans = []
    for f in sorted(files):
        try:
            entries = lpc_coagents(f)
        except OSError:
            continue
        if not entries:
            continue
        plans.append((f, entries))

    # 预读所有 UCL 文本
    ucl_texts = {u: u.read_text(encoding="utf-8") for u in sorted(WORLD.glob("*.ucl"))}

    for f, entries in plans:
        lpc_rel = str(f).replace("\\", "/").replace("C:/files/git/mud/", "")
        marker = f"# Generated from C:/files/git/mud/{lpc_rel} by LPCConverter"
        hit_ucl = None
        for u, text in ucl_texts.items():
            if marker in text:
                hit_ucl = (u, text)
                break
        if hit_ucl is None:
            report.append(("NO_UCL_BLOCK", lpc_rel))
            continue
        u, text = hit_ucl
        startrooms = [normalize_startroom(sr) for sr, _ in entries]
        if any(sr is None for sr in startrooms):
            report.append(("BAD_STARTROOM", lpc_rel, str(startrooms)))
            continue
        coagent_block = "coagents = [\n" + "".join(
            f'    {{ id = "{cid}" startroom = "{sr}" }}{"," if i < len(entries) - 1 else ""}\n'
            for i, (sr, (_x, cid)) in enumerate(zip(startrooms, entries))
        ) + "  ]"
        # 定位该块 characters 的位置
        m = re.search(re.escape(marker) + r'\n# Zone: (\w+)\n\n\s*characters "(\w+)" \{', text)
        if not m:
            report.append(("NO_CHAR_BLOCK", lpc_rel))
            continue
        block_start = m.end()
        nxt = text.find("# Generated from", block_start)
        block = text[block_start:nxt if nxt != -1 else len(text)]
        if "coagents" in block:
            report.append(("ALREADY", lpc_rel))
            continue
        # 插入位置：carry/skills 前的最后，直接放块尾（下一个 Generated 前）
        new_block = block.rstrip("\n") + "\n\n  " + coagent_block + "\n\n    }\n"
        # 块原有的结尾 "    }" 已包含在 block 里？block 含到下一个 header 之前，应含 "    }"
        if not block.rstrip().endswith("}"):
            report.append(("BLOCK_SHAPE", lpc_rel, block[-80:]))
            continue
        # 移除原结尾，替换为 coagents + 原结尾
        idx = block.rstrip().rfind("    }")
        body_part = block[:idx]
        new_block = body_part.rstrip("\n") + "\n\n  " + coagent_block + "\n    }\n"
        if apply:
            new_text = text[:block_start] + new_block + text[nxt if nxt != -1 else len(text):]
            u.write_text(new_text, encoding="utf-8", newline="\n")
            ucl_texts[u] = new_text
        rewritten += 1
        print(f"{lpc_rel}: {len(entries)} coagents -> {u.name}")

    print(f"\nTOTAL: {rewritten}" + ("" if apply else "  (DRY RUN)"))
    if report:
        print("\n-- WARN --")
        for row in report:
            print(" | ".join(str(x) for x in row))


if __name__ == "__main__":
    process("--apply" in sys.argv)
