#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-shot UCL backfill for meizhuang (梅庄) teaching data (Task #870).

Authority: C:/files/git/mud/kungfu/class/meizhuang/{danqing,ding,heibai,huang,tubi}.c
and meizhuang.h. Only inserts new assignments into the five meizhuang_*
character blocks; strictly asserts every existing combat { ... } block stays
byte-identical. Replaces the 14 ask_skill / ask_riyue unimplemented inquiry
placeholders; keeps the 3 item placeholders annotated with GAP ids.

NOTE: one-shot. Do not treat as a repeatable migration tool.
"""
import os
import re

UCL = 'data/world/clone_lib.ucl'
LPC = r'C:\files\git\mud\kungfu\class\meizhuang'

FAMILY = '梅庄'
PERMIT = {
    'betray_sect_deny': '你当年既然已经离开本庄，现在何必又要回来？',
    'betray_times_deny': '我梅庄虽小，但是也不会接纳你这样的背信弃义之徒！',
    'other_family_deny': '你既然已经有了名师指点，还来我们梅庄干嘛？',
}

EXP_DENY = '你的江湖经验太浅，还是先多锻炼锻炼再说吧。'
OR_DENY = '你连本门的内功都没学好，我收你做甚？'
DEFER_PARTY = {
    'danqing': '我道是谁，原来是东方教主的弟子。\n这件事我不便插手，你去找我大哥、二哥好了。',
    'ding': '原来是东方教主的弟子，兴会，兴会！\n这件事非同小可，我做不了主，你还是去找几位庄主吧。',
    'heibai': '原来是东方教主的弟子，收你…这个倒没什么问题。\n但是在收你之前，我得先考察一下你的能力。',
    'huang': '原来是东方教主的弟子，收你…这个倒没什么问题。\n但是在收你之前，我得先考察一下你的能力。',
    'tubi': '我道是谁，原来是东方教主的弟子。\n这件事我不便插手，你去找我大哥、二哥好了。',
}
ACCEPT_PARTY = '不错，不错！我就收下你了，不过千万别招惹是非，给我梅庄添乱。\n现在你成为我梅庄中人，望你专心练武，别再去过问教中事物。'

# NPC -> dict of apprentice specifics
APPR = {
    'danqing': {
        'exp': 50000, 'exp_deny': EXP_DENY, 'any': ('wuzheng_xinfa', 'xuantian_wujigong', 80),
        'any_deny': OR_DENY,
    },
    'ding': {
        'min_shen': -1000, 'max_shen': 1000,
        'min_shen_deny': '我们孤山梅庄向来不问江湖事，更不会结交名声不好之人。',
        'max_shen_deny': '我们孤山梅庄向来不问江湖事，也不结交你这样的侠义之士。',
    },
    'heibai': {
        'exp': 200000, 'exp_deny': EXP_DENY,
        'min_skills': [('force', 120)],
        'skill_deny': {'force': '你内功火候太差，就算收下你，也不会有什么出息。'},
        'order': ['force'],
    },
    'huang': {
        'exp': 400000, 'exp_deny': EXP_DENY,
        'min_skills': [('force', 180), ('sword', 100), ('unarmed', 100)],
        'skill_deny': {
            'force': '学我七弦无形剑，内功非精纯不可，你还是先多练练吧。',
            'sword': '如要学我七弦无形剑，你还得在剑法上多下工夫。',
            'unarmed': '如要学我七弦无形剑，你还得在拳脚上多下工夫。',
        },
        'order': ['force', 'sword', 'unarmed'],
    },
    'tubi': {
        'exp': 50000, 'exp_deny': EXP_DENY, 'any': ('wuzheng_xinfa', 'xuantian_wujigong', 80),
        'any_deny': OR_DENY,
    },
}

NO_TEACH = {
    'huang': {
        'longzhua_gong': '龙爪功乃昔日方证大师所授的少林绝学，老夫略之一二，并不授教。'
    },
}

CN = {
    'pomopima-jian': '泼墨披麻剑',
    'jidian-jian': '疾电剑法',
    'fenglei-zifa': '风雷子法',
    'fenglei-panfa': '风雷盘法',
    'xuantian-wujigong': '玄天无极功',
    'xuantian-zhi': '玄天指',
    'qixian-wuxingjian': '七弦无形剑',
    'tanqin-jifa': '琴技',
    'shigu-bifa': '石鼓打穴笔法',
}

MAXED = '我已经教过你了，自己下去练，别老是跟我纠缠不休。'
GX_DENY = '你对本庄所作出的贡献不够，这一招我暂时还不能传你。'
FAMILY_DENY = '大侠和本教素无瓜葛，何出此言？'
FORCE_DENY = '你的内功火候尚不精纯，学不了这一招。'

# (npc, key, perform, skill, gx, levels(list of (skill,min)), level_deny(map), msg, learned, improve)
GRANTS = [
    ('danqing', '醉里乾坤', 'pomopima-jian/zui', 'pomopima-jian', 300,
     [('pomopima-jian', 120), ('force', 150)],
     {'pomopima_jian': '你的泼墨披麻剑还练得不到家，自己下去练练再来吧！',
      'force': FORCE_DENY},
     '$N哈哈一笑，举起手中酒杯一口饮干，说道：好，今日老夫便传你这招！\n'
     '$N说完左掌猛力拍落，一股掌力击在地下，“蓬”的一声响，身子向后\n'
     '跃起，已在丈许之外。只见他尚未站定，长剑已在身前连划三个圆圈，幻作\n'
     '三个光圈。三个光圈便如是有形之物，凝在空中停得片刻，缓缓向$n身前移\n'
     '去。这几个剑气化成的光圈骤视之似不及一字电剑的凌厉，但剑气满室，寒\n'
     '风袭体。直看得$n目瞪口呆。\n',
     '你学会了「醉里乾坤」。',
     ['sword', 'pomopima-jian', 'martial-cognize']),

    ('ding', '电光四射', 'jidian-jian/dian', 'jidian-jian', 50,
     [('jidian-jian', 100), ('force', 150)],
     {'jidian_jian': '你的疾电剑法还练得不到家，自己下去练练再来吧！',
      'force': '你的内功火候尚不精纯，是学不会这招的。'},
     '$N点了点头，说道：这疾电剑法的电光四射其实是慑人声势使其无所施其\n'
     '技，我这里给你演示一遍，你可看好了。$N说完手中长剑一抖，将这套剑\n'
     '法施展出来，霎时之间，满室都是电光，耀人眼目。$n看后双目一亮，顿时\n'
     '大有所悟。\n',
     '你学会了「电光四射」。',
     ['sword', 'jidian-jian', 'martial-cognize']),

    ('heibai', '射日诀', 'fenglei-zifa/she', 'fenglei-zifa', 300,
     [('fenglei-zifa', 100)],
     {'fenglei_zifa': '你的风雷子法还练得不到家，自己下去练练再来吧！'},
     '$N微微一笑，随手拈起一颗棋子，“飕”的弹射了出去。$n只觉眼前一花，那颗棋子正好打\n'
     '在自己脚跟前的青砖上，没入半尺之深。\n',
     '你学会了「射日诀」。',
     ['throwing', 'fenglei-zifa', 'martial-cognize']),

    ('heibai', '风雷四击', 'fenglei-panfa/fenglei', 'fenglei-panfa', 1000,
     [('force', 200), ('fenglei-panfa', 150)],
     {'force': FORCE_DENY,
      'fenglei_panfa': '你的风雷盘法还练得不到家，自己下去练练再来吧！'},
     '$N点了点头，将$n招至身边，在耳旁低声细说良久，$n听了半天，忽然说道：“我明白了，所谓四\n'
     '击便是抬手似疾风、起势如骤雨、出招若雷鸣、收势如电闪。”\n',
     '你学会了「风雷四击」。',
     ['force', 'hammer', 'fenglei-panfa', 'martial-cognize']),

    ('heibai', '冰坚地狱', 'xuantian-zhi/bing', 'xuantian-zhi', 1500,
     [('xuantian-wujigong', 180), ('xuantian-zhi', 180)],
     {'xuantian_wujigong': '你的玄天无极功火候不够，学不了这一招。',
      'xuantian_zhi': '你的玄天指还练得不到家，自己下去练练再来吧！'},
     '$N点了点头，默运玄天无极功，伸出右手食指，插入桌上的花瓶\n'
     '中。片刻间花瓶水面便浮起一丝丝白气，过不多时，瓶口上起了一层\n'
     '白箱，跟着水面结成一片片薄冰，冰越结越厚，只一盏茶时分，整个\n'
     '花瓶内的清水都化成了寒冰。\n',
     '你学会了「冰坚地狱」这一招。',
     ['force', 'xuantian-wujigong', 'finger', 'xuantian-zhi', 'martial-cognize']),

    ('huang', '七弦无形音', 'qixian-wuxingjian/yin', 'qixian-wuxingjian', 500,
     [('force', 250), ('qixian-wuxingjian', 160), ('tanqin-jifa', 120)],
     {'force': '你的内功火候不足，学不了这一招！',
      'qixian_wuxingjian': '你的七弦无形剑还练得不到家，自己下去练练再来吧。',
      'tanqin_jifa': '你的琴技还不够娴熟，运用不了这一招。'},
     '$N微微一笑，转身从书架上取出一本\n琴谱，指着其中一段对$n细说\n良久，$N一边听一边点头。\n',
     '你学会了「七弦无形音」。',
     ['unarmed', 'sword', 'force', 'qixian-wuxingjian', 'martial-cognize']),

    ('huang', '七弦黄龙闪', 'qixian-wuxingjian/shan', 'qixian-wuxingjian', 500,
     [('force', 250), ('qixian-wuxingjian', 160), ('tanqin-jifa', 120)],
     {'force': '你的内功火候不足，学不了这一招！',
      'qixian_wuxingjian': '你的七弦无形剑还练得不到家，自己下去练练再来吧！',
      'tanqin_jifa': '你的琴技还不够娴熟，运用不了这一招。'},
     '$N点了点头，将$n招至\n身边，在耳旁低声细说良久，$n听后会的\n一笑，看来大有所悟。\n',
     '你学会了「七弦黄龙闪」。',
     ['unarmed', 'sword', 'force', 'qixian-wuxingjian', 'martial-cognize']),

    ('huang', '七弦连环诛', 'qixian-wuxingjian/zhu', 'qixian-wuxingjian', 2000,
     [('force', 300), ('qixian-wuxingjian', 180), ('tanqin-jifa', 150)],
     {'force': '你的内功火候不足，学不了这一招！',
      'qixian_wuxingjian': '你的七弦无形剑还练得不到家，自己下去练练再来吧！',
      'tanqin_jifa': '你的琴技还不够娴熟，运用不了这一招。'},
     '$N微微一笑，也不答话，转身怀抱手中\n瑶琴，放至身前，轻轻拂弄。顿时琴声\n四起，时缓\n时急，忽尔悄然无声，忽尔铮然大响，过了一会，琴\n声越弹越急。$n只\n听得心神不定，呼吸不舒\n，便在此时，琴音铮铮大响，琴音响一声，$n\n便退出一步，\n琴音连响五下，便不由自主的退了五\n步。$n脸色雪白，定了定神，才道：“师父这\n无形剑法当真厉害。这六音连续狠打猛击，江湖中\n又有谁能抵受得了？”$N听\n后哈哈一笑。\n',
     '你学会了「七弦连环诛」。',
     ['unarmed', 'sword', 'force', 'qixian-wuxingjian', 'martial-cognize']),

    ('tubi', '神笔封穴', 'shigu-bifa/feng', 'shigu-bifa', 300,
     [('calligraphy', 100), ('shigu-bifa', 100), ('force', 150)],
     {'calligraphy': '嘿，你连字都写不好，还谈什么笔法？',
      'shigu_bifa': '你的石鼓打穴笔法还练得不到家，自己下去练练再来吧！',
      'force': '你的内功火候尚不精纯，学不了，学不了。'},
     '$N哈哈一笑，说道：不错，不错，孺子可\n教也。今天我就传你这招。\n$N说完便将$n\n招至身前，嘀嘀咕咕说了半天。\n',
     '你学会了「神笔封穴」。',
     ['dagger', 'shigu-bifa', 'martial-cognize']),

    ('tubi', '诗意纵横', 'shigu-bifa/shiyi', 'shigu-bifa', 300,
     [('calligraphy', 100), ('shigu-bifa', 100), ('force', 150)],
     {'calligraphy': '嘿，你连字都写不好，还谈什么笔法？',
      'shigu_bifa': '你的石鼓打穴笔法还练得不到家，自己下去练练再来吧！',
      'force': '你的内功火候尚不精纯，学不了，学不了。'},
     '$N点了点头，说道：这一套笔法乃是从颜真\n卿所书诗帖中变化出来\n的，一共二十三字，每字三招至十六招不等，你可听好了。只听$N\n摇头晃脑的\n念道：裴将军！大君制六合，猛将清九垓。战马若龙虎，腾\n陵何壮哉……\n',
     '你学会了「诗意纵横」。',
     ['dagger', 'shigu-bifa', 'martial-cognize']),
]

# NPC -> riyue config
RIYUE = {
    'danqing': ('pomopima-jian', '泼墨披麻剑', ['pomopima-jian/zui']),
    'heibai': ('fenglei-panfa', '风雷盘法', ['fenglei-panfa/fenglei']),
    'huang': ('qixian-wuxingjian', '七弦无形剑',
              ['qixian-wuxingjian/yin', 'qixian-wuxingjian/shan', 'qixian-wuxingjian/zhu']),
    'tubi': ('shigu-bifa', '石鼓打穴笔法', ['shigu-bifa/feng', 'shigu-bifa/shiyi']),
}

GAP_ITEM = {
    'heibai': {'玄铁棋盘': ' inquire about qipan (unimplemented: GAP #875)'},
    'huang': {
        '绿玉洞箫': ' inquire about xiao (unimplemented: GAP #876)',
        '白玉瑶琴': ' inquire about qin (unimplemented: GAP #876)',
    },
}


def read_lpc(name):
    return open(os.path.join(LPC, name + '.c'), encoding='utf-8', errors='replace').read()


def set_skills(text):
    # 只取 create() 里的 NPC 初始技能；排除 ask_riyue 里 me->set_skill(...,10) 的访客授艺。
    return [(s, int(v)) for s, v in
            re.findall(r'(?<!me->)set_skill\("([^"]+)"\s*,\s*(\d+)\)', text)]


def q(s):
    # 脚本里的 '\n' 是真换行；UCL 字符串必须写两字符 \n（见 UCL 语法参考 §6）
    s = s.replace('\n', '\\n')
    assert ';' not in s and '[' not in s and ']' not in s, s
    return '"' + s + '"'


def ukey(s):
    return s.replace('-', '_')


def teach_block(name):
    nt = NO_TEACH.get(name, {})
    # LPC set_skill 返回连字符 skill id；NO_TEACH 键用下划线，比较前须归一
    nt_norm = {ukey(k): v for k, v in nt.items()}
    lines = ['  teach = {', '    family = "' + FAMILY + '"', '    teach_skills = {']
    for skill, level in set_skills(read_lpc(name)):
        if ukey(skill) in nt_norm:
            continue
        lines.append(f'      {ukey(skill)} = {{ max = {level} gongxian = 0 }}')
    lines.append('    }')
    if nt:
        lines.append('    no_teach = {')
        for skill, reason in nt.items():
            lines.append(f'      {ukey(skill)} = {q(reason)}')
        lines.append('    }')
    lines.append('  }')
    return '\n'.join(lines)


def apprentice_block(name):
    spec = APPR[name]
    lines = ['  apprentice = {', '    family = "' + FAMILY + '"',
             '    permit_recruit = true', '    gate_order = "lpc_meizhuang"']
    for key, val in PERMIT.items():
        lines.append(f'    {key} = {q(val)}')

    # meizhuang.h 他派门例外
    lines.append('    allow_families = ["日月神教"]')
    lines.append('    allow_master_name = "东方不败"')

    # 东方不败弟子 move_party 分支
    lines += [
        '    defer_family = "日月神教"',
        '    defer_master_name = "东方不败"',
        '    defer_mark = "move_party/日月神教--梅庄"',
        '    defer_msg = ' + q(DEFER_PARTY[name]),
    ]
    if name in ('heibai', 'huang'):
        lines.append('    defer_continue = true')
        lines.append('    delete_mark_on_accept = true')
        lines.append('    accept_msg = ' + q(ACCEPT_PARTY))

    # 丁坚：双向侠义门
    if 'min_shen' in spec:
        lines += [
            f'    min_shen = {spec["min_shen"]}',
            f'    max_shen = {spec["max_shen"]}',
            '    min_shen_deny = ' + q(spec['min_shen_deny']),
            '    max_shen_deny = ' + q(spec['max_shen_deny']),
        ]
    else:
        # 丹青生/黑白子/黄钟公/秃笔翁 LPC 无侠义门；显式关闭缺省下界
        lines.append('    no_min_shen = true')

    if 'exp' in spec:
        lines += [
            f'    min_exp = {spec["exp"]}',
            '    min_exp_deny = ' + q(spec['exp_deny']),
        ]

    if 'any' in spec:
        a, b, lv = spec['any']
        lines += [
            '    any_min_skills = {',
            f'      {a} = {lv}',
            f'      {b} = {lv}',
            '    }',
            '    any_min_skills_deny = ' + q(spec['any_deny']),
        ]

    if 'min_skills' in spec:
        lines.append('    min_skills = {')
        for skill, lv in spec['min_skills']:
            lines.append(f'      {ukey(skill)} = {lv}')
        lines.append('    }')
        lines.append('    min_skills_deny = {')
        for skill, text in spec['skill_deny'].items():
            lines.append(f'      {ukey(skill)} = {q(text)}')
        lines.append('    }')
        lines.append('    recruit_skill_order = [' +
                     ', '.join(q(x) for x in spec['order']) + ']')

    lines.append('  }')
    return '\n'.join(lines)


def grant_map(g):
    npc, key, perform, skill, gx, levels, level_deny, msg, learned, improve = g
    lines = ['{ key = ' + q(key) + ' value = {',
             '  kind = "sect_master_grant"',
             '  perform_id = ' + q(perform),
             '  skill = ' + q(skill),
             '  family = "' + FAMILY + '"',
             '  gate_order = "lpc_meizhuang"',
             '  maxed = ' + q(MAXED),
             '  family_deny = ' + q(FAMILY_DENY),
             '  skill_deny = ' + q('你连' + CN[skill] + '都没学，何谈此言？'),
             '  gongxian_deny = ' + q(GX_DENY),
             f'  min_gongxian = {gx}',
             f'  cost_gongxian = {gx}',
             '  min_levels = {' + ' '.join(
                 f'{ukey(s)} = {lv}' for s, lv in levels) + ' }',
             '  level_order = [' + ', '.join(q(s) for s, _ in levels) + ']',
             '  level_deny = {' + ' '.join(
                 f'{ukey(s)} = {q(level_deny.get(ukey(s), level_deny.get(s, "")))}'
                 for s, _ in levels) + ' }',
             '  msg_one = ' + q(msg),
             '  improve_skills = [' + ', '.join(q(x) for x in improve) + ']',
             '  learned = ' + q(learned),
             '} }']
    return '\n'.join(lines)


def riyue_map(npc):
    skill, cn, performs = RIYUE[npc]
    lines = ['{ key = "日月神教" value = {',
             '  kind = "meizhuang_riyue"',
             '  skill = ' + q(skill),
             '  family = "日月神教"',
             '  granted_level = 10',
             '  learn_mark = "can_learn/meizhuang"',
             '  unlock_performs = [' + ', '.join(q(x) for x in performs) + ']',
             '  min_gongxian = 10000',
             '  cost_gongxian = 10000',
             '  min_bank_coins = 10000000000',
             '  cost_bank_coins = 10000000000',
             '  family_deny = "本庄只接待神教人士！"',
             '  maxed = "你不是已经会了吗？还来找我干什么！"',
             '  say_teach = ' + q('恩，那好吧，我就教你' + cn + '。'),
             '  say_close = "下去好好练习吧。"',
             '  learned = ' + q('你学会了' + cn + '！'),
             '} }']
    return '\n'.join(lines)


def inquiries_for(name):
    grants = [grant_map(g) for g in GRANTS if g[0] == name]
    if name in RIYUE:
        grants.append(riyue_map(name))
    return grants


def replace_placeholders(body, name):
    for key, value in [(g[1], grant_map(g)) for g in GRANTS if g[0] == name]:
        pat = re.compile(r'\{ key = "' + re.escape(key) + r'" value = "[^"]*\(unimplemented\)" \}')
        body, n = pat.subn(lambda _m: value, body, count=1)
        assert n == 1, (name, key, n)

    if name in RIYUE:
        pat = re.compile(r'\{ key = "日月神教" value = "[^"]*\(unimplemented\)" \}')
        body, n = pat.subn(lambda _m: riyue_map(name), body, count=1)
        assert n == 1, (name, '日月神教', n)

    for key, value in GAP_ITEM.get(name, {}).items():
        pat = re.compile(r'\{ key = "' + re.escape(key) + r'" value = "[^"]*\(unimplemented\)" \}')
        body, n = pat.subn(lambda _m: '{ key = "' + key + '" value = ' + q(value) + ' }',
                           body, count=1)
        if n == 1:
            continue
        # 已是 GAP 注解的旧值也接受（幂等）
        assert '(unimplemented: GAP #' in body, (name, key)
    return body


def insert_assignments(body, additions):
    m = re.search(r'\n  skills = \[', body)
    if not m:
        raise RuntimeError('no insertion anchor')
    return body[:m.start()] + '\n' + additions + '\n' + body[m.start() + 1:]


def main():
    text = open(UCL, encoding='utf-8').read()
    combat_before = re.findall(r'combat = \{.*?\n  \}', text, re.S)
    parts = re.split(r'(characters "([^"]+)" \{)', text)
    out = [parts[0]]
    changed = {}
    i = 1
    while i < len(parts):
        header, key = parts[i], parts[i + 1]
        body = parts[i + 2]
        name = key[len('meizhuang_'):] if key.startswith('meizhuang_') else None
        if name in APPR:
            before = body
            body = replace_placeholders(body, name)
            additions = '\n'.join([teach_block(name), apprentice_block(name)])
            body = insert_assignments(body, additions)
            assert body != before, key
            changed[key] = (len(set_skills(read_lpc(name))) - len(NO_TEACH.get(name, {})),
                            len([g for g in GRANTS if g[0] == name]))
        out.append(header)
        out.append(body)
        i += 3
    new_text = ''.join(out)
    combat_after = re.findall(r'combat = \{.*?\n  \}', new_text, re.S)
    assert combat_before == combat_after, 'combat block changed!'
    assert len(changed) == 5, sorted(changed)
    with open(UCL, 'w', encoding='utf-8', newline='') as f:
        f.write(new_text)
    for k, v in sorted(changed.items()):
        print(f'{k:20} teach={v[0]:2} grants={v[1]}')
    print(f'OK: {len(changed)} meizhuang blocks updated, combat byte-identical')


if __name__ == '__main__':
    main()