#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4x backfill: 给 data/world/wudang.ucl 追加 6 个 ask_me NPC 的 characters 块，
内含 4 门 ask_skill 的 inquiries perform_id 脚本 + 2 门 ask_me 的 give_item 配置。

对应 LPC kungfu/class/wudang/{guxu,qingxu,shan,xi,yin,yu}.c 的 ask_me：

  谷虚道长   (wudang_guxu)   问"道德经" → give_item clone_lib:daodejing_i   (上卷，限武当派，unique)
  清虚道长   (wudang_qingxu) 问"道德经" → give_item clone_lib:daodejing_ii  (下卷，限武当派，unique)
  张翠山     (wudang_shan)    问"谁与争锋" → perform_id yitian-zhang/zheng
  张松溪     (wudang_xi)      问"乱环诀"   → perform_id xuanxu-dao/huan
  殷梨亭     (wudang_yin)     问"柔月穿空" → perform_id raozhi-roujian/chuankong
  俞莲舟     (wudang_yu)      问"绝户神抓" → perform_id huzhua-shou/juehu

映射至现有管道（无需新 handler）：
  ask_skill：inquiries map（无 kind）→ NpcAskEvent.handle_scripted_answer → npc/perform 事件
    → NpcScriptEvent.perform_result → SectMaster.inquiry_grant（门派/门槛/贡献/杀气校验）
    → Stats.learn_perform → 扣 gongxian
  ask_me：inquiries map（kind = "give_item"）→ NpcAskEvent.handle_scripted_answer → npc/inquiry 事件
    → InquiryHandlers.lookup("give_item") → GiveItem.run/3 → 发放 clone_lib 书册

config 键（字符串，loader.parse_inquiry_value 归一）：
  perform_id = "yitian-zhang/zheng" 等（与 Stats.learn_perform 的 performs 键一致）
  skill = "yitian-zhang"             等（带连字符，与 Stats.skills 键一致）
  min_levels = { yitian_zhang = 120 }（下划线→连字符，见 loader.normalize_inquiry_field）
  min_gongxian / min_shen / cost_gongxian = 整数
  kind = "give_item"                 （ask_me 走 give_item 处理器）
  item = "clone_lib:daodejing_i"     （clone_lib 标准库物品，见 clone_lib.ucl）
  match = "daodejing_i"              （present(name, me) 匹配词；缺省取 item_id 尾段）
  unique = true                      （玩家已持有时拒重发）
  family = "武当派"                    （限门派）

shen 方向：
  武当派为正派（shen_type = 1），LPC ask_me 校验 shen >= 正阈值（足够正派），
  与 inquiry_grant 管道的 shen >= min_shen 方向一致，因此直接填 LPC 阈值。

携带物品：
  guxu   : greenrobe (/d/wudang/obj/greenrobe) → items.greenrobe.id
  qingxu :（LPC 仅 changjian /clone/weapon/changjian，clone_lib 物品，此处不回填 carry）
  shan/xi/yin/yu : whiterobe (/d/wudang/obj/whiterobe) → items.whiterobe.id

门禁（与 G1-G8 一致）：dry-run → 备份 → 写盘(newline="") → validate_ucl → 幂等复跑 0 待改。

用法：
  python scripts/backfill_wudang_ask_me_inquiries.py          # dry-run
  python scripts/backfill_wudang_ask_me_inquiries.py --apply  # 真正写盘
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

# ---- 6 个 NPC 的定义 ----
# 缩进风格：块名 0 空格（顶级），成员 2 空格，内嵌映射 4 空格，再内嵌 6 空格。
# Elias UCL：块内成员以换行分隔，不得用逗号；行内仅用 key = value。
# Chinese bare keys 均可（Elias read_bare 接受非 ASCII 字符，见 wudang.zhang 先例）。

NPCS = [
    {
        "id": "wudang_guxu",
        "name": "谷虚道长",
        "aliases": ["guxu daozhang", "guxu", "daozhang"],
        "nickname": None,
        "description": "他就是俞莲舟的弟子谷虚道长。他今年四十岁，主管武当派的俗事。",
        "gender": "男性",
        "age": 40,
        "attitude": "peaceful",
        "shen_type": 1,
        "combat_stats": {
            "str": 22, "int": 25, "con": 26, "dex": 23,
            "max_qi": 3000, "max_jing": 1800, "max_neili": 3200,
            "neili": 3200, "jiali": 50, "combat_exp": 500000, "score": 30000,
        },
        "combat_skills": {
            "force": 120, "wudang_xinfa": 120, "dodge": 100, "tiyunzong": 100,
            "strike": 120, "wudang_zhang": 120, "parry": 120, "sword": 100,
            "wudang_jian": 100, "taoism": 120, "literate": 100, "martial_cognize": 100,
        },
        "map_skill": {
            "force": "wudang-xinfa", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "wudang-jian", "sword": "wudang-jian", "strike": "wudang-zhang",
        },
        "family": "武当派",
        "no_teach": [],
        "class_val": "taoist",
        "carry": ['{ id = items.greenrobe.id }'],
        # ask_me → 道德经（上卷），give_item
        "inquiries": """    道德经 = {
      kind = "give_item"
      item = "clone_lib:daodejing_i"
      match = "daodejing_i"
      unique = true
      family = "武当派"
      vision_name = "谷虚道长"
      success = "好吧，这本「道德经」你拿回去好好钻研。"
      already = "你不是已经拿着道德经「上卷」了吗？"
      family_deny = "与本派素无来往，不知此话从何谈起？"
    }""",
    },
    {
        "id": "wudang_qingxu",
        "name": "清虚道长",
        "aliases": ["qingxu daozhang", "qingxu"],
        "nickname": None,
        "description": "他就是俞莲舟的弟子清虚道长。他今年二十多岁，主管复真观的杂事。专门在这里看守本派的各种道经。",
        "gender": "男性",
        "age": 40,
        "attitude": "peaceful",
        "shen_type": 1,
        "combat_stats": {
            "str": 22, "int": 22, "con": 22, "dex": 22,
            "max_qi": 1800, "max_jing": 1000, "max_neili": 1500,
            "neili": 1500, "jiali": 30, "combat_exp": 300000, "score": 10000,
        },
        "combat_skills": {
            "force": 100, "wudang_xinfa": 100, "dodge": 80, "tiyunzong": 80,
            "strike": 100, "wudang_zhang": 100, "parry": 80, "sword": 80,
            "wudang_jian": 80, "taoism": 100, "literate": 80, "martial_cognize": 60,
        },
        "map_skill": {
            "force": "wudang-xinfa", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "wudang-jian", "sword": "wudang-jian", "strike": "wudang-zhang",
        },
        "family": "武当派",
        "no_teach": [],
        "class_val": "taoist",
        "carry": [],
        # ask_me → 道德经（下卷），give_item
        "inquiries": """    道德经 = {
      kind = "give_item"
      item = "clone_lib:daodejing_ii"
      match = "daodejing_ii"
      unique = true
      family = "武当派"
      vision_name = "清虚道长"
      success = "好吧，这本「道德经」你拿回去好好钻研。"
      already = "你不是已经拿着道德经「下卷」了吗？"
      family_deny = "与本派素无来往，不知此话从何谈起？"
    }""",
    },
    {
        "id": "wudang_shan",
        "name": "张翠山",
        "aliases": ["zhang cuishan", "zhang", "cuishan"],
        "nickname": "武当五侠",
        "description": "他就是张三丰的五弟子、武当七侠之中的张翠山。身穿一件干干净净的白色道袍。",
        "gender": "男性",
        "age": 31,
        "attitude": "peaceful",
        "shen_type": 1,
        "combat_stats": {
            "str": 28, "int": 35, "con": 28, "dex": 28,
            "max_qi": 5000, "max_jing": 5000, "max_neili": 4500,
            "neili": 4500, "jiali": 150, "combat_exp": 1400000, "score": 60000,
        },
        "combat_skills": {
            "force": 220, "wudang_xinfa": 220, "taiji_shengong": 200,
            "dodge": 220, "tiyunzong": 220, "unarmed": 200, "taiji_quan": 180,
            "strike": 220, "yitian_zhang": 220, "wudang_zhang": 200, "hand": 200,
            "paiyun_shou": 200, "parry": 200, "sword": 220, "wudang_jian": 220,
            "taiji_jian": 200, "taoism": 200, "literate": 180, "martial_cognize": 200,
        },
        "map_skill": {
            "force": "taiji-shengong", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "taiji-quan", "sword": "taiji-jian", "strike": "yitian-zhang",
        },
        "family": "武当派",
        "no_teach": ["taiji-shengong", "taiji-jian", "taiji-quan"],
        "class_val": None,
        "carry": ['{ id = items.whiterobe.id }'],
        # ask_me → 谁与争锋，perform_id yitian-zhang/zheng
        "inquiries": """    谁与争锋 = {
      perform_id = "yitian-zhang/zheng"
      skill = "yitian-zhang"
      min_levels = {
        yitian_zhang = 120
      }
      min_gongxian = 200
      min_shen = 12000
      cost_gongxian = 200
    }""",
    },
    {
        "id": "wudang_xi",
        "name": "张松溪",
        "aliases": ["zhang songxi", "zhang", "songxi"],
        "nickname": "武当四侠",
        "description": "他就是张三丰的四弟子张松溪。他今年四十岁，精明能干，以足智多谋著称。",
        "gender": "男性",
        "age": 40,
        "attitude": "peaceful",
        "shen_type": 1,
        "combat_stats": {
            "str": 26, "int": 33, "con": 26, "dex": 28,
            "max_qi": 5000, "max_jing": 5000, "max_neili": 4500,
            "neili": 4500, "jiali": 150, "combat_exp": 1400000, "score": 60000,
        },
        "combat_skills": {
            "force": 220, "wudang_xinfa": 220, "taiji_shengong": 200,
            "dodge": 220, "tiyunzong": 220, "unarmed": 200, "taiji_quan": 180,
            "strike": 200, "wudang_zhang": 200, "hand": 200, "paiyun_shou": 200,
            "parry": 200, "sword": 200, "wudang_jian": 200, "blade": 220,
            "xuanxu_dao": 220, "taiji_jian": 180, "taoism": 220, "literate": 160,
            "martial_cognize": 200,
        },
        "map_skill": {
            "force": "taiji-shengong", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "xuanxu-dao", "sword": "wudang-jian", "blade": "xuanxu-dao",
            "strike": "wudang-zhang",
        },
        "family": "武当派",
        "no_teach": ["taiji-shengong", "taiji-jian", "taiji-quan"],
        "class_val": None,
        "carry": ['{ id = items.whiterobe.id }'],
        # ask_me → 乱环诀，perform_id xuanxu-dao/huan
        "inquiries": """    乱环诀 = {
      perform_id = "xuanxu-dao/huan"
      skill = "xuanxu-dao"
      min_levels = {
        xuanxu_dao = 100
      }
      min_gongxian = 150
      min_shen = 10000
      cost_gongxian = 150
    }""",
    },
    {
        "id": "wudang_yin",
        "name": "殷梨亭",
        "aliases": ["yin liting", "yin", "liting"],
        "nickname": "武当六侠",
        "description": "他就是张三丰的六弟子殷梨亭。他今年三十岁，精明能干，嫉恶如仇，性如烈火。",
        "gender": "男性",
        "age": 30,
        "attitude": "heroism",
        "shen_type": 1,
        "combat_stats": {
            "str": 26, "int": 30, "con": 26, "dex": 28,
            "max_qi": 4000, "max_jing": 2000, "max_neili": 4200,
            "neili": 4200, "jiali": 100, "combat_exp": 1000000, "score": 100000,
        },
        "combat_skills": {
            "force": 180, "wudang_xinfa": 180, "taiji_shengong": 160,
            "dodge": 180, "tiyunzong": 180, "unarmed": 180, "taiji_quan": 160,
            "strike": 180, "wudang_zhang": 180, "hand": 180, "paiyun_shou": 180,
            "parry": 180, "sword": 180, "wudang_jian": 180, "raozhi_roujian": 180,
            "taiji_jian": 180, "taoism": 180, "literate": 160, "martial_cognize": 180,
        },
        "map_skill": {
            "force": "wudang-xinfa", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "wudang-jian", "sword": "raozhi-roujian", "strike": "wudang-zhang",
        },
        "family": "武当派",
        "no_teach": ["taiji-shengong", "taiji-jian", "taiji-quan"],
        "class_val": None,
        "carry": ['{ id = items.whiterobe.id }'],
        # ask_me → 柔月穿空，perform_id raozhi-roujian/chuankong
        "inquiries": """    柔月穿空 = {
      perform_id = "raozhi-roujian/chuankong"
      skill = "raozhi-roujian"
      min_levels = {
        raozhi_roujian = 100
        force = 150
      }
      min_gongxian = 250
      min_shen = 15000
      cost_gongxian = 250
    }""",
    },
    {
        "id": "wudang_yu",
        "name": "俞莲舟",
        "aliases": ["yu lianzhou", "yu", "lianzhou"],
        "nickname": "武当二侠",
        "description": "他就是张三丰的二弟子俞莲舟。他今年五十岁，身材魁梧，气度凝重。虽在武当七侠中排名第二，功夫却是最精。",
        "gender": "男性",
        "age": 50,
        "attitude": "peaceful",
        "shen_type": 1,
        "combat_stats": {
            "str": 30, "int": 30, "con": 32, "dex": 32,
            "max_qi": 5800, "max_jing": 4600, "max_neili": 6500,
            "neili": 6500, "jiali": 200, "combat_exp": 1800000, "score": 100000,
        },
        "combat_skills": {
            "force": 250, "wudang_xinfa": 250, "taiji_shengong": 240,
            "dodge": 240, "tiyunzong": 240, "unarmed": 240, "taiji_quan": 220,
            "claw": 250, "huzhua_shou": 250, "strike": 240, "wudang_zhang": 240,
            "zhenshan_zhang": 240, "hand": 240, "paiyun_shou": 240, "parry": 240,
            "sword": 250, "wudang_jian": 250, "taiji_jian": 240, "taoism": 230,
            "literate": 200, "medical": 180, "wudang_yaoli": 180, "martial_cognize": 240,
        },
        "map_skill": {
            "force": "taiji-shengong", "dodge": "tiyunzong", "unarmed": "taiji-quan",
            "parry": "taiji-quan", "sword": "taiji-jian", "strike": "zhenshan-zhang",
            "hand": "paiyun-shou", "claw": "huzhua-shou", "medical": "wudang-yaoli",
        },
        "family": "武当派",
        "no_teach": ["taiji-shengong", "taiji-jian", "taiji-quan"],
        "class_val": None,
        "carry": ['{ id = items.whiterobe.id }'],
        # ask_me → 绝户神抓，perform_id huzhua-shou/juehu
        "inquiries": """    绝户神抓 = {
      perform_id = "huzhua-shou/juehu"
      skill = "huzhua-shou"
      min_levels = {
        huzhua_shou = 120
        force = 180
      }
      min_gongxian = 400
      min_shen = 100000
      cost_gongxian = 400
    }""",
    },
]

TARGET_CHARS = [npc["id"] for npc in NPCS]


# ---- UCL 块生成 ----

def build_char_block(npc):
    """为单个 NPC 生成完整的 characters 块文本。"""
    lines = []
    src_name = npc["id"].replace("wudang_", "")
    is_give_item = "kind" in npc["inquiries"]
    lines.append('# Generated from C:/files/git/mud/kungfu/class/wudang/%s.c by LPCConverter (manual backfill)' % src_name)
    lines.append('# %s — 武当派 ask_me NPC，%s' % (npc["name"], "give_item 发书" if is_give_item else "perform_id 绝招"))
    lines.append('characters "%s" {' % npc["id"])
    lines.append('  name = "%s"' % npc["name"])
    lines.append('  aliases = [%s]' % ', '.join('"%s"' % a for a in npc["aliases"]))
    if npc["nickname"]:
        lines.append('  nickname = "%s"' % npc["nickname"])
    lines.append('  description = "%s"' % npc["description"])
    lines.append('  gender = "%s"' % npc["gender"])
    lines.append('  age = %d' % npc["age"])
    lines.append('  attitude = "%s"' % npc["attitude"])
    lines.append('  shen_type = %d' % npc["shen_type"])
    lines.append('')
    lines.append('  combat = {')
    for key, val in npc["combat_stats"].items():
        lines.append('    %s = %s' % (key, val))
    lines.append('    skills = {')
    for key, val in npc["combat_skills"].items():
        lines.append('      %s = %s' % (key, val))
    lines.append('    }')
    lines.append('    map_skill = {')
    for key, val in npc["map_skill"].items():
        lines.append('      %s = "%s"' % (key, val))
    lines.append('    }')
    lines.append('  }')
    lines.append('')
    lines.append('  # 门派身份（供 inquiry_grant 同门校验，LPC create_family("武当派", N, "弟子/侠")）')
    lines.append('  teach = {')
    lines.append('    family = "%s"' % npc["family"])
    lines.append('  }')
    if npc["no_teach"]:
        lines.append('')
        lines.append('  # LPC no_teach = ([ ... ]) —— 太极神功/太极剑/太极拳须张真人亲传，此处不回填。')
        lines.append('  no_teach = [%s]' % ', '.join('"%s"' % s for s in npc["no_teach"]))
    if npc["class_val"]:
        lines.append('')
        lines.append('  # LPC set("class", "taoist")')
        lines.append('  class = "%s"' % npc["class_val"])
    lines.append('')
    lines.append('  # ask_me 绝招 → inquiries 脚本。')
    lines.append('  inquiries = {')
    lines.append(npc["inquiries"])
    lines.append('  }')
    lines.append('')
    if npc["carry"]:
        lines.append('  # 随身装备（LPC carry_object(...)->wear()）')
        lines.append('  carry = [')
        for item in npc["carry"]:
            lines.append('    %s' % item)
        lines.append('  ]')
    lines.append('}')
    return "\n".join(lines)


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

    匹配 `characters "wudang_guxu" {`（允许前导空白）。
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


def already_done(text, char_name):
    """True：char 块已存在且已有 inquiries。"""
    block = find_char_block(text, char_name)
    if block is None:
        return False
    start, close = block
    return block_has_inquiries(text, start, close)


def plan(text):
    """返回 dict：{char_name: plan_info}；plan_info 为 None 表示无需改动，
    否则为 {"exists": bool, "has_inquiries": bool}。None 整体返回表示全部无需改动。"""
    result = {}
    any_pending = False
    for npc in NPCS:
        cn = npc["id"]
        if already_done(text, cn):
            result[cn] = None
            continue
        block = find_char_block(text, cn)
        if block is None:
            result[cn] = {"exists": False, "has_inquiries": False}
        else:
            start, close = block
            result[cn] = {"exists": True, "has_inquiries": block_has_inquiries(text, start, close)}
        if result[cn] is not None:
            any_pending = True
    return result if any_pending else None


def backup():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-wudang-ask-me-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    src = os.path.join(DATA_WORLD, TARGET_ZONE)
    shutil.copy2(src, os.path.join(bdir, TARGET_ZONE))
    print("  备份 -> %s" % bdir)
    return bdir


def apply(plan_dict, text):
    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    lines = text.split("\n")

    # 去掉末尾空行，准备追加
    while lines and lines[-1] == "":
        lines = lines[:-1]
    lines.append("")
    lines.append("")

    for npc in NPCS:
        cn = npc["id"]
        p = plan_dict.get(cn)
        if p is None:
            print("  跳过 %s：已有 inquiries（无需改动）。" % cn)
            continue

        block_text = build_char_block(npc)
        lines.append(block_text)
        lines.append("")

        if not p["exists"]:
            print("  写入 %s：+characters %s（完整块）" % (TARGET_ZONE, cn))
        else:
            print("  写入 %s：+characters %s（块已存在，重写）" % (TARGET_ZONE, cn))

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
    print("== P5-4x wudang 6 门 ask_me NPC inquiries backfill ==")
    print("模式: %s" % ("APPLY" if apply_flag else "dry-run"))
    print("NPC: 谷虚道长(give_item daodejing_i) 清虚道长(give_item daodejing_ii)")
    print("     张翠山(perform_id yitian-zhang/zheng) 张松溪(perform_id xuanxu-dao/huan)")
    print("     殷梨亭(perform_id raozhi-roujian/chuankong) 俞莲舟(perform_id huzhua-shou/juehu)")

    path = os.path.join(DATA_WORLD, TARGET_ZONE)
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    p = plan(text)
    if p is None:
        print("无需改动：%s :: 6 个 NPC 块均已有 inquiries。" % TARGET_ZONE)
        return

    for cn, pd in p.items():
        if pd is None:
            print("  计划：%s :: %s 已有 inquiries，跳过。" % (TARGET_ZONE, cn))
        elif not pd["exists"]:
            print("  计划：%s :: %s 块不存在，将在文末追加完整 characters 块。" % (TARGET_ZONE, cn))
        else:
            print("  计划：%s :: %s 块已存在，将重写。" % (TARGET_ZONE, cn))

    if not apply_flag:
        print("\n(dry-run 结束；加 --apply 真正写盘)")
        return

    backup()
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
    all_done = True
    for npc in NPCS:
        cn = npc["id"]
        if not already_done(text2, cn):
            print("  [WARN] %s：复跑后仍未完成。" % cn)
            all_done = False
    if all_done:
        print("  OK：6 个 NPC 块均已有 inquiries（幂等 0 待改）。")
    else:
        print("  [WARN] 幂等检查未通过。", file=sys.stderr)
        sys.exit(2)
    print("OK：%s :: wudang 6 门 ask_me NPC 回填完毕。" % TARGET_ZONE)


if __name__ == "__main__":
    main()
