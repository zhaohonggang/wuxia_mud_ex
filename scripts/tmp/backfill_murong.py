#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#763 慕容派 UCL 补完（docs/慕容派教学门控移植计划.zh-CN.md）。幂等。

已有：3 teach、8 grant、1 give_item、2 apprentice、慕容博 no_teach。
本脚本补：permit/born_family 门、逐字 skill deny、success 文案、coagents、chat、
慕容龙城「绝技/绝招」两条占位别名。
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "data" / "world" / "clone_lib.ucl"

PERMIT_LINES = (
    '    betray_sect_deny = "你吃里爬外，反复无常，叫我如何收你？"\n'
    '    required_born_family = "慕容世家"\n'
    '    born_family_deny = "你不是我们慕容家的人，师徒就免了吧。"\n'
    '    other_family_deny = "你既然已经离家拜师，又跑回来作甚？"\n'
)


def block_span(text, key):
    start = text.find('characters "%s" {' % key)
    if start < 0:
        raise SystemExit("missing %s" % key)
    starts = [m.start() for m in re.finditer(r'characters "', text)]
    next_start = min(s for s in starts if s > start)
    # 块中间也有 `    }`（teach_skills 等嵌套 map），取下一个块之前的最后一个。
    end = text.rfind("\n    }\n", start, next_start)
    return start, end


def patch(text, old, new, label):
    if new in text:
        print("  SKIP", label)
        return text
    if old not in text:
        raise SystemExit("missing anchor: " + label)
    print("  PATCH", label)
    return text.replace(old, new, 1)


def main():
    text = TARGET.read_text(encoding="utf-8")

    # 慕容复：born_family / permit 三句 + coagents + 战斗闲聊。
    s, e = block_span(text, "murong_murongfu")
    b = text[s:e]
    anchor = '  apprentice = {\n    family = "慕容世家"\n    permit_recruit = true\n'
    if "required_born_family" not in b:
        b = b.replace(anchor, anchor + PERMIT_LINES, 1)
    # 旧批次把 LPC 的 `\n` 写进 UCL 字符串：按项目定论字面 `\n` 不换行，
    # 改为单行逐字文案（信息不丢失）。
    b = patch(b,
              '    max_shen_deny = "我慕容世家向来不和你们这些所谓正道人士交往。\\n你还是请回吧！"\n',
              '    max_shen_deny = "我慕容世家向来不和你们这些所谓正道人士交往。你还是请回吧！"\n',
              "murongfu max_shen_deny 去掉字面 \\n")
    if "coagents = [" not in b:
        b = b.rstrip("\n") + """

  coagents = [
    { id = "murong bo" startroom = "yanziwu:canheju" }
  ]

  chat_chance_combat = 120
  chat_msg_combat = ["recover", "parry.yi", "blade.feng", "cuff.zhai"]
"""
    text = text[:s] + b + text[e:]

    # 慕容博：born_family / permit、逐字三技能 deny、recruit_skill_order、
    # 成功文案、战斗闲聊。
    s, e = block_span(text, "murong_murongbo")
    b = text[s:e]
    if "required_born_family" not in b:
        b = b.replace(anchor, anchor + PERMIT_LINES, 1)
    b = patch(b,
              '    max_shen_deny = "我慕容博向来不与你们这些所谓正道人士交往。\\n你还是请回吧！"\n',
              '    max_shen_deny = "我慕容博向来不与你们这些所谓正道人士交往。你还是请回吧！"\n',
              "murongbo max_shen_deny 去掉字面 \\n")
    b = patch(b,
              '      canhe_zhi = "该武功仅限本门弟子，不传外人。"\n',
              '      canhe_zhi = "我最讨厌你们这些所谓正派人士，你还是请回吧！'
              '你不是我们慕容家的人，我怎敢妄加指点。阁下还是请回吧！'
              '阁下与我毫无瓜葛，我怎敢妄加指点？你参合指火候还不够，还得下去多多练习。"\n',
              "murongbo canhe-zhi no_teach 四门文案")
    b = patch(b,
              '    min_skills_deny = "你的慕容世家武功基础尚浅，下去多多练习再来吧。"\n',
              '    min_skills_deny = {\n'
              '      douzhuan_xingyi = "斗转星移乃我慕容世家绝技，你不好好练习到我这来做甚？。"\n'
              '      murong_xinfa = "我慕容世家武功讲究心神合一，最重视基本心法。你的慕容心法还不够熟练，下去练练再来吧。"\n'
              '      dodge = "我慕容世家武功需配合灵巧的身法。你是否还应该在轻功修为上多下点功夫？"\n'
              '    }\n'
              '    recruit_skill_order = ["douzhuan-xingyi", "murong-xinfa", "dodge"]\n',
              "murongbo min_skills_deny")
    b = patch(b,
              '    min_exp_deny = "你现在经验尚浅，还是多在江湖上走吧。"\n',
              '    min_exp_deny = "你现在经验尚浅，还是多在江湖上走走吧。"\n',
              "murongbo min_exp_deny")
    b = patch(b,
              '    accept_msg = "很好，很好。念在你有心，今日我便收你为徒，希望日后能有一番作为。"\n',
              '    accept_msg = "慕容博大喜：我们慕容家真是英才迭出，复国有望啊！"\n',
              "murongbo accept_msg")
    if "chat_chance_combat" not in b:
        b = b.rstrip("\n") + """

  chat_chance_combat = 120
  chat_msg_combat = ["powerup", "recover", "finger.canhe", "parry.yi", "finger.lian", "finger.zhi"]
"""
    text = text[:s] + b + text[e:]

    # 慕容龙城：绝技/绝招 与 风雨交加 同指 ask_me。
    s, e = block_span(text, "murong_longcheng")
    b = text[s:e]
    if "inquire about me (unimplemented)" in b:
        anchor = '    { key = "风雨交加" value = {'
        i = b.find(anchor)
        j = b.find("\n    } }", i) + len("\n    } }")
        grant = b[i + len('    { key = "风雨交加" '):j]
        for key in ["绝技", "绝招"]:
            old = '    { key = "%s" value = " inquire about me (unimplemented)" },' % key
            b = b.replace(old, '    { key = "%s" %s,' % (key, grant), 1)
        print("  PATCH murong_longcheng 绝技/绝招 aliases")
    text = text[:s] + b + text[e:]

    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print("WROTE", TARGET)


if __name__ == "__main__":
    main()
