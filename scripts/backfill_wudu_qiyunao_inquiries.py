#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4x backfill: 给 data/world/wudu.ucl 追加 characters "wudu_qiyunao" 块，
内含 3 门 ask_skill 的 inquiries perform_id 脚本 + 1 门 ask_me 的 give_item 配置。

对应 LPC kungfu/class/wudu/qiyunao.c 的 ask_skill1..ask_skill3 + ask_me：
  腾蛇诀 / 毒蟾掌 / 夺命连环（perform_id 脚本）  +  毒经中篇（give_item 发书）

映射至现有管道（无需新 handler）：
  ask_skill：inquiries map（无 kind）→ NpcAskEvent.handle_scripted_answer → npc/perform 事件
    → NpcScriptEvent.perform_result → SectMaster.inquiry_grant（门派/门槛/贡献/杀气校验）
    → Stats.learn_perform → 扣 gongxian
  ask_me：inquiries map（kind = "give_item"）→ NpcAskEvent.handle_scripted_answer → npc/inquiry 事件
    → InquiryHandlers.lookup("give_item") → GiveItem.run/3 → 发放 items.dujing2

config 键（字符串，loader.parse_inquiry_value 归一）：
  perform_id = "xiewei-bian/tengshe" 等（与 Stats.learn_perform 的 performs 键一致）
  skill = "xiewei-bian"               等（带连字符，与 Stats.skills 键一致）
  min_levels = { xiewei_bian = 100 }  （下划线→连字符，见 loader.normalize_inquiry_field）
  min_gongxian / min_shen / cost_gongxian = 整数
  kind = "give_item"                  （ask_me 走 give_item 处理器）
  item = "wudu:dujing2"               （items "dujing2"，见 wudu.ucl）
  match = "dujing2"                   （present(name, me) 匹配词）
  unique = true                       （玩家已持有时拒重发）
  family = "五毒教"                   （限门派）

注意 shen 方向：
  LPC ask_skill1/2/3 校验 `shen > -20000 / -35000 / -40000` 即拒（需要足够邪恶，shen <= 负阈值），
  而 SectMaster.inquiry_grant 管道检查 `shen < min_shen`（即 shen >= min_shen 才过），方向相反。
  因此本批 min_shen 暂置 0（不拦），并标注 TODO；后续如需严格还原可另设 max_shen 处理器。

携带物品：LPC carry_object("/d/wudu/npc/obj/jinyi")->wear() → wudu.ucl items "jinyi"。

门禁（与 G1-G8 一致）：dry-run → 备份 → 写盘(newline="") → validate_ucl → 幂等复跑 0 待改。

用法：
  python scripts/backfill_wudu_qiyunao_inquiries.py          # dry-run
  python scripts/backfill_wudu_qiyunao_inquiries.py --apply  # 真正写盘
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

TARGET_ZONE = "wudu.ucl"
TARGET_CHAR = "wudu_qiyunao"

# ---- UCL 内容：characters "wudu_qiyunao" { ... } ----
# 缩进风格：块名 4 空格，成员 6 空格，内嵌映射 8 空格。
# Elias UCL：块内成员以换行分隔，不得用逗号；行内仅用 key = value。
# Chinese bare keys 均可（Elias read_bare 接受非 ASCII 字符，见 wudang.zhang 先例）。
CHAR_BLOCK = """# Generated from C:/files/git/mud/kungfu/class/wudu/qiyunao.c by LPCConverter (manual backfill)
# 齐云敖 — 五毒教长老，人称锦衣毒丐。3 门绝招（ask_skill1..3）映射为 inquiries perform_id 脚本，
# 1 门 ask_me（毒经中篇）映射为 kind = "give_item" 发放 items.dujing2。
# ask_skill 无需新 handler：map（无 kind）→ npc/perform → SectMaster.inquiry_grant → Stats.learn_perform。
# ask_me 走现有 GiveItem：kind = "give_item" → InquiryHandlers.lookup("give_item") → GiveItem.run/3。
characters "%s" {
  name = "齐云敖"
  aliases = ["qi yunao", "qi", "yunao"]
  nickname = "锦衣毒丐"
  title = "五毒教长老"
  description = "他就是五毒教的长老，人称锦衣毒丐的齐云敖。乃是教主的同门师兄，在教中一向飞扬跋扈，大权独揽。他长的身材魁梧，面目狰狞，身穿一件五彩锦衣，太阳穴高高坟起。"
  gender = "男性"
  age = 45
  attitude = "friendly"
  shen_type = -1

  combat = {
    attitude = "friendly"
    str = 30
    int = 40
    con = 30
    dex = 30
    max_qi = 4500
    max_jing = 4000
    max_neili = 5000
    neili = 5000
    jiali = 120
    combat_exp = 1800000
    score = 10000
    skills = {
      force = 220
      wudu_xinfa = 220
      xiuluo_yinshagong = 180
      dodge = 180
      jinshe_youshenbu = 180
      strike = 200
      tianchan_zhang = 200
      claw = 200
      wusheng_zhao = 200
      parry = 200
      sword = 200
      jinwu_goufa = 180
      whip = 180
      xiewei_bian = 180
      ruanhong_zhusuo = 180
      throwing = 180
      literate = 100
      poison = 250
      wudu_qishu = 250
      martial_cognize = 200
    }
    map_skill = {
      force = "xiuluo-yinshagong"
      dodge = "jinshe-youshenbu"
      strike = "tianchan-zhang"
      claw = "wusheng-zhao"
      parry = "wusheng-zhao"
      sword = "jinwu-goufa"
      whip = "ruanhong-zhusuo"
      poison = "wudu-qishu"
    }
  }

  # 门派身份（供 inquiry_grant 同门校验，LPC create_family("五毒教", 11, "长老")）
  teach = {
    family = "五毒教"
  }

  # LPC no_teach = ([ "xiuluo-yinshagong" : ... , "ruanhong-zhusuo" : ... ])
  no_teach = ["xiuluo-yinshagong", "ruanhong-zhusuo"]

  # LPC set("shen_type", -1) 反派/邪派；详见 combat.shen_type
  shen_type = -1

  # 3 门 ask_skill 绝招 → inquiries perform_id 脚本。
  # TODO：LPC 校验 shen > -20000/-35000/-40000 即拒（需足够邪恶，shen <= 负阈值），
  #       而 inquiry_grant 管道检查 `shen < min_shen`（shen >= min_shen 才过），方向相反。
  #       本批 min_shen 暂置 0（不拦杀气），后续如需严格还原可另设 max_shen 处理器。
  inquiries = {
    腾蛇诀 = {
      perform_id = "xiewei-bian/tengshe"
      skill = "xiewei-bian"
      min_levels = {
        xiewei_bian = 100
      }
      min_gongxian = 100
      min_shen = 0
      cost_gongxian = 100
    }

    毒蟾掌 = {
      perform_id = "tianchan-zhang/chan"
      skill = "tianchan-zhang"
      min_levels = {
        tianchan_zhang = 120
        force = 150
      }
      min_gongxian = 200
      min_shen = 0
      cost_gongxian = 200
    }

    夺命连环 = {
      perform_id = "wusheng-zhao/lian"
      skill = "wusheng-zhao"
      min_levels = {
        wusheng_zhao = 120
        force = 150
      }
      min_gongxian = 300
      min_shen = 0
      cost_gongxian = 300
    }

    # LPC ask_me → 毒经中篇（/clone/lonely/book/dujing2），限五毒教，玩家已有时不重发。
    # kind = "give_item" 走现有 GiveItem 处理器（inquiry_handlers.ex），无需新 handler。
    毒经中篇 = {
      kind = "give_item"
      item = "wudu:dujing2"
      match = "dujing2"
      unique = true
      family = "五毒教"
      vision_name = "齐云敖"
      success = "你拿去看吧，若有不解之处可以来问我。"
      already = "不就是你拿着么？怎么反倒问我来了？"
      family_deny = "你是哪里来的？跑来跟我罗嗦什么！"
    }
  }

  # 随身装备（LPC carry_object("/d/wudu/npc/obj/jinyi")->wear()）
  carry = [
    { id = items.jinyi.id }
  ]
}""" % TARGET_CHAR


# ---- UCL 扫描工具 ----

def find_char_block_close(lines, start):
    """从 start 行起做括号深度扫描，返回深度回到 0 的那一行（不含 start 自身）。"""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        if depth <= 0 and j > start:
            return j
    return None


def find_char_block(text, char_name):
    """返回 (start, close) 行号（0-based）；找不到返回 None。

    匹配 `characters "wudu_qiyunao" {`（允许前导空白）。
    """
    lines = text.split("\n")
    re_open = re.compile(r'^\s*characters\s+"%s"\s*\{' % re.escape(char_name))
    for i, line in enumerate(lines):
        if re_open.match(line):
            close = find_char_block_close(lines, i)
            return (i, close)
    return None


def block_has_inquiries(text, start, close):
    """判断字符块内是否已有 inquiries = { ... }。"""
    lines = text.split("\n")
    seg = "\n".join(lines[start:close + 1])
    return bool(re.search(r'^\s*inquiries\s*=\s*\{', seg, re.MULTILINE))


def already_done(text):
    """True：wudu_qiyunao 块已存在且已有 inquiries。"""
    block = find_char_block(text, TARGET_CHAR)
    if block is None:
        return False
    start, close = block
    return block_has_inquiries(text, start, close)


def plan(text):
    """返回 dict：{exists: bool, has_inquiries: bool}；None 表示无需改动。"""
    if already_done(text):
        return None
    block = find_char_block(text, TARGET_CHAR)
    if block is None:
        return {"exists": False, "has_inquiries": False}
    start, close = block
    return {"exists": True, "has_inquiries": block_has_inquiries(text, start, close)}


def backup():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-wudu-qiyunao-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    src = os.path.join(DATA_WORLD, TARGET_ZONE)
    shutil.copy2(src, os.path.join(bdir, TARGET_ZONE))
    print("  备份 -> %s" % bdir)
    return bdir


def apply(plan_dict, text):
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    lines = text.split("\n")

    if not plan_dict["exists"]:
        # 追加到文件末尾
        if lines and lines[-1] == "":
            lines = lines[:-1]  # 去掉末尾空行
        lines.append("")
        lines.append(CHAR_BLOCK.rstrip("\n"))
        lines.append("")
    else:
        # 块已存在但无 inquiries：在块内追加 inquiries（定位到块的末尾 } 之前）
        start, close = find_char_block(text, TARGET_CHAR)
        # close 行是块的 }；在它之前插入 inquiries
        indent = "  "
        inquiries_lines = [
            "",
            "%sinquiries = {" % indent,
            '    腾蛇诀 = {',
            '      perform_id = "xiewei-bian/tengshe"',
            '      skill = "xiewei-bian"',
            '      min_levels = {',
            '        xiewei_bian = 100',
            '      }',
            '      min_gongxian = 100',
            '      min_shen = 0',
            '      cost_gongxian = 100',
            '    }',
            "  }",
        ]
        # 插入到 close 行之前
        lines[close:close] = inquiries_lines

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))

    if not plan_dict["exists"]:
        print("  写入 %s：+characters %s（含 3 门 inquiries perform_id + 1 门 give_item）"
              % (TARGET_ZONE, TARGET_CHAR))
    else:
        print("  写入 %s：+characters %s.inquiries" % (TARGET_ZONE, TARGET_CHAR))


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
    print("== P5-4x wudu_qiyunao ask_skill/ask_me inquiries backfill ==")
    print("模式: %s" % ("APPLY" if apply_flag else "dry-run"))

    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    p = plan(text)
    if p is None:
        print("无需改动：%s :: %s 已有 inquiries。" % (TARGET_ZONE, TARGET_CHAR))
        return

    if p["exists"]:
        print("  计划：%s :: %s 块已存在，将在其中追加 inquiries。" % (TARGET_ZONE, TARGET_CHAR))
    else:
        print("  计划：%s :: %s 块不存在，将在文末追加完整 characters 块。" % (TARGET_ZONE, TARGET_CHAR))
    print("    3 门 ask_skill → perform_id：腾蛇诀(xiewei-bian/tengshe) 毒蟾掌(tianchan-zhang/chan) 夺命连环(wusheng-zhao/lian)")
    print("    1 门 ask_me → give_item：毒经中篇(wudu:dujing2)")

    if not apply_flag:
        print("\n(dry-run 结束；加 --apply 真正写盘)")
        return

    backup()
    # 重读（备份不改文件，文本不变）
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    p = plan(text)
    apply(p, text)
    print("\n== 校验 ==")
    if not validate():
        print("VALIDATE 失败，请检查。", file=sys.stderr)
        sys.exit(1)
    print("\n== 幂等复跑 ==")
    with open(path, "r", encoding="utf-8") as f:
        text2 = f.read()
    if already_done(text2):
        print("  OK：复跑确认 inquiries 已存在（幂等 0 待改）。")
    else:
        print("  [WARN] 幂等检查未通过：复跑仍能处理。", file=sys.stderr)
        sys.exit(2)
    print("OK：%s :: %s 回填完毕。" % (TARGET_ZONE, TARGET_CHAR))


if __name__ == "__main__":
    main()
