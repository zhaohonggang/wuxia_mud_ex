from pathlib import Path

ROOT = Path("C:/files/git/wuxia_mud_ex")
CLONE = ROOT / "data/world/clone_lib.ucl"
ZONE = ROOT / "data/world/tiezhang.ucl"

CN = {
    "tiexue-dao": "铁血刀法",
    "chuanxin-zhang": "穿心掌",
    "tiexian-quan": "铁线拳",
    "tie-zhang": "铁掌",
    "tianlei-dao": "天雷绝刀",
    "tongbi-zhang": "通臂六合掌",
    "guyue-chan": "孤月铲法",
    "feilong-zhang": "飞龙掌",
}

# name, perform_id, skill, skill_lv, force, dodge, max_neili, gongxian, shen, msg_one
GRANTS = {
    "tiezhang_fen": [
        ("血浪滔天", "tiexue-dao/xue", "tiexue-dao", 100, 60, None, None, 60, -15000, None),
        ("穿心锥", "chuanxin-zhang/zhui", "chuanxin-zhang", 100, 150, 220, 200, 200, -18000, None),
        ("破甲推山", "tiexian-quan/tui", "tiexian-quan", 100, 90, None, 400, 260, -23000, None),
    ],
    "tiezhang_qiuqianren": [
        ("掌心雷", "tie-zhang/lei", "tie-zhang", 160, 220, None, 2200, 600, -65000,
         "$N投以赞许的一笑，说道：“看好了！”随即只见$N猛催内力，双掌登时变得火红，你正惊诧之际$N双掌幻为一对掌刀凌空劈斩而出，只听「喀嚓」一声，大厅内一张青石桌应声而碎！"),
        ("九穹绝刹掌", "tie-zhang/juesha", "tie-zhang", 200, 300, None, 2200, 800, -85000,
         "$N默默注视了你良久，说道：“既然如此，今日我便传你这招！我只演示一遍，你可要看仔细了！”说完一声怒喝，体内所积存数十载的天雷真气澎湃而发，衣衫鼓动，双臂陡然暴长数尺。只听四周破空之声骤然响之，$N双掌幻出漫天掌影，铺天盖地向四面八方云涌而出，当真气势磅礴，无与伦比！"),
        ("龙影掌", "tie-zhang/long", "tie-zhang", 100, 80, None, 1300, 300, -60000, None),
        ("五指刀", "tie-zhang/dao", "tie-zhang", 180, 260, None, 2500, 700, -90000, None),
        ("阴阳磨", "tie-zhang/yin", "tie-zhang", 220, 300, None, 3500, 900, -95000, None),
        ("春雷炸空", "tianlei-dao/zha", "tianlei-dao", 150, 140, None, 1500, 600, -75000, None),
        ("五雷连闪", "tianlei-dao/shan", "tianlei-dao", 150, 150, None, 1500, 600, -75000, None),
    ],
    "tiezhang_qiuqianzhang": [
        ("孤雁出群", "tongbi-zhang/chu", "tongbi-zhang", 80, 40, None, None, 60, -5000, None),
        ("皓月惊空", "guyue-chan/jing", "guyue-chan", 80, 40, None, None, 80, -8000, None),
        ("龙飞势", "feilong-zhang/fei", "feilong-zhang", 160, 240, None, 2500, 400, -20000, None),
    ],
}

TEACH_SKILLS = {
    "tiezhang_fen": [
        ("force", 180), ("tiezhang_xinfa", 200), ("dodge", 200), ("dengping_dushui", 200),
        ("strike", 200), ("parry", 200), ("chuanxin_zhang", 200), ("tongbi_zhang", 200),
        ("cuff", 180), ("tiexian_quan", 180), ("unarmed", 180), ("tiexue_dao", 180),
        ("blade", 180), ("literate", 160), ("martial_cognize", 160),
    ],
    "tiezhang_qiuqianren": [
        ("force", 280), ("tiezhang_xinfa", 280), ("tianlei_shengong", 280), ("dodge", 320),
        ("dengping_dushui", 320), ("strike", 320), ("parry", 280), ("tie_zhang", 320),
        ("chuanxin_zhang", 280), ("cuff", 280), ("tiexian_quan", 280), ("unarmed", 280),
        ("feilong_zhang", 260), ("staff", 260), ("blade", 260), ("tianlei_dao", 260),
        ("literate", 200), ("martial_cognize", 200),
    ],
    "tiezhang_qiuqianzhang": [
        ("force", 100), ("tiezhang_xinfa", 100), ("dodge", 120), ("lingxu_bu", 120),
        ("strike", 120), ("parry", 120), ("tongbi_zhang", 120), ("tie_zhang", 120),
        ("chuanxin_zhang", 120), ("feilong_zhang", 120), ("guyue_chan", 120),
        ("staff", 100), ("literate", 80), ("martial_cognize", 80),
    ],
}

COMBAT_CHAT = ["strike.juesha", "strike.lei", "strike.yin", "cuff.kai", "unarmed.zhui", "recover", "powerup"]
FEN_CHAT = ["blade.xue", "cuff.kai", "unarmed.zhui", "recover", "powerup"]
ZHANG_CHAT = ["strike.chu", "cuff.jia", "staff.fei", "recover"]

APPRENTICE = {
    "tiezhang_fen": """
  apprentice = {
    family = "铁掌帮"
    permit_recruit = true
    allow_families = [ "绝情谷" ]
    allow_master_name = "裘千尺"
    defer_family = "绝情谷"
    defer_master_name = "裘千尺"
    defer_mark = "绝情谷--铁掌帮"
    defer_msg = "原来阁下是裘千尺师叔的后裔，想来你和本帮有极深的渊源。这个事情我做不了主，你还是直接去找帮主吧。"
    no_min_shen = true
    max_shen = -10000
    max_shen_deny = "你这样心慈手软可不行。"
    min_exp = 140000
    min_exp_deny = "你这点能力怎能成大器，还是练练再来吧！"
    min_skills = { force = 60 strike = 40 }
    recruit_skill_order = [ "force", "strike" ]
    min_skills_deny = {
      force = "学武之人最讲究内功精纯，我看你下的工夫还不够呀。"
      strike = "入帮之后连最基本的掌法都没练好，那你入铁掌帮作甚？"
    }
    accept_msg = "既然这样，我便收下你，希望你苦练本帮神功，将之发扬光大。"
  }
""",
    "tiezhang_qiuqianren": """
  apprentice = {
    family = "铁掌帮"
    permit_recruit = true
    allow_families = [ "绝情谷" ]
    allow_master_name = "裘千尺"
    defer_family = "绝情谷"
    defer_master_name = "裘千尺"
    defer_mark = "绝情谷--铁掌帮"
    defer_msg = "原来是三妹的后裔，这样也好，我们本来就是一家人。且让我先看看你的能力。"
    defer_continue = true
    delete_mark_on_accept = true
    no_min_shen = true
    max_shen = -60000
    max_shen_deny = "我裘千仞可不收心慈手软的人做徒弟。"
    min_exp = 500000
    min_exp_deny = "你这点能力怎能继承我的衣钵？"
    min_skills = { force = 220 strike = 160 }
    recruit_skill_order = [ "force", "strike" ]
    min_skills_deny = {
      force = "要学我的铁掌绝技，内功非精纯不可，你还是先多练练吧。"
      strike = "要学我的铁掌绝技，需要精湛的掌法作基础，我看你在那上面下的工夫还不够啊。"
    }
    accept_msg = "不错，不错！我就收下你了，希望你苦练铁掌神功，将之发扬光大。公孙止那老家伙不是个东西，你以后还是跟我学习铁掌帮的功夫吧。"
  }
""",
    "tiezhang_qiuqianzhang": """
  apprentice = {
    family = "铁掌帮"
    permit_recruit = true
    allow_families = [ "绝情谷" ]
    allow_master_name = "裘千尺"
    defer_family = "绝情谷"
    defer_master_name = "裘千尺"
    defer_mark = "绝情谷--铁掌帮"
    defer_msg = "我道是谁，原来是三妹的弟子，我们本来就是一家人。这个事情我做不了主，你还是去找二弟吧。"
    defer_continue = true
    no_min_shen = true
    max_shen = 0
    max_shen_deny = "他妈的！爷爷我最恨你这样心慈手软的小王八蛋！。"
    accept_msg = "爷爷我武功盖世，你这娃娃好好跟着我学，准没错！"
  }
""",
}


def teach_block(key):
    lines = ["\n  teach = {", '    family = "铁掌帮"', "    teach_skills = {"]
    for skill, level in TEACH_SKILLS[key]:
        lines.extend([f"      {skill} = {{", "        max = %d" % level, "        gongxian = 0", "      }"])
    lines.append("    }")
    if key == "tiezhang_qiuqianzhang":
        lines.extend([
            "    no_teach = {",
            '      tie_zhang = "嘿嘿嘿，这玩意不厉害，我的通臂六合掌才是武林绝学，你还是用心练这个吧。"',
            "    }",
        ])
    lines.append("  }\n")
    return "\n".join(lines)


def grant_block(row):
    name, perform, skill, level, force, dodge, neili, gongxian, shen, msg = row
    cn = CN[skill]
    levels = [(skill.replace("-", "_"), level), ("force", force)]
    order = [skill, "force"]
    if dodge:
        levels.append(("dodge", dodge))
        order.append("dodge")
    if neili:
        levels.append(("max_neili", neili))
        order.append("max-neili")
    lines = ["    { key = \"%s\" value = {" % name,
             '      kind = "sect_master_grant"',
             '      perform_id = "%s"' % perform,
             '      skill = "%s"' % skill,
             '      gate_order = "lpc_masterd"',
             '      family = "铁掌帮"',
             "      min_levels = {"]
    for key, value in levels:
        lines.append("        %s = %d" % (key, value))
    lines.append("      }")
    lines.append("      level_order = [ %s ]" % " ".join('"%s"' % x for x in order))
    lines.append("      level_deny = {")
    lines.append('        %s = "你对%s的了解还不够，尚且无法领悟此招。"' % (skill.replace("-", "_"), cn))
    lines.append('        force = "你目前的内功火候不足，下去练练再来吧。"')
    if dodge:
        lines.append('        dodge = "你目前的轻功火候不足，下去练练再来吧。"')
    if neili:
        lines.append('        max_neili = "你现在的内力修为不足，修炼高点再来吧。"')
    lines.append("      }")
    lines.append("      min_gongxian = %d" % gongxian)
    lines.append("      cost_gongxian = %d" % gongxian)
    lines.append("      max_shen = %d" % shen)
    lines.append('      max_shen_deny = "哼！像你这样的心慈手软之辈，又能干成什么大事？"')
    lines.append('      gongxian_deny = "你为铁掌帮作出的贡献不够，这招暂时还不能传你。"')
    lines.append('      skill_deny = "你连%s都未曾学过，何谈绝招可言？"' % cn)
    lines.append('      family_deny = "大侠与我铁掌帮素无渊源，不知此话从何说起。"')
    lines.append('      maxed = "这招你不是已经会了么，还缠着我做甚？"')
    if msg:
        lines.append('      msg_one = "%s"' % msg)
    lines.append('      learned = "你学会了「%s」。"' % name)
    lines.append("    } },")
    return "\n".join(lines)


def slice_bounds(text, key):
    marker = 'characters "%s" {' % key
    start = text.index(marker)
    nxt = text.find("\n# LPC:", start)
    if nxt < 0:
        nxt = len(text)
    return start, nxt


def insert_after(text, anchor, addition, start, end):
    pos = text.index(anchor, start, end) + len(anchor)
    return text[:pos] + addition + text[pos:]


def main():
    text = CLONE.read_text(encoding="utf-8")

    for key in ["tiezhang_fen", "tiezhang_qiuqianren", "tiezhang_qiuqianzhang"]:
        start, end = slice_bounds(text, key)
        block = text[start:end]

        # teach + apprentice after score line
        score_anchor = "\n  score = 40000"
        assert score_anchor in block, key
        block = insert_after(block, score_anchor, "\n" + teach_block(key) + APPRENTICE[key], 0, len(block))

        # combat chatter + grants before carry (or at end if no carry)
        chats = FEN_CHAT if key == "tiezhang_fen" else (ZHANG_CHAT if key == "tiezhang_qiuqianzhang" else COMBAT_CHAT)
        chat_text = "\n  chat_chance_combat = 120\n  chat_msg_combat = [\n" + \
                    "\n".join('    "%s",' % c for c in chats[:-1]) + "\n" + \
                    '    "%s"\n  ]\n' % chats[-1]
        grants = "\n".join(grant_block(row) for row in GRANTS[key])
        if key == "tiezhang_fen":
            insert = "\n  inquiries = [\n" + grants + "\n  ]\n" + chat_text
            carry = "\n\n  carry = ["
            assert carry in block
            block = block.replace(carry, "\n" + insert + carry, 1)
        else:
            # append grants into existing inquiries list, before its closing "  ]"
            inq_start = block.index("\n  inquiries = [")
            inq_end = block.index("\n  ]", inq_start)
            if key == "tiezhang_qiuqianren":
                extra = "\n" + grants + "\n" + \
                        '    { key = "历练" value = " inquire about 历练 (unimplemented: GAP #927)" },' + \
                        '\n    { key = "历炼" value = " inquire about 历炼 (unimplemented: GAP #927)" },' + \
                        '\n    { key = "锻炼" value = " inquire about 锻炼 (unimplemented: GAP #927)" }'
            else:
                extra = "\n" + grants
            block = block[:inq_end] + extra + block[inq_end:]
            carry = "\n\n  carry = ["
            assert carry in block
            block = block.replace(carry, "\n" + chat_text + carry, 1)

        if key == "tiezhang_qiuqianzhang":
            old = 'msg = "啊哟，糟糕，糟糕，这会儿当真不凑巧！你等一会，我肚子痛，要出恭！"'
            new = 'msg = "大侠怕是活腻了，来来来，让爷爷教训教训你！啊哟，糟糕，糟糕，这会儿当真不凑巧！你等一会，我肚子痛，要出恭！"'
            assert old in block
            block = block.replace(old, new, 1)

        text = text[:start] + block + text[end:]

    CLONE.write_text(text, encoding="utf-8")

    # ---- tiezhang.ucl: 顾炎武 ----
    zt = ZONE.read_text(encoding="utf-8")
    gu_start = zt.index('characters "gu" {')
    gu_end = zt.index("\n# Generated from", gu_start)
    gu = zt[gu_start:gu_end]

    replacements = [
        ('{ key = "岳武穆" value = " inquire about wumu (unimplemented)" },',
         '{ key = "岳武穆" value = "岳武穆名飞字鹏举，乃抗金的名将，一生用兵如神。据说他死后留下了一部武穆遗书，其中记载着他一生戎马生涯的兵法要诀。" },'),
        ('{ key = "武穆遗书" value = " inquire about yishu (unimplemented)" },',
         '{ key = "武穆遗书" value = "这部遗书最早收藏在皇宫之中，后听说铁掌帮帮主上官剑南率帮中高手，将此书偷走，不知是真是假。" },'),
        ('{ key = "上官剑南" value = " inquire about jiannan (unimplemented)" },',
         '{ key = "上官剑南" value = {\n'
         '      kind = "give_item"\n'
         '      item = "tiezhang:zitie"\n'
         '      match = "zitie"\n'
         '      unique = true\n'
         '      vision_name = "顾炎武"\n'
         '      success = "看来大侠也是我辈中人，老朽这里有一幅字帖送给你，希望能不忘驱除胡虏，还我河山的志向！"\n'
         '      already = "我不是已经告诉你了么，怎么还问？"\n'
         '    } },'),
    ]
    for old, new in replacements:
        assert old in gu, old
        gu = gu.replace(old, new, 1)

    teach_gu = """

  teach = {
    teach_skills = {
      literate = {
        max = 200
        gongxian = 0
      }
    }
  }
"""
    combat_anchor = "\n  combat = {\n    combat_exp = 500\n  }"
    assert combat_anchor in gu
    gu = gu.replace(combat_anchor, "\n  combat = {\n    combat_exp = 500\n    apply = { attack = 10 defense = 10 damage = 5 }\n  }" + teach_gu, 1)

    zt = zt[:gu_start] + gu + zt[gu_end:]
    ZONE.write_text(zt, encoding="utf-8")

    print("tiezhang UCL backfill done")


if __name__ == "__main__":
    main()
