#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4q backfill: 给 city:guangchang 回填 look_gaoshi 的访客计数条幅配置。

对应 LPC d/city/guangchang.c 的 look_gaoshi()：
    count = query("visitor");
    returnback = "扬州府通告" 定宽条幅，中间写 "近期共有<N人>人通过此地。"

本端口由新 handler `gaoshi_visitor` 渲染：读房间 state.visitor（UCL state 播种），
转中文数字后拼装定宽 ASCII 条幅（详见 lib/kantele/world/item_desc_handlers/gaoshi_visitor.ex）。

本房间已有的结构（转换器输出，缩进不统一，按就近风格对齐）：
    rooms "guangchang" {
      ...
      item_desc = {        # 已有 dong / tree 两个静态键，本脚本在其中追加 gaoshi
        dong = "..."
        tree = "..."
      }
      flags = [ ... ]
      actions = { ... }
    }

回填内容：
  1) 在 item_desc 块内追加：
        gaoshi = {
          kind = "gaoshi_visitor"
        }
  2) 在 item_desc 块闭合 } 之后追加（访客计数播种）：
        state = {
          visitor = 365
        }

`visitor = 365` 是 LPC `query("visitor")` 的运行时计数初始播种值（LPC 在玩家每次
进入 init() 时 add("visitor", 1) 自增；运行期增量钩子为后续事项，本批只落地读取与渲染）。

门禁（与 P5-4p 一致）：G1 dry-run -> G2 备份 -> G3 写盘(newline="") -> G4 validate_ucl
-> G5 幂等复跑 0 待改。

用法：
    python scripts/backfill_guoshi_visitor.py            # dry-run
    python scripts/backfill_guoshi_visitor.py --apply    # 真正写盘
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
TARGET_STEM = "guangchang"
KIND = "gaoshi_visitor"
SEED_VISITOR = 365

OPEN_RE = re.compile(r'^\s*rooms\s+"%s"\s*\{' % re.escape(TARGET_STEM))
ITEM_DESC_RE = re.compile(r"^\s*item_desc\s*=\s*\{")


def find_block_close(lines, start):
    """从 start 行起做括号深度扫描，返回深度回到 0 的那一行（不含 start 自身）。"""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        if depth <= 0 and j > start:
            return j
    return None


def find_rooms_block(text, stem):
    """返回 (start, close) 行号（0-based）；找不到返回 None。"""
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if OPEN_RE.match(line):
            close = find_block_close(lines, i)
            return (i, close)
    return None


def already_done(text):
    block = find_rooms_block(text, TARGET_STEM)
    if block is None:
        return False
    start, close = block
    lines = text.split("\n")
    seg = "\n".join(lines[start : close + 1])
    return ('kind = "%s"' % KIND) in seg


def plan():
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if already_done(text):
        print("  [IDEMPOTENT] %s :: %s 已有 gaoshi_visitor，跳过" % (TARGET_ZONE, TARGET_STEM))
        return None
    block = find_rooms_block(text, TARGET_STEM)
    if block is None:
        print("  [SKIP] %s :: %s 找不到 rooms 块" % (TARGET_ZONE, TARGET_STEM), file=sys.stderr)
        return None
    start, close = block
    lines = text.split("\n")
    # 只在 guangchang 的 rooms 块内找 item_desc = { 的开行
    ido = None
    for i in range(start, close):
        if ITEM_DESC_RE.match(lines[i]):
            ido = i
            break
    if ido is None:
        print("  [SKIP] %s :: %s 找不到 item_desc 块" % (TARGET_ZONE, TARGET_STEM), file=sys.stderr)
        return None
    idc = find_block_close(lines, ido)
    if idc is None:
        print("  [SKIP] %s :: %s item_desc 块未闭合" % (TARGET_ZONE, TARGET_STEM), file=sys.stderr)
        return None
    return {"close": close, "item_desc_open": ido, "item_desc_close": idc}


def backup():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-guoshi-visitor-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    shutil.copy2(os.path.join(DATA_WORLD, TARGET_ZONE), os.path.join(bdir, TARGET_ZONE))
    print("  备份 -> %s" % bdir)
    return bdir


GAOSHI_LINES = [
    " gaoshi = {",
    '   kind = "%s"' % KIND,
    " }",
]
STATE_LINES = [
    "  state = {",
    "    visitor = %d" % SEED_VISITOR,
    "  }",
]


def apply(plan):
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")
    idc = plan["item_desc_close"]
    # 先插 state（在 item_desc 闭合 } 之后），再插 gaoshi（在闭合 } 之前）。
    # 两处都不影响对方的索引（state 在 idc+1，gaoshi 在 idc）。
    lines[idc + 1 : idc + 1] = STATE_LINES
    lines[idc:idc] = GAOSHI_LINES
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))
    print("  写入 %s：+item_desc.gaoshi / +state{visitor=%d}" % (TARGET_ZONE, SEED_VISITOR))


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
    print("== P5-4q guangchang gaoshi_visitor backfill ==")
    print("模式: %s" % ("APPLY" if apply_flag else "dry-run"))
    p = plan()
    if p is None:
        print("无需改动。")
        return
    print("  计划：%s :: %s  (item_desc@%d, close@%d)" % (TARGET_ZONE, TARGET_STEM, p["item_desc_open"], p["item_desc_close"]))

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
        print("  OK：复跑确认 gaoshi_visitor 已存在（幂等 0 待改）。")
    else:
        print("  [WARN] 幂等检查未通过：复跑仍能处理。", file=sys.stderr)
        sys.exit(2)
    print("OK：city:guangchang 回填完毕。")


if __name__ == "__main__":
    main()
