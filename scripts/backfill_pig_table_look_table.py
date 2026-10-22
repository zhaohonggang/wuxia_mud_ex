#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4r backfill: 给 city:eproom/nproom/sproom/wproom 四间拱猪房回填 look_table 配置。

对应 LPC d/city/eproom.c（nproom/sproom/wproom 同源）的 look_table()：

    string look_table()
    {
        if (this_player()->query_temp("pigging_seat"))
            return table_str(this_player()->query_temp("pigging_seat"));
        return table_str("");
    }

本端口由新 handler `pig_table` 渲染：读角色 temp pigging_seat 与房间 state 中的
pig_* 字段，输出牌桌座位状态（详见 lib/kantele/world/item_desc_handlers/pig_table.ex）。

本房间已有的结构（转换器输出，item_desc 写了 paper，table 闭包被丢弃）：
    rooms "eproom" {
      ...
      item_desc = {        # 已有 paper 静态键，本脚本在其中追加 table
       paper = "..."
      }
      valid_leave = [ ... ]
    }

回填内容（每间房）：
  1) 在 item_desc 块内追加：
       table = {
         kind = "pig_table"
       }
  2) 在 item_desc 块闭合 } 之后追加（牌局初始播种）：
       state = {
         pig_phase = "initting"
         pig_north = ""
         pig_west = ""
         pig_south = ""
         pig_east = ""
         pig_server = ""
       }

`pig_*` 为 LPC PIG_ROOM 牌局状态的运行时副本（phase/pl/server 等）。本批只落地
读取与渲染（look_table），坐下/发牌/叫牌/出牌等动作留待后续子系统接线。

门禁（与 P5-4p 一致）：G1 dry-run -> G2 备份 -> G3 写盘(newline="") -> G4 validate_ucl
-> G5 幂等复跑 0 待改。

用法：
    python scripts/backfill_pig_table_look_table.py            # dry-run
    python scripts/backfill_pig_table_look_table.py --apply    # 真正写盘
"""
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_WORLD = os.path.join(ROOT, "data", "world")
VALIDATE = os.path.join(ROOT, "scripts", "validate_ucl.py")

TARGET_ZONE = "city.ucl"
TARGET_STEMS = ["eproom", "nproom", "sproom", "wproom"]
KIND = "pig_table"
PIG_PHASE = "initting"

OPEN_RE = re.compile(r'^\s*rooms\s+"(%s)"\s*\{' % "|".join(re.escape(s) for s in TARGET_STEMS))
ITEM_DESC_RE = re.compile(r"^\s*item_desc\s*=\s*\{")
KIND_RE = re.compile(r'kind\s*=\s*"%s"' % re.escape(KIND))


def find_block_close(lines, start):
    """从 start 行起做括号深度扫描，返回深度回到 0 的那一行（不含 start 自身）。"""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        if depth <= 0 and j > start:
            return j
    return None


def find_rooms_blocks(text):
    """返回 {stem: (start, close)} 行号（0-based）。"""
    lines = text.split("\n")
    result = {}
    for i, line in enumerate(lines):
        m = OPEN_RE.match(line)
        if m:
            stem = m.group(1)
            close = find_block_close(lines, i)
            if close is not None:
                result[stem] = (i, close)
    return result


def already_done(text):
    """四间房都已有 kind = "pig_table" 则视为完成。"""
    blocks = find_rooms_blocks(text)
    if len(blocks) != len(TARGET_STEMS):
        return False
    lines = text.split("\n")
    for stem in TARGET_STEMS:
        start, close = blocks[stem]
        seg = "\n".join(lines[start : close + 1])
        if not KIND_RE.search(seg):
            return False
    return True


def plan():
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if already_done(text):
        print("  [IDEMPOTENT] %s :: 四间拱猪房均已有 pig_table，跳过" % TARGET_ZONE)
        return None
    blocks = find_rooms_blocks(text)
    missing = [s for s in TARGET_STEMS if s not in blocks]
    if missing:
        print("  [SKIP] %s :: 找不到 rooms 块：%s" % (TARGET_ZONE, ", ".join(missing)), file=sys.stderr)
        return None
    lines = text.split("\n")
    plan_items = []
    for stem in TARGET_STEMS:
        start, close = blocks[stem]
        seg = "\n".join(lines[start : close + 1])
        if KIND_RE.search(seg):
            print("  [IDEMPOTENT] %s :: %s 已有 pig_table，跳过" % (TARGET_ZONE, stem))
            continue
        # 只在该房间的 rooms 块内找 item_desc = { 的开行
        ido = None
        for i in range(start, close):
            if ITEM_DESC_RE.match(lines[i]):
                ido = i
                break
        if ido is None:
            print("  [SKIP] %s :: %s 找不到 item_desc 块" % (TARGET_ZONE, stem), file=sys.stderr)
            continue
        idc = find_block_close(lines, ido)
        if idc is None:
            print("  [SKIP] %s :: %s item_desc 块未闭合" % (TARGET_ZONE, stem), file=sys.stderr)
            continue
        plan_items.append({
            "stem": stem,
            "start": start,
            "close": close,
            "item_desc_open": ido,
            "item_desc_close": idc,
        })
    if not plan_items:
        print("  无需改动。")
        return None
    return plan_items


def backup():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-pig-table-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    shutil.copy2(os.path.join(DATA_WORLD, TARGET_ZONE), os.path.join(bdir, TARGET_ZONE))
    print("  备份 -> %s" % bdir)
    return bdir


TABLE_LINES = [
    " table = {",
    '   kind = "%s"' % KIND,
    " }",
]

STATE_LINES = [
    " state = {",
    '  pig_phase = "%s"' % PIG_PHASE,
    '  pig_north = ""',
    '  pig_west = ""',
    '  pig_south = ""',
    '  pig_east = ""',
    '  pig_server = ""',
    " }",
]


def apply(plan_items):
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")

    # 从后往前插入，避免索引错位；每个房间独立处理。
    for item in reversed(plan_items):
        idc = item["item_desc_close"]
        # 先插 state（在 item_desc 闭合 } 之后），再插 table（在闭合 } 之前）。
        lines[idc + 1 : idc + 1] = STATE_LINES
        lines[idc:idc] = TABLE_LINES
        print("  写入 %s :: %s +item_desc.table / +state{pig_*}" % (TARGET_ZONE, item["stem"]))

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))


def validate():
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    try:
        res = subprocess.run(
            [sys.executable, VALIDATE, path], capture_output=True, text=True, cwd=ROOT
        )
        if res.returncode != 0:
            print("  [VALIDATE FAIL] %s\n%s" % (TARGET_ZONE, res.stdout[-2000:]))
            return False
        print("  [validate ok] %s" % TARGET_ZONE)
        return True
    except Exception as e:  # noqa
        print("  [VALIDATE ERROR] %s: %s" % (TARGET_ZONE, e))
        return False


def main():
    apply_flag = "--apply" in sys.argv
    print("== P5-4r pig_table look_table backfill ==")
    print("模式: %s" % ("APPLY" if apply_flag else "dry-run"))
    p = plan()
    if p is None:
        print("无需改动。")
        return
    for item in p:
        print("  计划：%s :: %s  (item_desc@%d, close@%d)" % (
            TARGET_ZONE, item["stem"], item["item_desc_open"], item["item_desc_close"]))

    if not apply_flag:
        print("\n(dry-run 结束；加 --apply 真正写盘)")
        return

    backup()
    apply(p)
    print("\n== 校验 ==")
    if not validate():
        print("VALIDATE 失败，请检查。", file=sys.stderr)
        sys.exit(1)
    print("\n== 幂等复跑 ==")
    if already_done(open(os.path.join(DATA_WORLD, TARGET_ZONE), encoding="utf-8").read()):
        print("  OK：复跑确认 pig_table 已存在（幂等 0 待改）。")
    else:
        print("  [WARN] 幂等检查未通过：复跑仍能处理。", file=sys.stderr)
        sys.exit(2)
    print("OK：city:eproom/nproom/sproom/wproom look_table 回填完毕。")


if __name__ == "__main__":
    main()
