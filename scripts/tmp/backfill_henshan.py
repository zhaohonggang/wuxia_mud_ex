#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-shot UCL backfill for henshan (衡山派) teaching data (Task #859).

Authority: C:/files/git/mud/kungfu/class/henshan/{henshan.h,liu.c,lu.c,mi.c,mo.c,xiang.c}
and adm/daemons/masterd.c for teach_pfm gate order/text.
Only inserts new assignments into the five henshan_* character blocks;
strictly asserts every existing combat { ... } block stays byte-identical.

NOTE: one-shot. Re-running after placeholders/grants are in place does not
regenerate anything else; do not treat as a repeatable migration tool.
"""
import os
import re

UCL = 'data/world/clone_lib.ucl'
LPC = r'C:\files\git\mud\kungfu\class\henshan'

FAMILY = '衡山派'

PERMIT = {
    'betray_sect_deny': '你当年都已经离开了衡山派，何必又要回来？',
    'betray_times_deny': '我们衡山派乃名门正派，决不收判师之徒！',
    'other_family_deny': '你既然已经有了名师指点，不好好学习，来我们衡山派作甚？',
}

SHEN_DENY_STD = '我衡山剑派乃是堂堂名门正派，对弟子要求严格。你在这侠义与德行方面是否还做得不够？'
EXP_DENY = '你现在经验尚浅，还是多在江湖上走走吧。'
JIAN_DENY_STD = '我衡山乃五岳剑派之一，最为重视剑法。你的衡山剑法还不够熟练，下去练练再来吧。'
FORCE_DENY_STD = '我衡山剑派虽善用剑，但内功却是御剑之本。你是否还应该在内功心法上多下点功夫？'

# NPC -> (shen, exp, henshan-jian, force, shen_deny, jian_deny, force_deny, extra lines)
APPR = {
    'liu': (30000, 200000, 120, 150, SHEN_DENY_STD, JIAN_DENY_STD, FORCE_DENY_STD, []),
    'lu': (5000, 50000, 50, 100, SHEN_DENY_STD, JIAN_DENY_STD, FORCE_DENY_STD, []),
    'mi': (0, 0, 0, 0, '你这人不做好事，我衡山派可容你不得。', '', [],
           ['    reject_master_name = "xiang danian"',
            '    reject_master_name_deny = "你既已拜我向师兄为师，我也不便收你为徒。"']),
    'mo': (40000, 300000, 120, 180, SHEN_DENY_STD, JIAN_DENY_STD, FORCE_DENY_STD, []),
    'xiang': (2000, 20000, 30, 80,
              '你非侠义之辈，岂能入我衡山剑派？',
              '你衡山剑法练成这样，平时都干什么去了？',
              '你的内功心法太差，又能跟我学什么？', []),
}

NO_TEACH_MAP = {
    'liu': {
        'liuyun-zhang': '这流云掌向来只由掌门人亲授，你还是找我师兄传授吧！',
        'shilin-jian': '石廪剑法向来只由掌门人亲授，你还是找我师兄传授吧！',
    },
    'lu': {'zhenyue-jue': '这门内功我也是刚练不久，生疏得紧。'},
}

# masterd.c:109-205 exact deny texts.
MD_MAXED = '这招你不是已经会了么，还缠着我做甚？'
MD_FAMILY = '大侠与我衡山派素无渊源，不知此话从何说起。'
MD_SHEN = '你目前所做的侠义正事不够，这招暂时还不能传你。'
MD_GX = '你为衡山派作出的贡献不够，这招暂时还不能传你。'
MD_FORCE = '你目前的内功火候不足，下去练练再来吧。'
MD_DODGE = '你目前的轻功火候不足，下去练练再来吧。'
MD_NEILI = '你现在的内力修为不足，修炼高点再来吧。'

CN = {
    'furong-jian': '芙蓉剑法',
    'luoyan-jian': '回风落雁剑',
    'henshan-jian': '衡山剑法',
    'tianzhu-jian': '天柱剑法',
    'henshan-quan': '衡山拳法',
    'zigai-jian': '紫盖剑法',
    'shilin-jian': '石廪剑法',
    'liuyun-zhang': '流云掌',
    'biluo-zhang': '碧罗掌法',
}
BASIC = {
    'furong-jian': 'sword', 'luoyan-jian': 'sword', 'henshan-jian': 'sword',
    'tianzhu-jian': 'sword', 'zigai-jian': 'sword', 'shilin-jian': 'sword',
    'henshan-quan': 'cuff', 'liuyun-zhang': 'strike', 'biluo-zhang': 'strike',
}

# (npc, key, perform, sk1, lv1, force, dodge, neili, gongxian, shen)
GRANTS = [
    ('liu', '乱剑覆花', 'furong-jian/luan', 'furong-jian', 100, 140, 140, 1600, 300, 20000, '乱剑覆花'),
    ('liu', '一剑落九雁', 'luoyan-jian/luo', 'luoyan-jian', 150, 220, 220, 2800, 1500, 50000, None),
    ('lu', '幻剑式', 'henshan-jian/huan', 'henshan-jian', 60, 80, None, None, 50, 2000, '幻剑式'),
    ('lu', '烟云锁身', 'tianzhu-jian/suo', 'tianzhu-jian', 120, 150, 150, None, 300, 20000, None),
    ('mi', '青天揽日月', 'henshan-quan/lan', 'henshan-quan', 60, 80, None, None, 50, 2000, None),
    ('mo', '紫盖回翔', 'zigai-jian/hui', 'zigai-jian', 120, 150, 120, None, 200, 15000, None),
    ('mo', '落英纷飞', 'shilin-jian/luo', 'shilin-jian', 120, 180, None, None, 500, 50000, None),
    ('mo', '流云叠影', 'liuyun-zhang/die', 'liuyun-zhang', 100, None, 150, None, 300, 50000, '流云叠影'),
    ('mo', '排山倒海', 'liuyun-zhang/pai', 'liuyun-zhang', 140, 180, None, None, 600, 50000, '排山倒海'),
    ('xiang', '峰连碧罗', 'biluo-zhang/lian', 'biluo-zhang', 100, 120, None, None, 200, 5000, None),
]

GAP_INQUIRIES = {
    'mo': [
        ('历练', 'GAP #864：莫大 QUEST_D 历练问询（历练/历炼/锻炼）有状态任务分发，未实现。'),
        ('历炼', 'GAP #864：莫大 QUEST_D 历练问询（历练/历炼/锻炼）有状态任务分发，未实现。'),
        ('锻炼', 'GAP #864：莫大 QUEST_D 历练问询（历练/历炼/锻炼）有状态任务分发，未实现。'),
        ('镇岳尚方', 'GAP #863：莫大「镇岳尚方」give_item（master=1、henshan-jian 120、shen 50000、神兵持有者遍历），未实现。'),
    ],
}


def read_lpc(name):
    return open(os.path.join(LPC, name + '.c'), encoding='utf-8', errors='replace').read()


def set_skills(text):
    # liu.c:46 is `set_skill("liuyun-zhang" , 220)` - tolerate space before comma.
    return [(s, int(v)) for s, v in
            re.findall(r'set_skill\("([^"]+)"\s*,\s*(\d+)\)', text)]


def extract_msg1(text, case_name):
    m = re.search(r'case\s+"' + re.escape(case_name) + r'"\s*:(.*?)(?=\n\s*case\s+"|\n\s*default:)',
                  text, re.S)
    if not m:
        return None
    mm = re.search(r'"msg1"\s*:\s*((?:"[^"]*"\s*)+)', m.group(1), re.S)
    if not mm:
        return None
    return ''.join(re.findall(r'"([^"]*)"', mm.group(1)))


def q(s):
    assert ';' not in s and '[' not in s and ']' not in s and '\\' not in s, s
    return '"' + s + '"'


def ukey(s):
    return s.replace('-', '_')


def block_span(text, brace_pos):
    depth = 0
    in_str = False
    esc = False
    i = brace_pos
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    raise RuntimeError('unbalanced braces')


def insert_assignments(body, additions):
    m = re.search(r'\n  skills = \[', body)
    if not m:
        raise RuntimeError('no insertion anchor')
    return body[:m.start()] + '\n' + additions.rstrip() + '\n' + body[m.start() + 1:]


def teach_block(name, text):
    nt = NO_TEACH_MAP.get(name, {})
    lines = ['  teach = {', '    family = "' + FAMILY + '"', '    teach_skills = {']
    for skill, level in set_skills(text):
        if skill in nt:
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
    shen, exp, jian, force, shen_deny, jian_deny, force_deny, extra = APPR[name]
    lines = ['  apprentice = {', '    family = "' + FAMILY + '"', '    permit_recruit = true']
    for key, val in PERMIT.items():
        lines.append(f'    {key} = {q(val)}')
    lines += [f'    min_shen = {shen}', f'    min_shen_deny = {q(shen_deny)}']
    if name != 'mi':
        lines += [f'    min_exp = {exp}', f'    min_exp_deny = {q(EXP_DENY)}',
                  '    min_skills = {',
                  f'      henshan_jian = {jian}',
                  f'      force = {force}',
                  '    }',
                  '    min_skills_deny = {',
                  f'      henshan_jian = {q(jian_deny)}',
                  f'      force = {q(force_deny)}',
                  '    }',
                  '    recruit_skill_order = ["henshan-jian", "force"]']
    lines += extra
    lines.append('  }')
    return '\n'.join(lines)


def grant_entry(npc, key, perform, sk1, lv1, force, dodge, neili, gx, shen, msg_case):
    lines = ['    { key = ' + q(key) + ' value = {',
             '      kind = "sect_master_grant"',
             '      perform_id = ' + q(perform),
             '      skill = ' + q(sk1),
             '      family = "' + FAMILY + '"',
             '      gate_order = "lpc_masterd"',
             '      maxed = ' + q(MD_MAXED),
             '      family_deny = ' + q(MD_FAMILY),
             '      skill_deny = ' + q('你连' + CN[sk1] + '都未曾学过，何谈绝招可言？'),
             '      gongxian_deny = ' + q(MD_GX),
             '      shen_deny = ' + q(MD_SHEN),
             '      min_gongxian = ' + str(gx),
             '      cost_gongxian = ' + str(gx),
             '      min_shen = ' + str(shen),
             '      min_levels = { ' + ukey(sk1) + ' = ' + str(lv1) + ' }',
             '      level_order = [' + q(sk1) + ']',
             '      level_deny = { ' + ukey(sk1) + ' = ' +
             q('你对' + CN[sk1] + '的了解还不够，尚且无法领悟此招。') + ' }']
    if force is not None:
        lines += [f'      min_force = {force}', '      force_deny = ' + q(MD_FORCE)]
    if dodge is not None:
        lines += [f'      min_dodge = {dodge}', '      dodge_deny = ' + q(MD_DODGE)]
    if neili is not None:
        lines += [f'      min_max_neili = {neili}', '      max_neili_deny = ' + q(MD_NEILI)]
    if msg_case:
        msg = extract_msg1(read_lpc(npc), msg_case)
        assert msg, (npc, msg_case)
        lines.append('      msg_one = ' + q(msg))
    basic = BASIC[sk1]
    improve = [basic, basic, sk1, sk1, 'martial-cognize']
    lines.append('      improve_skills = [' + ', '.join(q(x) for x in improve) + ']')
    lines.append('      learned = ' + q('你学会了「' + key + '」。'))
    lines.append('    } }')
    return '\n'.join(lines)


def inquiries_block(name):
    entries = [grant_entry(*g) for g in GRANTS if g[0] == name]
    entries += ['    { key = ' + q(k) + ' value = ' + q(v) + ' }'
                for k, v in GAP_INQUIRIES.get(name, [])]
    if not entries:
        return ''
    return '  inquiries = [\n' + ',\n'.join(entries) + '\n  ]'


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
        name = key[len('henshan_'):] if key.startswith('henshan_') else None
        if name in APPR:
            before = body
            additions = '\n'.join(x for x in [
                teach_block(name, read_lpc(name)),
                apprentice_block(name),
                inquiries_block(name),
            ] if x)
            body = insert_assignments(body, additions)
            assert body != before, key
            grants = len([g for g in GRANTS if g[0] == name])
            changed[key] = (len(set_skills(read_lpc(name))) - len(NO_TEACH_MAP.get(name, {})), grants)
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
        print(f'{k:16} teach={v[0]:2} grants={v[1]}')
    print(f'OK: {len(changed)} henshan blocks updated, combat byte-identical')


if __name__ == '__main__':
    main()
