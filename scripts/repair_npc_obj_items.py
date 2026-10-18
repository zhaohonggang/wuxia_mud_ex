#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 `d/*/npc/obj/*.c` 被误分类为 characters 的世界数据。

## 背景

转换器 `_determine_object_type`（见 `scripts/lpc_converter.py` 与
`lib/kantele/world/lpc_converter.ex`）曾把 `npc/` 路径判定放在「物品继承」
判定之前，于是 `d/beijing/npc/obj/blade.c`（`inherit BLADE;`）这类路径含
`npc` 但实为物品的文件被生成为：

    # Generated from .../npc/obj/blade.c by LPCConverter
    # Zone: beijing

        characters "blade" { ... }

而 loader 只会把 `items "x" { ... }` 段放进物品缓存（`Kantele.World.Items`），
`characters` 段则被当作 NPC —— 于是这些物品在运行时 `Items.get("beijing:blade")`
取不到定义（发物动作只能给出「未知物品」占位）。

## 本脚本做什么

只做**最小、安全**的原地修复：把「由 `/npc/obj/` 源文件生成、但被写成
`characters` 的对象块」的关键字改成 `items`。**不动块内容**（name / aliases /
description 等都是合法物品字段），**不动行尾**（保持 LF），**不触碰其它块**。

保守起见只在调用方显式给出的 UCL 文件上运行；通用修复（全量重新生成）留待
转换器修复后的后续 pass（分类 bug 已在两个转换器里修正）。

用法:
    python scripts/repair_npc_obj_items.py data/world/beijing.ucl [more.ucl ...]
"""

import io
import re
import sys
from pathlib import Path

# 匹配「由 npc/obj 源生成、当前为 characters」的块头，并捕获其整块（扁平、无嵌套花括号）。
BLOCK_RE = re.compile(
    r'(# Generated from (?P<src>[^\n]*?/npc/obj/[^\n]*?) by LPCConverter\n'
    r'# Zone: [^\n]*\n\n'
    r'    )characters (?P<name>"[^"]+")(\s*\{.*?\n    \}\n)',
    re.S,
)


def repair_text(text: str) -> tuple[str, list[str]]:
    """返回 (修复后文本, 被修复的对象名列表)。"""
    names: list[str] = []

    def _repl(m: re.Match) -> str:
        names.append(m.group("name").strip('"'))
        return f'{m.group(1)}items {m.group("name")}{m.group(4)}'

    return BLOCK_RE.sub(_repl, text), names


def repair_file(path: Path) -> int:
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    fixed, names = repair_text(text)
    if fixed == text:
        print(f"{path}: 无需修复")
        return 0
    if path.read_bytes().decode("utf-8").count("\r\n") != 0:
        print(f"{path}: 含 CRLF，拒绝（本仓库约定 LF）", file=sys.stderr)
        return 2
    path.write_bytes(fixed.encode("utf-8"))
    print(f"{path}: 修复 {len(names)} 个 -> {', '.join(names)}")
    return len(names)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    total = 0
    for arg in argv[1:]:
        total += repair_file(Path(arg))
    print(f"共修复 {total} 个对象块")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main(sys.argv))
