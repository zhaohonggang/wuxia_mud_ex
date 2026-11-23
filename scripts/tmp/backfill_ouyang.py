#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#940-#943 欧阳世家（ouyang）UCL 回填（docs/欧阳世家教学门控移植计划.zh-CN.md）。幂等。

只改 data/world/clone_lib.ucl 的两个 ouyang_* 块；不触碰 combat 属性行。
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "data" / "world" / "clone_lib.ucl"


def block_span(text, key):
    start = text.find('characters "%s" {' % key)
    if start < 0:
        raise SystemExit("missing %s" % key)
    starts = [m.start() for m in re.finditer(r'characters "', text)]
    next_start = min(s for s in starts if s > start)
    end = text.rfind("\n    }\n", start, next_start)
    if end < 0:
        raise SystemExit("missing end for %s" % key)
    return start, end


def rep(block, old, new, label):
    if old not in block:
        raise SystemExit("missing anchor: " + label)
    if new in block:
        print("  SKIP", label)
        return block
    print("  PATCH", label)
    return block.replace(old, new, 1)


def rep_all(block, old, new, label):
    if old not in block:
        raise SystemExit("missing anchor: " + label)
    if old == new:
        return block
    count = block.count(old)
    print("  PATCH x%d" % count, label)
    return block.replace(old, new)


FENG_APPRENTICE = '''  apprentice = {
    family = "欧阳世家"
    gate_order = "lpc_ouyang"
    reject_student_names = ["欧阳锋", "欧阳克"]
    reject_student_name_deny = "大怒：他奶奶的！你起这个名字是什么意思啊？"
    required_born_family = "欧阳世家"
    born_family_deny = "你不是我们欧阳家的人，我怎能收你为徒？"
    betray_sect_deny = "你反复无常，我不能收你为徒！"
    betray_times_deny = "你反复无常，我不能收你为徒！"
    other_family_deny = "你虽然是我们欧阳家的人，但你入了其他门派，我不能收你为徒！"
    min_exp = 200000
    min_exp_deny = "你的经验还不够，先和我的侄儿欧阳克学习武功吧。"
    accept_msg = "欧阳锋喃喃自语道：我欧阳家真是后继有人啊！"
  }
'''

KE_APPRENTICE = '''  apprentice = {
    family = "欧阳世家"
    gate_order = "lpc_ouyang"
    reject_student_names = ["欧阳锋", "欧阳克"]
    reject_student_name_deny = "大怒：他奶奶的！你起这个名字是什么意思啊？"
    required_born_family = "欧阳世家"
    born_family_deny = "你不是我们欧阳家的人，我怎能收你为徒？"
    female_born_family_deny = "这位真乃我的红颜知己，可惜家规所限，不能传你武功，你还是做我的小妾吧。"
    betray_sect_deny = "你反复无常，我不能收你为徒！"
    betray_times_deny = "你反复无常，我不能收你为徒！"
    other_family_deny = "你虽然是我们欧阳家的人，但你入了其他门派，我不能收你为徒！"
    accept_msg = "好... 很好！"
  }
'''

FENG_COMBAT_CHAT = '''
  chat_chance_combat = 120
  chat_msg_combat = ["staff.chan", "staff.qianshe", "staff.wuji", "strike.zhen", "cuff.rou", "powerup", "recover"]
'''


def patch_feng(text):
    s, e = block_span(text, "ouyang_ouyangfeng")
    b = text[s:e]

    # 1. 三条绝招门序：lpc_kunlun 只认 min_shen，会静默跳过 max_shen 负上界。
    b = rep_all(b, 'gate_order = "lpc_kunlun"', 'gate_order = "lpc_ouyang"',
                "feng grants gate_order → lpc_ouyang")

    # 2. improve_skills 次数：LPC staff×2 + lingshe-zhangfa×2 + martial-cognize×1。
    b = rep_all(
        b,
        '      improve_skills = ["staff", "lingshe-zhangfa", "martial-cognize"]',
        '      improve_skills = ["staff", "staff", "lingshe-zhangfa", "lingshe-zhangfa", "martial-cognize"]',
        "feng improve_skills 重复次数",
    )

    # 3. 千蛇万噬 LPC `add("gongxian",1000)`（非笔误，负 cost 表达增加）。
    b = rep(b, '''      perform_id = "lingshe-zhangfa/wanshi"
      skill = "lingshe-zhangfa"
      gate_order = "lpc_ouyang"
      family = "欧阳世家"
      max_shen = -120000
      min_gongxian = 1000
      cost_gongxian = 1000''', '''      perform_id = "lingshe-zhangfa/wanshi"
      skill = "lingshe-zhangfa"
      gate_order = "lpc_ouyang"
      family = "欧阳世家"
      max_shen = -120000
      min_gongxian = 1000
      cost_gongxian = -1000''', "feng wanshi gongxian +1000")

    # 4. 显示文案不写字面 \n（项目实测定论）。
    for old, new in [
        ('      msg_one = "$n将「横行无忌」演练了一遍，$N看得出神，心中惊叹不已。\\n"',
         '      msg_one = "$n将「横行无忌」演练了一遍，$N看得出神，心中惊叹不已。"'),
        ('      learned = "你学会了「横行无忌」。\\n"',
         '      learned = "你学会了「横行无忌」。"'),
        ('      msg_one = "$n喝道：看仔细了！说把荡臂横扫，伸伸缩缩，当真是变幻无穷！\\n"',
         '      msg_one = "$n喝道：看仔细了！说把荡臂横扫，伸伸缩缩，当真是变幻无穷！"'),
        ('      learned = "你学会了千蛇出洞。\\n"',
         '      learned = "你学会了千蛇出洞。"'),
        ('      msg_one = "$n微微颔首，随手拣起一根木条点向$N，$N见来招缓慢，只是随手向上一格。\\n忽然$n杖势一变，木条从意想不到的角度拐来，$N大吃一惊，慌乱不迭。\\n"',
         '      msg_one = "$n微微颔首，随手拣起一根木条点向$N，$N见来招缓慢，只是随手向上一格。忽然$n杖势一变，木条从意想不到的角度拐来，$N大吃一惊，慌乱不迭。"'),
        ('      learned = "你学会了千蛇万噬。\\n"',
         '      learned = "你学会了千蛇万噬。"'),
        ('      success = "好，你便用这灵蛇杖去对付那些正派人士吧！\\n"',
         '      success = "好，你便用这灵蛇杖去对付那些正派人士吧！"'),
    ]:
        b = rep(b, old, new, "去掉字面 \\n: " + old[:34])

    # 5. 显示文案去字面 \n（两条筝谱共用同一句）。
    b = rep_all(b, '      success = "你拿去自己好好琢磨吧。\\n"',
                '      success = "你拿去自己好好琢磨吧。"', "feng zhengpu success 去 \\n")

    # 6. 筝谱库存：LPC set("music_book",1) + reset() 恢复 1；可重复领取。
    b = rep_all(
        b,
        '''      kind = "give_item"
      item = "clone_lib:zhengpu"
      match = "zhengpu"
      family = "欧阳世家"
      success = "你拿去自己好好琢磨吧。"''',
        '''      kind = "give_item"
      item = "clone_lib:zhengpu"
      match = "zhengpu"
      unique = false
      count = "music_book"
      family = "欧阳世家"
      vision_name = "欧阳锋"
      success = "你拿去自己好好琢磨吧。"
      exhausted = "我的筝谱已经借出去了。"''',
        "feng zhengpu count/unique/exhausted",
    )
    # 7. 灵蛇杖：补已有副本文案 + vision_name（is_good/持有者遍历仍为 GAP）。
    b = rep(b, '''      master_deny = "只有我的弟子才能用灵蛇杖，你还是请回吧。"
      success = "好，你便用这灵蛇杖去对付那些正派人士吧！"''', '''      master_deny = "只有我的弟子才能用灵蛇杖，你还是请回吧。"
      already = "灵蛇杖不是在你的手中么，怎么反而来找我呢？"
      vision_name = "欧阳锋"
      success = "好，你便用这灵蛇杖去对付那些正派人士吧！"''', "feng lingshezhang already/vision_name")

    # 7. NPC 侧库存初值（LPC set("music_book",1)）。
    if "inquiry_state" not in b:
        b = rep(b, '''  chat_chance = 2
chats = [''', '''  inquiry_state = {
    music_book = 1
  }

  chat_chance = 2
chats = [''', "feng inquiry_state music_book")

    # 8. combat apply（LPC set_temp("apply/*")）。仅插入 apply 子块，不改已有属性行。
    if "apply = {" not in b:
        b = rep(b, '''    str = 32
  }''', '''    str = 32
    apply = {
      attack = 150
      defense = 150
      damage = 100
      unarmed_damage = 100
      armor = 200
    }
  }''', "feng combat apply")

    # 9. 战斗闲聊 7 条（LPC chat_chance_combat=120）。
    if "chat_chance_combat" not in b:
        b = rep(b, '''  carry = [
    { id = items.shezhang.id },
    { id = items.cloth.id },
    { id = items.tiezheng.id }
  ]
''', '''  carry = [
    { id = items.shezhang.id },
    { id = items.cloth.id },
    { id = items.tiezheng.id }
  ]
''' + FENG_COMBAT_CHAT, "feng combat chat")

    # 10. 收徒四门 + 成功文案（替换旧 4 行 apprentice 块）。
    old_appr = '''  apprentice = {
    family = "欧阳世家"
    permit_recruit = true
    min_exp = 200000
    min_exp_deny = "你的经验还不够，先和我的侄儿欧阳克学习武功吧。"
  }
'''
    if old_appr in b:
        print("  PATCH feng apprentice")
        b = b.replace(old_appr, FENG_APPRENTICE, 1)
    elif "gate_order = \"lpc_ouyang\"\n    reject_student_names" not in b:
        raise SystemExit("missing feng apprentice anchor")

    # 11. guzheng-jifa 首次授艺说台词并落 mark（recognize_apprentice）。
    if "can_learn/ouyang/guzheng-jifa" not in b:
        b = rep(b, '''    no_teach = {
      force = "该武功仅限本门弟子，不传外人。"''', '''    no_teach = {
      guzheng_jifa = {
        unlock = {
          mark = "can_learn/ouyang/guzheng-jifa"
          min_exp = -1
          learned = "好吧，你愿意学我就传你一点古筝之道。"
        }
      }
      force = "该武功仅限本门弟子，不传外人。"''', "feng guzheng-jifa unlock")

    return text[:s] + b + text[e:]


def patch_ke(text):
    s, e = block_span(text, "ouyang_ouyangke")
    b = text[s:e]

    # 1. 显示文案去字面 \n。
    b = rep_all(b, '      success = "嗯，你可得收好了！别到处乱放。\\n"',
                '      success = "嗯，你可得收好了！别到处乱放。"', "ke shenshe success 去 \\n")

    # 2. 引路神蛇库存 5（LPC set_temp("shenshe_count",5)）；冷却 900s 为 GAP。
    b = rep_all(
        b,
        '''      kind = "give_item"
      item = "baituo:shenshe"
      match = "shenshe"
      family = "欧阳世家"
      success = "嗯，你可得收好了！别到处乱放。"''',
        '''      kind = "give_item"
      item = "baituo:shenshe"
      match = "shenshe"
      unique = false
      count = "shenshe_count"
      family = "欧阳世家"
      success = "嗯，你可得收好了！别到处乱放。"''',
        "ke shenshe count/unique",
    )
    if "shenshe_count" not in b.split("inquiries = [")[0]:
        b = rep(b, '''  chat_chance = 2
chats = [''', '''  inquiry_state = {
    shenshe_count = 5
  }

  chat_chance = 2
chats = [''', "ke inquiry_state shenshe_count")

    # 2. recognize_apprentice 逐字拒绝文案 + lingshe-quan 硬标记门。
    b = rep_all(b, '"该武功仅限本门弟子，不传外人。"', '"我可没答应教你其他武功。"',
                "ke no_teach 逐字文案")
    if "can_learn/lingshe-quan/ke" not in b:
        b = rep(b, '''    no_teach = {
      cuff = "我可没答应教你其他武功。"''', '''    no_teach = {
      lingshe_quan = {
        unlock = {
          mark = "can_learn/lingshe-quan/ke"
          require_mark_only = true
          locked = "干嘛？没拜师就想向本少爷学东西？"
        }
      }
      cuff = "我可没答应教你其他武功。"''', "ke lingshe-quan mark-only unlock")

    # 3. 收徒四门 + 女性外姓专属拒绝 + 成功文案。
    old_appr = '''  apprentice = {
    family = "欧阳世家"
    permit_recruit = true
    gender_deny = "家规所限，不能传你武功，你还做我的小妾吧。"
  }
'''
    if old_appr in b:
        print("  PATCH ke apprentice")
        b = b.replace(old_appr, KE_APPRENTICE, 1)
    elif "female_born_family_deny" not in b:
        raise SystemExit("missing ke apprentice anchor")

    return text[:s] + b + text[e:]


def main():
    text = TARGET.read_text(encoding="utf-8")
    print("ouyangfeng:")
    text = patch_feng(text)
    print("ouyangke:")
    text = patch_ke(text)
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print("written", TARGET)


if __name__ == "__main__":
    main()
