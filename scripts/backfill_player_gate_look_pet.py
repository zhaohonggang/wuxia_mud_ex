#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4m：回填 xiyu:houdong 的 `look_pet`（星宿派后洞石桌五毒）。

LPC 源（xiyu/houdong.c look_pet）：
    if (me->query("family/family_name") != "星宿派" ||
        me->query_skill("xingxiu-qishu", 1) < 160)
        return "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。\n";
    return "上面刻有金蜈蚣，黑寡妇，赤蝎子，千年灵蛇，花斑毒蟾。你心中一惊：“难道这便是五圣剧毒？”\n";

映射为 kind="player_skill"（P5-4m 已扩展 family 门控）：
    item_desc = {
      pet = {
        kind = "player_skill"
        family = "星宿派"
        skill = "xingxiu-qishu"
        min_level = 160
        has_text = "门派弟子才看得到的五圣剧毒"
        no_text = "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。"
      }
    }

门禁（G 系列，与 P5-4c/k/l 一致）：
  G1  dry-run 先打印计划，不落盘
  G2  --apply 前备份到 tmp/backup-playergate-<ts>/
  G3  仅新增 item_desc.pet，不删不改既有行
  G4  幂等：pet 已存在则跳过（复跑 0 待改）
  G5  落盘后用 validate_ucl 复核（调用 scripts/validate_ucl.py）

用法：
  python3 scripts/backfill_player_gate_look_pet.py            # dry-run
  python3 scripts/backfill_player_gate_look_pet.py --apply    # 写入
"""
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
UCL = os.path.join(ROOT, "data", "world", "xiyu.ucl")
VALIDATE = os.path.join(SCRIPT_DIR, "validate_ucl.py")

ROOM = "houdong"
ZONE = "xiyu"

# 颜色码已剥离；\n 折叠为单行，handler 末尾统一补 \n（故此处不含尾换行）。
HAS_TEXT = '上面刻有金蜈蚣，黑寡妇，赤蝎子，千年灵蛇，花斑毒蟾。你心中一惊：“难道这便是五圣剧毒？”'
NO_TEXT = '上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。'

INSERT_BLOCK = (
    '  item_desc = {\n'
    '    pet = {\n'
    '      kind = "player_skill"\n'
    '      family = "星宿派"\n'
    '      skill = "xingxiu-qishu"\n'
    '      min_level = 160\n'
    '      has_text = "%s"\n' % HAS_TEXT +
    '      no_text = "%s"\n' % NO_TEXT +
    '    }\n'
    '  }\n'
)


def find_room_block(text, room):
    marker = '    rooms "%s" {' % room
    start = text.find(marker)
    if start < 0:
        return None, None
    open_brace = text.index('{', start)
    depth = 0
    i = open_brace
    while i < len(text):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return start, i  # [start, close_brace]
        i += 1
    return start, None


def already_done(text, start, close_brace):
    block = text[start:close_brace + 1]
    return 'pet = {' in block


def apply_backfill(apply):
    with open(UCL, "r", encoding="utf-8", newline="") as fh:
        text = fh.read()

    start, close_brace = find_room_block(text, ROOM)
    if start is None:
        print("ERROR: 找不到 rooms \"%s\" 块" % ROOM)
        sys.exit(1)
    if close_brace is None:
        print("ERROR: 无法定位 %s 房间闭合括号" % ROOM)
        sys.exit(1)

    if already_done(text, start, close_brace):
        print("幂等：%s:%s 的 item_desc.pet 已存在，跳过。" % (ZONE, ROOM))
        return False

    new_text = text[:close_brace] + INSERT_BLOCK + text[close_brace:]

    if not apply:
        print("DRY-RUN：将在 %s:%s 房间闭合前插入 item_desc.pet：" % (ZONE, ROOM))
        print("----")
        print(INSERT_BLOCK.rstrip("\n"))
        print("----")
        print("待改文件：%s" % UCL)
        return True

    # G2 备份
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = os.path.join(SCRIPT_DIR, "tmp", "backup-playergate-%s" % ts)
    os.makedirs(os.path.dirname(backup_dir), exist_ok=True)
    shutil.copy2(UCL, backup_dir)
    print("备份 → %s" % backup_dir)

    with open(UCL, "w", encoding="utf-8", newline="") as fh:
        fh.write(new_text)
    print("已写入 %s:%s 的 item_desc.pet" % (ZONE, ROOM))

    # G5 validate_ucl
    if os.path.exists(VALIDATE):
        rc = subprocess.run(
            ["python3", VALIDATE, UCL], capture_output=True, text=True
        )
        print("--- validate_ucl %s ---" % os.path.basename(UCL))
        out = (rc.stdout + rc.stderr).strip()
        print(out if out else "(无输出)")
        if rc.returncode != 0:
            print("WARNING: validate_ucl 返回非零，请人工复核。")
    return True


def main():
    apply = "--apply" in sys.argv[1:]
    changed = apply_backfill(apply)
    if changed and not apply:
        print("\n（dry-run 未落盘；加 --apply 执行写入 + 备份 + validate_ucl）")


if __name__ == "__main__":
    main()
