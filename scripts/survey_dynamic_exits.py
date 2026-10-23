#!/usr/bin/env python3
"""勘查 LPC 源里所有 `set("exits/...")` / `delete("exits/...")` 调用点。

目的：给「动态出口」消费端移植排批次。输出每个调用点所在的
(区, 房间文件, 函数名, 是否玩家可触发, 涉及方向)。

判定「玩家可触发」：
  - 函数名以 `do_` 开头；或
  - 文件里有 `add_action("<verb>", "<函数名>")` 指向它。
其余（`close_*` / `check_trigger` / `on_board` / `arrive` / `trapping` /
`reset` / `init` / `setup` 等）是定时器与 NPC/对象回调。

用法：
    python scripts/survey_dynamic_exits.py            # markdown 表格
    python scripts/survey_dynamic_exits.py --csv      # CSV
    python scripts/survey_dynamic_exits.py --zone shaolin
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys

MUD_ROOT = os.environ.get("MUD_ROOT", "/c/files/git/mud")
SCAN_DIRS = ("d", "clone")

# `set("exits/north", ...)` / `delete("exits/north")`；也兼容 `query("exits/...")` 之外的写法
CALL_RE = re.compile(r'\b(set|delete)\s*\(\s*"exits/([a-z]+)"')

# 顶层函数头：返回类型 + 名字 + 参数表，左花括号可有可无
FUNC_RE = re.compile(
    r"^(?:[A-Za-z_][\w \t\*]*?)\b([A-Za-z_]\w*)\s*\([^;{]*\)\s*\{?\s*$"
)

# `add_action("do_open", "open")` —— 第二参数是 verb，第一是函数
ADD_ACTION_RE = re.compile(r'add_action\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')

# 明显不是玩家动作的前缀/名字
NON_ACTION_NAMES = {
    "init",
    "setup",
    "reset",
    "create",
    "check_trigger",
    "arrive",
    "on_board",
    "off_board",
    "trapping",
    "destruct",
    "heart_beat",
    "call_out_close",
    "close_men",
    "close_door",
    "close_gate",
}


def room_id_from_path(path: str) -> str:
    """`d/shaolin/guangchang.c` -> `shaolin:guangchang`"""
    rel = os.path.relpath(path, MUD_ROOT)
    rel = rel.replace("\\", "/")
    zone, _, name = rel.rpartition("/")
    zone = zone.split("/", 1)[1] if "/" in zone else zone
    return f"{zone}:{name[:-2]}"


def zone_from_path(path: str) -> str:
    rel = os.path.relpath(path, MUD_ROOT).replace("\\", "/")
    parts = rel.split("/")
    return parts[1] if len(parts) > 2 else parts[0]


def enclosing_func(lines: list[str], lineno: int) -> str:
    """从 lineno（0 基）往前找最近的顶层函数头。"""
    depth_guess = 0
    for i in range(lineno, -1, -1):
        line = lines[i]
        if not line or line[0] in " \t":
            continue
        m = FUNC_RE.match(line.rstrip())
        if m:
            name = m.group(1)
            if name in ("if", "for", "while", "switch", "return", "else"):
                continue
            # 排除 `set(...)`、`call_out(...)` 这类调用被误当函数头
            if name in ("set", "delete", "query", "call_out", "message", "notify_fail"):
                continue
            del depth_guess
            return name
    return "?"


def scan_file(path: str) -> list[dict]:
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []

    lines = text.split("\n")
    add_actions = {}
    # add_action(函数名, verb) —— 第一个参数才是函数
    for func, verb in ADD_ACTION_RE.findall(text):
        add_actions.setdefault(func, set()).add(verb)

    out = []
    for idx, line in enumerate(lines):
        matches = CALL_RE.findall(line)
        if not matches:
            continue
        func = enclosing_func(lines, idx)
        is_action = func.startswith("do_") or func in add_actions
        out.append(
            {
                "zone": zone_from_path(path),
                "room": room_id_from_path(path),
                "file": os.path.relpath(path, MUD_ROOT).replace("\\", "/"),
                "line": idx + 1,
                "func": func,
                "verbs": ",".join(sorted(add_actions.get(func, set()))) or "-",
                "player": "yes" if is_action else "no",
                "dirs": ",".join(sorted({d for _op, d in matches})),
                "ops": ",".join(sorted({op for op, _d in matches})),
            }
        )
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", action="store_true")
    ap.add_argument("--zone")
    ap.add_argument("--player-only", action="store_true")
    args = ap.parse_args()

    rows: list[dict] = []
    for sub in SCAN_DIRS:
        root = os.path.join(MUD_ROOT, sub)
        for dirpath, _dirnames, filenames in os.walk(root):
            for fn in sorted(filenames):
                if fn.endswith(".c"):
                    rows.extend(scan_file(os.path.join(dirpath, fn)))

    if args.zone:
        rows = [r for r in rows if r["zone"] == args.zone]
    if args.player_only:
        rows = [r for r in rows if r["player"] == "yes"]

    rows.sort(key=lambda r: (r["zone"], r["room"], r["func"], r["line"]))

    if args.csv:
        w = csv.DictWriter(sys.stdout, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
        return 0

    print(f"调用点 {len(rows)} 个 / 文件 {len({r['file'] for r in rows})} 个")
    print()
    print("| 区 | 房间 | 函数 | add_action verb | 玩家可触发 | 方向 | 操作 |")
    print("|---|---|---|---|:--:|---|---|")
    for r in rows:
        print(
            f"| {r['zone']} | {r['room']} | {r['func']} | {r['verbs']} | "
            f"{r['player']} | {r['dirs']} | {r['ops']} |"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
