#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""#933 明教 UCL 回填（Task #932 plan；LPC kungfu/class/mingjiao/*.c 逐字）。

幂等：已含 `teach = {` 或 `mingjiao_grant` 标记的块跳过。
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "data" / "world" / "clone_lib.ucl"

CN = {
    "force": "基本内功", "dodge": "基本轻功", "sword": "基本剑法",
    "blade": "基本刀法", "unarmed": "基本拳脚", "cuff": "基本拳法",
    "strike": "基本掌法", "parry": "基本招架", "hand": "基本手法",
    "claw": "基本爪法", "staff": "基本杖法", "throwing": "基本暗器",
    "finger": "基本指法", "pili-quan": "霹雳神拳",
    "shenghuo-xinfa": "圣火心法", "shenghuo-ling": "圣火令法",
    "jiuyang-shengong": "九阳神功", "xiaoyao-jian": "逍遥剑法",
    "pomopima-jian": "泼墨披麻剑", "sougu-yingzhua": "搜骨鹰爪功",
    "hanbing-mianzhang": "寒冰绵掌", "pili-shou": "混元霹雳手",
    "qishang-quan": "七伤拳", "tougu-zhen": "透骨针",
    "yinfeng-dao": "阴风刀", "yinhu-zhang": "银瑚杖法",
    "duoming-jinhua": "夺命金花", "literate": "读书写字",
    "martial-cognize": "武学修养",
}

COMMON_DENIES = (
    '    betray_sect_deny = "我们明教教规你还记得吗，你还有脸回来！"\n'
    '    betray_times_deny = "哼，阁下不忠不信，我们明教可不会收留。"\n'
    '    other_family_deny = "阁下既有了师承，还来我们明教做什么？"\n'
)
SHEN_DENY = "你行侠仗义的事做得还不够，还是请回吧。"
XINFA_DENY = "你圣火心法不够娴熟，还是下去多练习一下吧！"
EXP_DENY = "你江湖经验不足，还是多磨练一下吧！"
ACCEPT = "好，好，今日我就收你为弟子。"

MASTERS = {
    "mingjiao_daijisi": {
        "teach": [("force", 320), ("dodge", 300), ("parry", 300), ("throwing", 320),
                  ("staff", 320), ("cuff", 320), ("pili-quan", 320),
                  ("duoming-jinhua", 320), ("yinhu-zhang", 320), ("shenghuo-xinfa", 320),
                  ("shenghuo-bu", 300), ("literate", 260), ("martial-cognize", 240)],
        "shen": 60000, "skills": [("shenghuo-xinfa", 180)], "exp": 450000,
        "denies": {"shenghuo-xinfa": XINFA_DENY}, "accept": ACCEPT,
        "co": ["zhang wuji", "fan yao", "yin tianzheng", "weiyi xiao", "xie xun"],
        "chat": (120, ["perform staff.lao", "perform cuff.jin"]),
        "grants": [
            ("大海捞针", "yinhu-zhang/lao", [("yinhu-zhang", 100)], 2000, {"force": 260}, 750, 70000, False),
            ("天外飞花", "duoming-jinhua/hua", [("duoming-jinhua", 120)], 2400, {"force": 200}, 750, 70000, False),
        ],
    },
    "mingjiao_lengqian": {
        "teach": [("force", 140), ("shenghuo-xinfa", 140), ("dodge", 120),
                  ("shenghuo-bu", 120), ("cuff", 140), ("pili-quan", 140),
                  ("parry", 140), ("strike", 140), ("sword", 140),
                  ("literate", 120), ("martial-cognize", 100)],
        "shen": 0, "skills": [], "exp": None,
        "denies": {}, "accept": "好，好，今日我就收你为弟子，从此你便入我明教，信奉明尊。",
        "shen_deny": "阁下身染邪气，还是及早回头得好。",
        "co": ["zhang wuji", "fan yao", "yang xiao"],
        "chat": (120, ["perform cuff.jin"]),
        "grants": [
            ("紫雷劲", "pili-quan/jin", [("pili-quan", 40)], None, {}, 80, 500, False),
        ],
    },
    "mingjiao_weiyixiao": {
        "teach": [("force", 220), ("dodge", 240), ("strike", 240), ("sword", 220),
                  ("claw", 220), ("sougu-yingzhua", 220), ("parry", 220),
                  ("shenghuo-xinfa", 220), ("qingfu-shenfa", 240), ("shenghuo-bu", 240),
                  ("hanbing-mianzhang", 240), ("literate", 200), ("martial-cognize", 180)],
        "shen": 10000, "skills": [("shenghuo-xinfa", 100), ("dodge", 100)], "exp": None,
        "denies": {"shenghuo-xinfa": XINFA_DENY,
                   "dodge": "你基本轻功火候不够，怎么学我的青蝠身法！"},
        "accept": ACCEPT,
        "co": ["zhang wuji", "fan yao", "dai jisi", "xie xun", "yin tianzheng"],
        "chat": (120, ["perform strike.jue"]),
        "grants": [
            ("赤血爪", "sougu-yingzhua/xue", [("sougu-yingzhua", 60)], None, {"force": 80}, 200, 11000, False),
            ("连绵不绝", "hanbing-mianzhang/jue", [("hanbing-mianzhang", 100)], None, {}, 480, 14000, False),
        ],
    },
    "mingjiao_xiexun": {
        "teach": [("force", 280), ("dodge", 260), ("parry", 260), ("hand", 280),
                  ("cuff", 280), ("shenghuo-xinfa", 280), ("shenghuo-bu", 260),
                  ("pili-shou", 280), ("pili-quan", 280), ("qishang-quan", 280),
                  ("literate", 240), ("martial-cognize", 220)],
        "shen": 40000, "skills": [("shenghuo-xinfa", 140)], "exp": 380000,
        "denies": {"shenghuo-xinfa": XINFA_DENY},
        "accept": ACCEPT,
        "co": ["zhang wuji", "fan yao", "dai jisi", "weiyi xiao", "yin tianzheng"],
        "chat": (120, ["perform cuff.shang", "perform cuff.fei"]),
        "grants": [
            ("天地混元", "pili-shou/hun", [("pili-shou", 140)], None, {"force": 240}, 550, 48000, False),
            ("伤字诀", "qishang-quan/shang", [("qishang-quan", 120)], None, {"force": 180}, 550, 48000, False),
            ("魂魄飞扬", "qishang-quan/fei", [("qishang-quan", 160)], None, {"force": 260}, 850, 68000, False),
        ],
    },
    "mingjiao_yintianzheng": {
        "teach": [("force", 280), ("dodge", 260), ("parry", 260), ("strike", 280),
                  ("cuff", 280), ("pili-quan", 280), ("finger", 280),
                  ("shenghuo-xinfa", 280), ("shenghuo-bu", 260), ("yinfeng-dao", 280),
                  ("tougu-zhen", 280), ("literate", 240), ("martial-cognize", 220)],
        "shen": 60000, "skills": [("shenghuo-xinfa", 180)], "exp": 450000,
        "denies": {"shenghuo-xinfa": XINFA_DENY},
        "accept": ACCEPT,
        "co": ["zhang wuji", "fan yao", "dai jisi", "weiyi xiao", "xie xun"],
        "chat": (120, ["perform strike.jue", "perform finger.feng"]),
        "grants": [
            ("封杀", "tougu-zhen/feng", [("tougu-zhen", 100)], 2400, {"force": 260}, 750, 68000, False),
            ("绝杀", "yinfeng-dao/jue", [("yinfeng-dao", 140)], 2400, {"force": 260}, 750, 68000, False),
        ],
    },
    "mingjiao_yangxiao": {
        "teach": [("force", 320), ("dodge", 340), ("strike", 340), ("sword", 320),
                  ("parry", 320), ("cuff", 320), ("unarmed", 320), ("pili-quan", 320),
                  ("shenghuo-xinfa", 320), ("shenghuo-bu", 340), ("pomopima-jian", 340),
                  ("xiaoyao-jian", 340), ("literate", 300), ("martial-cognize", 280)],
        "shen": 80000, "skills": [("shenghuo-xinfa", 160), ("dodge", 160)], "exp": 700000,
        "denies": {"shenghuo-xinfa": XINFA_DENY,
                   "dodge": "你基本轻功火候不够，怎么学我的逍遥剑法！"},
        "accept": ACCEPT,
        "exp_deny": "你江湖经验尚浅，还是去多闯荡一下吧！",
        "co": ["zhang wuji"],
        "chat": (20, ["perform sword.kuai", "perform sword.qi", "perform sword.fei", "perform cuff.jin"]),
        "grants": [
            ("醉里乾坤", "pomopima-jian/zui", [("pomopima-jian", 120)], None, {"force": 180}, 700, 80000, False),
            ("飞剑诀", "xiaoyao-jian/fei", [("xiaoyao-jian", 60)], None, {}, 400, 80000, False),
            ("快剑诀", "xiaoyao-jian/kuai", [("xiaoyao-jian", 160)], None, {"dodge": 260}, 680, 85000, False),
            ("奇剑诀", "xiaoyao-jian/qi", [("xiaoyao-jian", 160)], 3000, {}, 780, 88000, False),
        ],
        "huanling": True,
    },
    "mingjiao_zhangwuji": {
        "teach": [("force", 360), ("unarmed", 340), ("dodge", 340), ("parry", 340),
                  ("cuff", 340), ("sword", 340), ("jiuyang-shengong", 360),
                  ("shenghuo-shengong", 360), ("shenghuo-xinfa", 360),
                  ("qiankun-danuoyi", 360), ("shenghuo-bu", 340), ("qishang-quan", 340),
                  ("taiji-quan", 340), ("taiji-jian", 340), ("shenghuo-ling", 340)],
        "shen": 90000, "skills": [("shenghuo-xinfa", 180), ("force", 180)], "exp": 800000,
        "denies": {"shenghuo-xinfa": XINFA_DENY,
                   "force": "你基本内功火候不够，怎么学我明教的圣火神功！"},
        "accept": "好，好，今日我就收你为弟子，将我明教圣火神功传授于你",
        "exp_deny": "你江湖经验还不够，下去多磨练一下吧！",
        "no_teach": {
            "jiuyang-shengong": "这个我可不能传你。",
            "taiji-jian": "你还是找我太师父吧！",
            "taiji-quan": "你还是找我太师父吧！",
            "qishang-quan": "想学七伤拳你还是找我义父谢逊吧！",
        },
        "co": [],
        "chat": (120, ["perform sword.hua", "perform sword.xi", "perform sword.lian",
                       "perform sword.can", "perform cuff.shang", "perform cuff.fei",
                       "shield", "powerup", "recover"]),
        "grants": [
            ("吸焰令", "shenghuo-ling/xi", [("shenghuo-ling", 140)], 2000, {}, 800, 100000, False),
            ("敛心令", "shenghuo-ling/lian", [("shenghuo-ling", 160)], 2200, {}, 800, 100000, False),
            ("光华令", "shenghuo-ling/hua", [("shenghuo-ling", 160)], 2400, {}, 900, 80000, False),
            ("残血令", "shenghuo-ling/can", [("shenghuo-ling", 220)], 5000, {"force": 350}, 1000, 100000, False),
            ("混沌一阳", "jiuyang-shengong/hun", [("jiuyang-shengong", 180)], 2000, {"force": 270}, 0, None, True),
            ("九曦混阳", "jiuyang-shengong/jiu", [("jiuyang-shengong", 200)], 5000, {"force": 320}, 0, None, True),
            ("金阳破岭", "jiuyang-shengong/po", [("jiuyang-shengong", 220), ("sword", 240), ("force", 240)], 5500, {}, 0, None, True),
            ("骄阳劈天", "jiuyang-shengong/pi", [("jiuyang-shengong", 220), ("blade", 240), ("force", 240)], 5500, {}, 0, None, True),
            ("魔光日无极", "jiuyang-shengong/ri", [("jiuyang-shengong", 260)], 8000, {}, 0, None, True),
        ],
    },
}


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_teach(block):
    lines = ["  teach = {", '    family = "明教"', "    teach_skills = {"]
    for key, level in block["teach"]:
        lines.append("      %s = { max = %d gongxian = 0 }" % (key.replace("-", "_"), level))
    lines.append("    }")
    if block.get("no_teach"):
        lines.append("    no_teach = {")
        for key, text in block["no_teach"].items():
            lines.append("      %s = %s" % (key.replace("-", "_"), q(text)))
        lines.append("    }")
    lines.append("  }")
    return "\n".join(lines) + "\n"


def build_apprentice(block):
    lines = ["  apprentice = {", '    family = "明教"', "    permit_recruit = true",
             '    gate_order = "lpc_mingjiao"', COMMON_DENIES.rstrip("\n")]
    lines.append("    min_shen = %d" % block["shen"])
    lines.append("    min_shen_deny = %s" % q(block.get("shen_deny", SHEN_DENY)))
    if block["skills"]:
        lines.append("    min_skills = {")
        for key, level in block["skills"]:
            lines.append("      %s = %d" % (key.replace("-", "_"), level))
        lines.append("    }")
        lines.append("    min_skills_deny = {")
        for key, _level in block["skills"]:
            lines.append("      %s = %s" % (key.replace("-", "_"),
                                            q(block["denies"][key])))
        lines.append("    }")
        lines.append("    recruit_skill_order = [%s]" %
                     ", ".join(q(k) for k, _ in block["skills"]))
    if block["exp"] is not None:
        lines.append("    min_exp = %d" % block["exp"])
        lines.append("    min_exp_deny = %s" % q(block.get("exp_deny", EXP_DENY)))
    lines.append("    accept_msg = %s" % q(block["accept"]))
    lines.append("  }")
    return "\n".join(lines) + "\n"


BASE = {
    "shenghuo-ling": "sword", "jiuyang-shengong": "unarmed",
    "pomopima-jian": "sword", "xiaoyao-jian": "sword",
    "sougu-yingzhua": "claw", "hanbing-mianzhang": "strike",
    "pili-shou": "hand", "qishang-quan": "cuff", "tougu-zhen": "finger",
    "yinfeng-dao": "strike", "yinhu-zhang": "staff",
    "duoming-jinhua": "throwing", "pili-quan": "cuff",
}


def build_grant(name, perform, skills, neili, extra, gx, shen, free):
    sk1 = skills[0][0]
    lines = [
        "    { key = %s value = {" % q(name),
        '      kind = "sect_master_grant"',
        "      perform_id = %s" % q(perform),
        '      gate_order = "lpc_masterd"',
        "      family = %s" % q("明教"),
        "      skill = %s" % q(sk1),
    ]
    if free:
        lines.append("      no_family_check = true")
    if shen is not None and not free:
        lines.append("      min_shen = %d" % shen)
    if gx:
        lines.append("      min_gongxian = %d" % gx)
        lines.append("      cost_gongxian = %d" % gx)
    # min_levels: 有序 sk1..skN → force/dodge（独立字段）→ max-neili
    # sk 中显式出现的 force 不可再当独立字段重复。
    order = []
    levels = []
    for sk, lv in skills:
        order.append(sk)
        levels.append((sk, lv))
    for key, lv in extra.items():
        if key in order:
            continue
        order.append(key)
        levels.append((key, lv))
    if neili is not None:
        order.append("max-neili")
        levels.append(("max-neili", neili))
    lines.append("      min_levels = {")
    for k, v in levels:
        lines.append("        %s = %d" % (k.replace("-", "_"), v))
    lines.append("      }")
    lines.append("      level_order = [%s]" % ", ".join(q(k) for k in order))
    denies = {
        "maxed": "自己下去练，还来罗嗦什么。",
        "family_deny": "与我明教素无渊源，不知此话从何说起。",
        "skill_deny": "你连%s都未曾学过，何谈绝招可言？" % CN.get(sk1, sk1),
        "shen_deny": "你目前所做的侠义正事不够，这招暂时还不能传你。",
        "gongxian_deny": "你为明教作出的贡献不够，这招暂时还不能传你。",
    }
    for key, _ in denies.items():
        lines.append("      %s = %s" % (key, q(denies[key])))
    lines.append("      level_deny = {")
    for k, _ in levels:
        if k == "max-neili":
            text = "你现在的内力修为不足，修炼高点再来吧。"
        elif k == "force" and k not in [s for s, _ in skills]:
            text = "你目前的内功火候不足，下去练练再来吧。"
        elif k == "dodge" and k not in [s for s, _ in skills]:
            text = "你目前的轻功火候不足，下去练练再来吧。"
        else:
            text = "你对%s的了解还不够，尚且无法领悟此招。" % CN.get(k, k)
        lines.append("        %s = %s" % (k.replace("-", "_"), q(text)))
    lines.append("      }")
    lines.append("      learned = %s" % q("你学会了「%s」。" % name))
    improve = []
    base = BASE.get(sk1)
    if base:
        improve.append(base)
    for sk, _ in skills:
        if sk not in improve:
            improve.append(sk)
    for k in extra:
        if k not in improve:
            improve.append(k)
    improve.append("martial-cognize")
    lines.append("      improve_skills = [%s]" % ", ".join(q(k) for k in improve))
    lines.append("    } }")
    return "\n".join(lines) + "\n"


def build_inquiries(block):
    lines = ["  inquiries = ["]
    entries = [build_grant(*args).rstrip("\n") for args in block["grants"]]
    for idx, entry in enumerate(entries):
        lines.append(entry + ("," if idx < len(entries) - 1 or block.get("huanling") else ""))
    if block.get("huanling"):
        lines.extend([
            '    { key = "幻灵剑" value = {',
            '      kind = "give_item"',
            '      item = "clone_lib:huanlingjian"',
            '      match = "huanlingjian"',
            '      unique = false',
            '      family = "明教"',
            '      master_id = true',
            '      min_skill_levels = {',
            '        xiaoyao_jian = 120',
            '      }',
            '      min_shen = 80000',
            '      min_shen_deny = "你目前所做的侠义正事不够，这幻灵剑暂时还不能交给你。"',
            '      min_skill_deny = "你的逍遥剑法火候未到，就算拿着幻灵剑也没用。"',
            '      master_deny = "只有我的弟子才配使用幻灵剑，你还是走吧。"',
            '      family_deny = "与我明教素无渊源，不知此话从何说起。"',
            '      success = "既然这样，那这柄幻灵剑你就拿去吧。"',
            '    } }',
        ])
    lines.append("  ]")
    return "\n".join(lines) + "\n"


def build_coagents(block):
    if not block["co"]:
        return ""
    lines = ["  coagents = ["]
    for idx, ident in enumerate(block["co"]):
        lines.append('    { id = %s startroom = "mingjiao:dadian" }%s' %
                     (q(ident), "," if idx < len(block["co"]) - 1 else ""))
    lines.append("  ]")
    return "\n".join(lines) + "\n"


def build_chat(block):
    chance, msgs = block["chat"]
    return ("  chat_chance_combat = %d\n  chat_msg_combat = [%s]\n" %
            (chance, ", ".join(q(m) for m in msgs)))


def insert_before_close(text, key, payload):
    marker = 'characters "%s" {' % key
    i = text.find(marker)
    if i < 0:
        raise SystemExit("missing block %s" % key)
    j = text.find("\n    }\n", i)
    if j < 0:
        raise SystemExit("missing close for %s" % key)
    if "#933 mingjiao backfill" in text[i:j]:
        print("  SKIP %s (already backfilled)" % key)
        return text
    print("  INSERT %s" % key)
    return text[:j] + "\n" + payload.rstrip("\n") + text[j:]


def append_to_inquiries(text, key, grant_text):
    if 'perform_id = "shenghuo-ling/xi"' in text:
        print("  SKIP %s grants (already backfilled)" % key)
        return text
    marker = 'characters "%s" {' % key
    i = text.find(marker)
    close = text.find("\n    }\n", i)
    block = text[i:close]
    # build_inquiries 生成完整数组；追加到既有 inquiries 时只取中间的条目行。
    lines = grant_text.rstrip("\n").split("\n")
    entries = "\n".join(lines[1:-1])
    anchor = '    { key = "金毛狮王" value = "那是我义父谢大侠的职司。" }\n  ]'
    if anchor not in block:
        raise SystemExit("missing inquiry anchor for %s" % key)
    new_block = block.replace(anchor,
                              '    { key = "金毛狮王" value = "那是我义父谢大侠的职司。" },\n' +
                              entries + "\n  ]", 1)
    return text[:i] + new_block + text[close:]


XIAOZHAO_INQUIRIES = """  inquiries = [
    { key = "张无忌" value = "小昭幽幽地说：天涯思君不可忘，东西永隔如参商。" },
    { key = "wuji" value = "小昭幽幽地说：天涯思君不可忘，东西永隔如参商。" },
    { key = "倚天剑" value = "我不知道在哪里...别问我。" },
    { key = "jian" value = "我不知道在哪里...别问我。" },
    { key = "黄金" value = "不行啊，这不能随便给人。" },
    { key = "gold" value = "不行啊，这不能随便给人。" },
    { key = "歌" value = "小昭曼声唱道：世情推物理  人生贵适意 想人间造物搬兴废  吉藏凶 凶藏吉  富贵那能长富贵 日盈昃  月满亏蚀  地下东南  天高西北  天地尚无完体 展放愁眉  休争闲气  今日容颜  老于昨日  古往今来  尽须如此 管他贤的愚的  贫的和富的  到头这一身  难逃那一日 受用了一朝  一朝便宜 百岁光阴  七十者稀  急急流年  滔滔逝水" },
    { key = "ge" value = "小昭曼声唱道：世情推物理  人生贵适意 想人间造物搬兴废  吉藏凶 凶藏吉  富贵那能长富贵 日盈昃  月满亏蚀  地下东南  天高西北  天地尚无完体 展放愁眉  休争闲气  今日容颜  老于昨日  古往今来  尽须如此 管他贤的愚的  贫的和富的  到头这一身  难逃那一日 受用了一朝  一朝便宜 百岁光阴  七十者稀  急急流年  滔滔逝水" },
    { key = "乾坤大挪移" value = "自上代教主阳顶天离奇失踪，乾坤大挪移心法已经失落很久了。后来张公子才在密道里面找了回来。" },
    { key = "乾坤大挪移心法" value = "自上代教主阳顶天离奇失踪，乾坤大挪移心法已经失落很久了。后来张公子才在密道里面找了回来。" }
  ]"""


def backfill_xiaozhao(text):
    marker = 'characters "mingjiao_xiaozhao" {'
    i = text.find(marker)
    close = text.find("\n    }\n", i)
    block = text[i:close]
    if "小昭幽幽地说：天涯思君不可忘" in block:
        print("  SKIP mingjiao_xiaozhao (already backfilled)")
        return text
    old_start = block.find("  inquiries = [")
    old_end = block.find("\n  ]", old_start) + len("\n  ]")
    new_block = (block[:old_start] + XIAOZHAO_INQUIRIES + block[old_end:])
    # coagents：LPC xiaozhao.c:93 —— zhang wuji / mingjiao:dadian
    add = ("\n  #933 mingjiao backfill\n" +
           '  coagents = [\n    { id = "zhang wuji" startroom = "mingjiao:dadian" }\n  ]\n')
    new_block = new_block.rstrip("\n") + "\n" + add
    print("  INSERT mingjiao_xiaozhao")
    return text[:i] + new_block + text[close:]


def main():
    text = TARGET.read_text(encoding="utf-8")
    for key, block in MASTERS.items():
        if key == "mingjiao_zhangwuji":
            continue
        payload = ("  #933 mingjiao backfill\n" + build_teach(block) + "\n" +
                   build_apprentice(block) + "\n" + build_inquiries(block) + "\n" +
                   build_coagents(block) + "\n" + build_chat(block))
        text = insert_before_close(text, key, payload)

    zw = MASTERS["mingjiao_zhangwuji"]
    payload = ("  #933 mingjiao backfill\n" + build_teach(zw) + "\n" +
               build_apprentice(zw) + "\n" + build_coagents(zw) + "\n" +
               build_chat(zw))
    text = insert_before_close(text, "mingjiao_zhangwuji", payload)
    text = append_to_inquiries(text, "mingjiao_zhangwuji", build_inquiries(zw))

    # 范遥（非师父）：coagents + 战斗闲聊。
    fy = {
        "co": ["zhang wuji"],
        "chat": (120, ["prepare finger.nianhua-zhi", "prepare strike.sanhua-zhang"]),
    }
    text = insert_before_close(text, "mingjiao_fanyao",
                               "  #933 mingjiao backfill\n" +
                               build_coagents(fy) + "\n" + build_chat(fy))

    text = backfill_xiaozhao(text)

    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print("WROTE", TARGET)


if __name__ == "__main__":
    main()
