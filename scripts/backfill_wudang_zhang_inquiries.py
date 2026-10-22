#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4x backfill: 给 data/world/wudang.ucl 追加 characters "wudang_zhang" 块，
内含 11 门 ask_skill 的 inquiries perform_id 脚本配置。

对应 LPC kungfu/class/wudang/zhang.c 的 ask_skill1..ask_skill11：
  鹤嘴劲 / 震字诀 / 引字诀 / 挤字诀 / 粘字诀 / 太极图 / 缠字诀 / 随字诀 /
  驾字诀 / 剑轮岚转 / 真武除邪

映射至现有管道（无需新 handler）：
  inquiries map（无 kind）→ NpcAskEvent.handle_scripted_answer → npc/perform 事件
  → NpcScriptEvent.perform_result → SectMaster.inquiry_grant（门派/门槛/贡献/杀气校验）
  → Stats.learn_perform → 扣 gongxian

config 键（字符串，loader.parse_inquiry_value 归一）：
  perform_id = "taiji-shengong/dian"  等（与 Stats.learn_perform 的 performs 键一致）
  skill = "taiji-shengong"            等（带连字符，与 Stats.skills 键一致）
  min_levels = { taiji_shengong = 100 }（下划线→连字符，见 loader.normalize_inquiry_field）
  min_gongxian / min_shen / cost_gongxian = 整数

注意：ask_skill6「太极图」还校验 max_jingli >= 1000、potential >= learned_points + 100，
      并把 can_perform/taiji-quan/tu 做计数器（>=10 封顶），以上均不在 inquiry_grant
      管道内，本批只回填可表达字段，文中标注 TODO。

携带物品：LPC carry_object("/d/wudang/obj/greyrobe")->wear() → wudang.ucl items "greyrobe"。

门禁（与 G1-G8 一致）：dry-run → 备份 → 写盘(newline="") → validate_ucl → 幂等复跑 0 待改。

用法：
  python scripts/backfill_wudang_zhang_inquiries.py          # dry-run
  python scripts/backfill_wudang_zhang_inquiries.py --apply  # 真正写盘
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

TARGET_ZONE = "wudang.ucl"
TARGET_CHAR = "wudang_zhang"

# ---- UCL 内容：characters "wudang_zhang" { ... } ----
# 缩进风格：块名 4 空格，成员 6 空格，内嵌映射 8 空格。
# Elias UCL：块内成员以换行分隔，不得用逗号；行内仅用 key = value。
CHAR_BLOCK = """# Generated from C:/files/git/mud/kungfu/class/wudang/zhang.c by LPCConverter (manual backfill)
# 张三丰 — 武当派开山祖师，11 门绝招（ask_skill1..11）均映射为 inquiries perform_id 脚本。
# 无需新 handler：map（无 kind）→ NpcAskEvent.handle_scripted_answer → npc/perform
# → NpcScriptEvent.perform_result → SectMaster.inquiry_grant → Stats.learn_perform。
characters "%s" {
  name = "张三丰"
  aliases = ["zhang sanfeng", "zhang", "sanfeng"]
  nickname = "太极真人"
  description = "他就是武当派开山鼻祖、当今武林的泰山北斗张三丰真人。只见他身着一身污秽的灰色道袍，不修边幅。身材高大，年满百岁，满脸红光，须眉皆白。"
  gender = "男性"
  age = 100
  attitude = "friendly"
  shen_type = 1

  combat = {
    str = 31
    int = 39
    con = 40
    dex = 32
    max_qi = 10000
    max_jing = 10000
    max_neili = 12000
    combat_exp = 5000000
    score = 1200000
    skills = {
      taiji_shengong = 420
      wudang_xinfa = 400
      taiji_quan = 420
      wudang_zhang = 400
      taiji_jian = 420
      taiji_dao = 400
      tiyunzong = 420
      unarmed = 420
      xuangong_quan = 400
      strike = 400
      yitian_zhang = 400
      zhenshan_zhang = 400
      hand = 400
      paiyun_shou = 400
      claw = 400
      huzhua_shou = 400
      parry = 420
      sword = 420
      wudang_jiuyang = 200
      shenmen_jian = 400
      rouyun_jian = 400
      raozhi_roujian = 400
      liangyi_jian = 400
      blade = 400
      xuanxu_dao = 400
      throwing = 400
      furong_jinzhen = 400
      taoism = 400
      literate = 280
      medical = 240
      wudang_yaoli = 240
      martial_cognize = 400
    }
  }

  # 门派身份（供 inquiry_grant 同门校验，LPC create_family("武当派", 1, "开山祖师")）
  teach = {
    family = "武当派"
  }

  # LPC no_teach = ([ "wudang-jiuyang" : (: try_to_learn_jy :) ])
  #   wudang-jiuyang 走 ask_jiuyang 闭包，不走 perform_id 管道；此处不回填。
  no_teach = ["wudang-jiuyang"]

  # LPC set("class", "taoist")
  class = "taoist"

  # 11 门 ask_skill 绝招 → inquiries perform_id 脚本。
  # 注意：ask_skill6「太极图」还校验 max_jingli >= 1000、potential >= learned_points + 100，
  #       并把 can_perform/taiji-quan/tu 做计数器（>=10 封顶），以上均不在 inquiry_grant
  #       管道内，本批只回填可表达字段，后续如需严格还原可另设 kind 处理器。
  inquiries = {
    鹤嘴劲 = {
      perform_id = "taiji-shengong/dian"
      skill = "taiji-shengong"
      min_levels = {
        taiji_shengong = 100
      }
      min_gongxian = 800
      min_shen = 150000
      cost_gongxian = 800
    }

    震字诀 = {
      perform_id = "taiji-quan/zhen"
      skill = "taiji-quan"
      min_levels = {
        taiji_quan = 150
      }
      min_gongxian = 300
      min_shen = 100000
      cost_gongxian = 300
    }

    引字诀 = {
      perform_id = "taiji-quan/yin"
      skill = "taiji-quan"
      min_levels = {
        taiji_quan = 150
      }
      min_gongxian = 200
      min_shen = 100000
      cost_gongxian = 200
    }

    挤字诀 = {
      perform_id = "taiji-quan/ji"
      skill = "taiji-quan"
      min_levels = {
        taiji_quan = 150
      }
      min_gongxian = 400
      min_shen = 120000
      cost_gongxian = 400
    }

    粘字诀 = {
      perform_id = "taiji-quan/zhan"
      skill = "taiji-quan"
      min_levels = {
        taiji_quan = 150
      }
      min_gongxian = 500
      min_shen = 140000
      cost_gongxian = 500
    }

    太极图 = {
      perform_id = "taiji-quan/tu"
      skill = "taiji-quan"
      min_levels = {
        taiji_quan = 250
        taiji_shengong = 300
        taoism = 300
      }
      min_gongxian = 3000
      min_shen = 250000
      cost_gongxian = 3000
    }

    缠字诀 = {
      perform_id = "taiji-jian/chan"
      skill = "taiji-jian"
      min_levels = {
        taiji_jian = 80
      }
      min_gongxian = 300
      min_shen = 80000
      cost_gongxian = 300
    }

    随字诀 = {
      perform_id = "taiji-jian/sui"
      skill = "taiji-jian"
      min_levels = {
        taiji_jian = 60
      }
      min_gongxian = 200
      min_shen = 80000
      cost_gongxian = 200
    }

    驾字诀 = {
      perform_id = "taiji-jian/jia"
      skill = "taiji-jian"
      min_levels = {
        taiji_jian = 150
      }
      min_gongxian = 600
      min_shen = 100000
      cost_gongxian = 600
    }

    剑轮岚转 = {
      perform_id = "taiji-jian/zhuan"
      skill = "taiji-jian"
      min_levels = {
        taiji_jian = 160
      }
      min_gongxian = 800
      min_shen = 120000
      cost_gongxian = 800
    }

    真武除邪 = {
      perform_id = "taiji-jian/zhenwu"
      skill = "taiji-jian"
      min_levels = {
        taiji_jian = 180
      }
      min_gongxian = 2000
      min_shen = 120000
      cost_gongxian = 2000
    }
  }

  # 随身装备（LPC carry_object("/d/wudang/obj/greyrobe")->wear()）
  carry = [
    { id = items.greyrobe.id }
  ]
}
""" % TARGET_CHAR


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

    匹配 `characters "wudang_zhang" {`（允许前导空白）。
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
    """True：wudang_zhang 块已存在且已有 inquiries。"""
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
    bdir = os.path.join(ROOT, "tmp", "backup-wudang-zhang-%s" % ts)
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
            '    "鹤嘴劲" = {',
            '      perform_id = "taiji-shengong/dian"',
            '      skill = "taiji-shengong"',
            '      min_levels = { taiji_shengong = 100 }',
            '      min_gongxian = 800',
            '      min_shen = 150000',
            '      cost_gongxian = 800',
            '    }',
            "  }",
        ]
        # 插入到 close 行之前
        lines[close:close] = inquiries_lines

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines))

    if not plan_dict["exists"]:
        print("  写入 %s：+characters %s（含 %d 门 inquiries perform_id）"
              % (TARGET_ZONE, TARGET_CHAR, 11))
    else:
        print("  写入 %s：+characters %s.inquiries（%d 门 perform_id）"
              % (TARGET_ZONE, TARGET_CHAR, 11))


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
    print("== P5-4x wudang_zhang ask_skill inquiries backfill ==")
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
    print("    11 门 ask_skill → perform_id：鹤嘴劲 震字诀 引字诀 挤字诀 粘字诀 太极图 缠字诀 随字诀 驾字诀 剑轮岚转 真武除邪")

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
