#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4ad backfill: 给 data/world/city.ucl 的四间拱猪房接上完整动作表。

对应 LPC：
  inherit/room/pigroom.c  init() 里 add_action 了十个动词：
      sit / leave / deal / bid / sell / pass / play / refresh / skip / claim
  d/city/{eproom,nproom,sproom,wproom}.c  四间房共用（各自只有 short/long/exits）

本脚本对 rooms "eproom" / "nproom" / "sproom" / "wproom" 四块做三件事：

  1. item_desc 里补 `scoreboard = { kind = "pig_scoreboard" }`
     （LPC 的 `"scoreboard" : (: look_scoreboard :)`，成绩表 item_desc）
  2. 用 `actions = { ... }` 替换 P5-4r 遗留的 `state = { pig_phase/pig_north/... }`
     占位播种。牌局运行态现在存在 `state["pig_game"]`（由
     `RoomActions.City.PigRoom` 用 `Room.put_state_by_id/3` 写入），
     旧扁平键已无任何读取方（`grep pig_phase` 仅剩本文件与旧测试）。
  3. 补 `flags = ["no_fight"]`（LPC `set("no_fight", "1")`）

门禁（G1-G8）：dry-run → 备份 → 写盘(newline="") → validate_ucl → 幂等复跑 0 待改。

用法：
  python scripts/backfill_pig_room_actions.py          # dry-run
  python scripts/backfill_pig_room_actions.py --apply  # 真正写盘
"""
import os
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_WORLD = os.path.join(ROOT, "data", "world")
VALIDATE = os.path.join(ROOT, "scripts", "validate_ucl.py")

TARGET_ZONE = "city.ucl"
ROOM_IDS = ["eproom", "nproom", "sproom", "wproom"]

# ---- 1. item_desc：补 scoreboard ----
OLD_ITEM_DESC = """item_desc = {
 paper = "请务必读 help pig_cmds 和 help pig_rules。"
 table = {
   kind = "pig_table"
 }
}"""

NEW_ITEM_DESC = """item_desc = {
 paper = "请务必读 help pig_cmds 和 help pig_rules。"
 table = {
   kind = "pig_table"
 }
 scoreboard = {
   kind = "pig_scoreboard"
 }
}"""

# ---- 2/3. 旧 state 占位 → actions + flags ----
OLD_STATE = """ state = {
  pig_phase = "initting"
  pig_north = ""
  pig_west = ""
  pig_south = ""
  pig_east = ""
  pig_server = ""
 }"""

NEW_ACTIONS = """  actions = {
    sit = "do_sit"
    leave = "do_leave"
    deal = "do_deal"
    bid = "do_bid"
    sell = "do_bid"
    pass = "do_pass"
    play = "do_play"
    refresh = "do_refresh"
    skip = "do_skip"
    claim = "do_claim"
  }
  flags = [
    "no_fight"
  ]"""


def already_done(text):
    """三件事都做完才算完成（幂等判据）。

    注意别用 `sit = "do_sit"` 计数：城里另有 3 间房（茶馆/客栈之类）本来就有
    同名 action，会让计数虚高。`claim = "do_claim"` 只有拱猪房有。
    """
    return (
        text.count('kind = "pig_scoreboard"') == len(ROOM_IDS)
        and text.count('claim = "do_claim"') == len(ROOM_IDS)
        and text.count('pig_phase = "initting"') == 0
    )


def plan(text):
    if already_done(text):
        return None

    return {
        "item_desc": text.count(OLD_ITEM_DESC),
        "state": text.count(OLD_STATE),
    }


def apply(text):
    new = text.replace(OLD_ITEM_DESC, NEW_ITEM_DESC)
    new = new.replace(OLD_STATE, NEW_ACTIONS)
    return new


def backup():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-pig-rooms-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    src = os.path.join(DATA_WORLD, TARGET_ZONE)
    shutil.copy2(src, os.path.join(bdir, TARGET_ZONE))
    print("  备份 -> %s" % bdir)
    return bdir


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
    print("== P5-4ad 拱猪四房 actions / scoreboard / no_fight 回填 ==")
    print("模式: %s" % ("APPLY" if apply_flag else "dry-run"))

    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    p = plan(text)
    if p is None:
        print("无需改动：%s 四间拱猪房均已接线（幂等 0 待改）。" % TARGET_ZONE)
        return

    print("  计划：")
    print("    item_desc 补 scoreboard      : %d 处（期望 %d）" % (p["item_desc"], len(ROOM_IDS)))
    print("    旧 state 占位 → actions+flags: %d 处（期望 %d）" % (p["state"], len(ROOM_IDS)))

    if p["item_desc"] != len(ROOM_IDS) or p["state"] != len(ROOM_IDS):
        print("  [ABORT] 命中数与四间房不符，可能数据已被改动，请人工核对。", file=sys.stderr)
        sys.exit(3)

    if not apply_flag:
        print("\n(dry-run 结束；加 --apply 真正写盘)")
        return

    backup()
    new = apply(text)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(new)
    print("  写入 %s：四间拱猪房 + actions(10 动词) + scoreboard + no_fight" % TARGET_ZONE)

    print("\n== 校验 ==")
    if not validate():
        print("VALIDATE 失败，请检查。", file=sys.stderr)
        sys.exit(1)

    print("\n== 幂等复跑 ==")
    with open(path, "r", encoding="utf-8") as f:
        text2 = f.read()
    if already_done(text2):
        print("  OK：复跑确认已完成（幂等 0 待改）。")
    else:
        print("  [WARN] 幂等检查未通过：复跑仍能处理。", file=sys.stderr)
        sys.exit(2)
    print("OK：%s 拱猪四房接线完毕。" % TARGET_ZONE)


if __name__ == "__main__":
    main()
