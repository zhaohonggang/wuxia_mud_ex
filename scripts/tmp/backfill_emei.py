#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate UCL edits for emei (峨眉派) teaching-data backfill (Task #849).

Authority: C:/files/git/mud/kungfu/class/emei/*.c + emei.h + tobebonze.h.
Edits clone_lib.ucl insertion-only except:
  - replaces the old fabricated emei_miejue teach/apprentice blocks;
  - replaces the 34 "inquire about ... (unimplemented)" placeholders.
Strict assertion: every existing combat { ... } block stays byte-identical.

NOTE: 这是一次性回填器（执行前从 /tmp/clone_lib_pre_emei.bak 还原）。本脚本以
「unimplemented inquiry 占位」为授艺入口；占位替换后重跑不会重新生成 grant，
也不会回退已落盘的 UCL，但绝不可当作可重复迁移工具使用。定向测试/计划文档是
本批保真基线（11 条 grant、34 处占位清零、#691 旧块修正）。
"""
import re, os, glob

UCL = 'data/world/clone_lib.ucl'
LPC = r'C:\files\git\mud\kungfu\class\emei'

# ---------- LPC parsing ----------

def read_lpc(name):
    return open(os.path.join(LPC, name + '.c'), encoding='utf-8', errors='replace').read()

def set_skills(text):
    out = []
    for skill, level in re.findall(r'set_skill\("([^"]+)",\s*(\d+)\)', text):
        out.append((skill, int(level)))
    return out

def no_teach(text):
    m = re.search(r'set\("no_teach",\s*\(\[(.*?)\]\s*\)\)', text, re.S)
    if not m:
        return {}
    body = m.group(1)
    out = {}
    for part in re.findall(r'"([^"]+)"\s*:\s*((?:"[^"]*"\s*)+)', body):
        key = part[0]
        val = ''.join(re.findall(r'"([^"]*)"', part[1]))
        out[key] = val
    return out

def has_recruit(text):
    return 'attempt_apprentice' in text

def is_bonze(text):
    return 'set("class", "bonze")' in text

SKILL_GROUPS = {
    'extra': ['fengling', 'he', 'hui', 'jia', 'kong', 'miejue', 'xian', 'xin', 'xu', 'xuan', 'zhao', 'zhen'],
    'plain': ['bei', 'dao', 'fang', 'feng', 'li', 'ling', 'su', 'zhou'],
    'junior': ['wenfang', 'wenhui', 'wenqing', 'wenyin'],
}

GAP_TEXT = {
    'for join': 'GAP #853：峨眉剃度/出家需 kneel 多状态流程（pending/join_bonze + 法名前缀），未实现。',
    'for quit': 'GAP #857：峨眉还俗需 pending/quit_bonze 状态门，未实现。',
    'yao': 'GAP #854：静风师太伤药 give_item 库存门（gao_count + 已持有 + 伤势），未实现。',
    'jian': 'GAP #854：静风师太软剑 give_item 库存门（jian_count + 已持有），未实现。',
    'back': 'GAP #855：李明霞「上山/back」带人传送状态机（age/同门/回程定时器），未实现。',
}

# 11 inline ask_skill grants; LPC order: known -> family -> skill>=1 -> gongxian -> levels -> shen.
GRANTS = {
    'miejue': [
        dict(key='灭剑', perform='huifeng-jian/mie', gx=1000, shen=30000,
             levels={'force': 180, 'huifeng_jian': 120}, order=['force', 'huifeng-jian'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连回风拂柳剑法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，怎能使出这回风拂柳剑法中的精妙之处？',
                  'huifeng_jian': '你回风拂柳剑法尚未修炼得精深，哪里能领会其中的微妙之处？'},
             improve=['sword', 'sword', 'huifeng-jian', 'huifeng-jian', 'martial-cognize']),
        dict(key='绝剑', perform='huifeng-jian/jue', gx=1800, shen=30000,
             levels={'force': 300, 'huifeng_jian': 180}, order=['force', 'huifeng-jian'],
             maxed='你自己多练练，降妖除魔就靠你们这些人了！',
             skill_deny='你连回风拂柳剑法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，怎能使出这回风拂柳剑法中的精妙之处？',
                  'huifeng_jian': '你回风拂柳剑法尚未修炼得精深，哪里能领会其中的微妙之处？'},
             improve=['sword', 'sword', 'huifeng-jian', 'huifeng-jian', 'martial-cognize']),
        dict(key='星罗棋布', perform='sixiang-zhang/xing', gx=80, shen=5000,
             levels={'force': 100, 'sixiang_zhang': 70}, order=['force', 'sixiang-zhang'],
             maxed='你自己多练练，降妖除魔就靠你们这些人了！',
             skill_deny='你连四象掌法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，尚且学不了这一招。',
                  'sixiang_zhang': '你的四象掌法火候未到，尚且学不了这一招。'},
             improve=['strike', 'strike', 'sixiang-zhang', 'sixiang-zhang', 'martial-cognize']),
        dict(key='八式合一', perform='jinding-zhang/bashi', gx=250, shen=8000,
             levels={'force': 120, 'jinding_zhang': 100}, order=['force', 'jinding-zhang'],
             maxed='你自己多练练，降妖除魔就靠你们这些人了！',
             skill_deny='你连金顶绵掌都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，尚且学不了这一招。',
                  'jinding_zhang': '你的金顶绵掌火候未到，尚且学不了这一招。'},
             improve=['strike', 'strike', 'jinding-zhang', 'jinding-zhang', 'martial-cognize']),
        dict(key='截筋断脉', perform='jieshou-jiushi/jie', gx=300, shen=12000,
             levels={'max_neili': 850, 'force': 120, 'jieshou_jiushi': 100},
             order=['max-neili', 'force', 'jieshou-jiushi'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连截手九式都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中碌碌无为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'max_neili': '你的内力修行太浅，尚且学不了这一招。',
                  'force': '你的内功修行太浅，尚且学不了这一招。',
                  'jieshou_jiushi': '你的截手九式火候未到，尚且学不了这一招。'},
             improve=['hand', 'hand', 'jieshou-jiushi', 'jieshou-jiushi', 'martial-cognize']),
        dict(key='凌空指穴', perform='tiangang-zhi/ling', gx=250, shen=10000,
             levels={'max_neili': 800, 'force': 100, 'tiangang_zhi': 100},
             order=['max-neili', 'force', 'tiangang-zhi'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连天罡指穴法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中碌碌无为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'max_neili': '你的内力修行太浅，尚且学不了这一招。',
                  'force': '你的内功修行太浅，尚且学不了这一招。',
                  'tiangang_zhi': '你的天罡指穴法火候未到，尚且学不了这一招。'},
             improve=['finger', 'finger', 'tiangang-zhi', 'tiangang-zhi', 'martial-cognize']),
        dict(key='无形幻影', perform='yanxing-dao/huan', gx=300, shen=15000,
             levels={'max_neili': 800, 'force': 120, 'yanxing_dao': 80},
             order=['max-neili', 'force', 'yanxing-dao'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连雁行刀法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中碌碌无为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'max_neili': '你的内力修行太浅，尚且学不了这一招。',
                  'force': '你的内功修行太浅，尚且学不了这一招。',
                  'yanxing_dao': '你的雁行刀法火候未到，尚且学不了这一招。'},
             improve=['blade', 'blade', 'yanxing-dao', 'yanxing-dao', 'martial-cognize']),
        dict(key='佛光初现', perform='emei-jian/xian', gx=50, shen=3000,
             levels={'force': 80, 'emei_jian': 60}, order=['force', 'emei-jian'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连峨嵋剑法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，用不了这一招！',
                  'emei_jian': '你峨嵋剑法尚未修炼得精深，没法用这招。'},
             improve=['sword', 'sword', 'emei-jian', 'emei-jian', 'martial-cognize']),
        dict(key='伏魔剑诀', perform='yitian-jian/fumo', gx=500, shen=20000,
             levels={'force': 180, 'yitian_jian': 120}, order=['force', 'yitian-jian'],
             maxed='这招我不是已经教过你了吗？自己下去多练吧！',
             skill_deny='你连倚天剑法都没学，还谈什么绝招可言？',
             gx_deny='哼，你在本派中无所作为，这一招我暂时还不能传你。',
             shen_deny='哼！你行侠仗义的事情还做得不够！做得不够！',
             lvl={'force': '你的内功修行太浅，用不了这一招！',
                  'yitian_jian': '你倚天剑法尚未修炼得精深，没法用这招。'},
             improve=['sword', 'sword', 'yitian-jian', 'yitian-jian', 'martial-cognize']),
    ],
    'fengling': [
        dict(key='云海明灯', perform='piaoxue-zhang/yun', gx=1800, shen=40000,
             levels={'force': 200, 'max_neili': 2000, 'piaoxue_zhang': 150},
             order=['force', 'max-neili', 'piaoxue-zhang'],
             maxed='这一招我不是已经传授予你了吗？还有什么不懂就自己下去练吧。',
             skill_deny='你连飘雪穿云掌都没学，还谈什么绝招可言？',
             gx_deny='你对峨嵋派所作出的贡献还不够，这招我暂时不能传你。',
             shen_deny='你行侠仗义的事情还做得不够，我暂时还不能传你此招。',
             lvl={'force': '你的内功修行太浅，尚且学不了这一招。',
                  'max_neili': '你的内力修行太浅，尚且学不了这一招。',
                  'piaoxue_zhang': '你的飘雪穿云掌火候未到，尚且学不了这一招。'},
             improve=['strike', 'strike', 'piaoxue-zhang', 'piaoxue-zhang', 'martial-cognize']),
        dict(key='佛光普照', perform='piaoxue-zhang/zhao', gx=2200, shen=40000,
             levels={'force': 300, 'max_neili': 3500, 'piaoxue_zhang': 180},
             order=['force', 'max-neili', 'piaoxue-zhang'],
             maxed='这一招我不是已经传授予你了吗？还有什么不懂就自己下去练吧。',
             skill_deny='你连飘雪穿云掌都没学，还谈什么绝招可言？',
             gx_deny='你对峨嵋派所作出的贡献还不够，这招我暂时不能传你。',
             shen_deny='你行侠仗义的事情还做得不够，我暂时还不能传你此招。',
             lvl={'force': '你的内功修行太浅，尚且学不了这一招。',
                  'max_neili': '你的内力修行太浅，尚且学不了这一招。',
                  'piaoxue_zhang': '你的飘雪穿云掌火候未到，尚且学不了这一招。'},
             improve=['strike', 'strike', 'piaoxue-zhang', 'piaoxue-zhang', 'martial-cognize']),
    ],
}

# ---------- UCL helpers ----------

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

def remove_assignment(body, key):
    pat = re.compile(r'\n  ' + re.escape(key) + r' = \{')
    m = pat.search(body)
    if not m:
        return body
    open_pos = m.end() - 1
    close_pos = block_span(body, open_pos)
    return body[:m.start()] + body[close_pos + 1:]

def insert_assignments(body, additions):
    for pat in [r'\n  inquiries = \[', r'\n  skills = \[', r'\n  carry = \[']:
        m = re.search(pat, body)
        if m:
            return body[:m.start()] + '\n' + additions.rstrip() + '\n' + body[m.start() + 1:]
    raise RuntimeError('no insertion anchor')

def q(s):
    assert ';' not in s and '[' not in s and ']' not in s and '\\' not in s, s
    return '"' + s + '"'

def ukey(s):
    return s.replace('-', '_')

def teach_block(name, text):
    nt = no_teach(text)
    lines = ['  teach = {', '    family = "峨嵋派"', '    teach_skills = {']
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

def apprentice_block(name, text):
    if not has_recruit(text):
        return ''
    lines = ['  apprentice = {', '    family = "峨嵋派"', '    permit_recruit = true',
             '    gate_order = "gender_first"',
             '    gender = "女性"',
             '    gender_deny = "阿弥陀佛！我峨嵋派不收男弟子。施主若想学艺，可去少林、武当投师。"',
             '    betray_sect_deny = "你当年既然离开了峨嵋派，今天又何必回来？"',
             '    betray_times_deny = "你欺师灭主，背叛师门，这种人我们峨嵋派不会收留的。"',
             '    other_family_deny = "你已有名师指点，为何又来峨嵋派？莫非你要判师不成？"']
    if is_bonze(text):
        lines += ['    require_class = "bonze"',
                  '    class_deny = "阿弥陀佛！贫尼不收俗家弟子。"']
    # emei.h shen >= 0
    lines += ['    min_shen = 0', '    min_shen_deny = "唉，你现在正入歧途，我怎能收你为徒？"']
    extra = {
        'fengling': (30000, 500000,
                     {'mahayana': 150, 'linji-zhuang': 150},
                     '你行侠仗义的事情还做得不够，我暂时还不能收你。',
                     {'mahayana': '你大乘涅磐功的修为还不行，好好感悟感悟！',
                      'linji-zhuang': '临济十二庄乃我峨嵋第一奇功，须得好好练习。'},
                     '灭'),
        'miejue': (30000, 300000,
                   {'mahayana': 100, 'emei-xinfa': 100},
                   '你行侠仗义之事做的太少！实在是太少！',
                   {'mahayana': '你大乘涅磐功修为还不行，好好感悟感悟！',
                    'emei-xinfa': '怎么回事？本门内功心法你怎么学的？好好给我练功去！'},
                   '静'),
    }
    if name in extra:
        shen, exp, skills, shen_deny, skill_denies, rename = extra[name]
        lines[lines.index('    min_shen = 0')] = f'    min_shen = {shen}'
        lines[lines.index('    min_shen_deny = "唉，你现在正入歧途，我怎能收你为徒？"')] = \
            f'    min_shen_deny = {q(shen_deny)}'
        lines += [f'    min_exp = {exp}',
                  '    min_exp_deny = "你的江湖经验太浅，还是先多锻炼锻炼再说吧。"',
                  '    min_skills = {']
        for skill, lv in skills.items():
            lines.append(f'      {ukey(skill)} = {lv}')
        lines.append('    }')
        lines.append('    min_skills_deny = {')
        for skill, deny in skill_denies.items():
            lines.append(f'      {ukey(skill)} = {q(deny)}')
        lines.append('    }')
        lines.append(f'    rename_prefix = "{rename}"')
    elif name in ['he', 'hui', 'jia', 'kong', 'xian', 'xin', 'xu', 'xuan', 'zhao', 'zhen']:
        lines[lines.index('    min_shen = 0')] = '    min_shen = 1000'
        lines[lines.index('    min_shen_deny = "唉，你现在正入歧途，我怎能收你为徒？"')] = \
            '    min_shen_deny = "你行侠仗义之事还做的不够。"'
        lines += ['    min_skills = {', '      mahayana = 50', '    }',
                  '    min_skills_deny = {',
                  '      mahayana = "你大乘涅磐功的修为还不够，提高些再来吧。"', '    }']
    lines.append('  }')
    return '\n'.join(lines)

def grant_block(key, g, comma=','):
    lines = [
        f'{{ key = "{key}" value = {{',
        '      kind = "sect_master_grant"',
        f'      perform_id = "{g["perform"]}"',
        '      gate_order = "lpc_emei"',
        f'      skill = "{g["perform"].split("/")[0]}"',
        '      family = "峨嵋派"',
        '      family_deny = "你是哪里来的？快给我滚开！"',
        '      min_levels = {',
    ]
    for skill, lv in g['levels'].items():
        lines.append(f'        {ukey(skill)} = {lv}')
    lines += ['      }', f'      level_order = [{", ".join(q(x) for x in g["order"])}]',
              f'      min_gongxian = {g["gx"]}', f'      cost_gongxian = {g["gx"]}',
              f'      min_shen = {g["shen"]}', f'      maxed = {q(g["maxed"])}',
              f'      skill_deny = {q(g["skill_deny"])}',
              f'      gongxian_deny = {q(g["gx_deny"])}',
              f'      shen_deny = {q(g["shen_deny"])}',
              '      level_deny = {']
    for skill, deny in g['lvl'].items():
        lines.append(f'        {ukey(skill)} = {q(deny)}')
    lines += ['      }', f'      learned = "你学会了「{key}」。"',
              f'      improve_skills = [{", ".join(q(x) for x in g["improve"])}]',
              '    } }' + (',' if comma else '')]
    return '\n'.join(lines)

PLACEHOLDER_RE = re.compile(
    r'\{ key = "([^"]+)" value = " inquire about ([^"]+?) \(unimplemented\)" \},?')

# ---------- apply ----------

text = open(UCL, encoding='utf-8').read()
combat_before = re.findall(r'combat = \{.*?\n  \}', text, re.S)

parts = re.split(r'(characters "([^"]+)" \{)', text)
out = [parts[0]]
i = 1
changed = {}
while i < len(parts):
    header, key = parts[i], parts[i + 1]
    body = parts[i + 2]
    if key.startswith('emei_') and os.path.exists(os.path.join(LPC, key[5:] + '.c')):
        name = key[5:]
        lpc = read_lpc(name)
        before = body
        # 1) replace old teach/apprentice (miejue) or append new ones
        body = remove_assignment(body, 'teach')
        body = remove_assignment(body, 'apprentice')
        additions = teach_block(name, lpc) + '\n' + apprentice_block(name, lpc)
        body = insert_assignments(body, additions.strip())

        # 2) replace placeholders
        grants = {g['key']: g for g in GRANTS.get(name, [])}
        def repl(m):
            k, kind = m.group(1), m.group(2)
            comma = ',' if m.group(0).rstrip().endswith(',') else ''
            if k in grants:
                return grant_block(k, grants[k], comma)
            assert kind in GAP_TEXT, (name, k, kind)
            return f'{{ key = "{k}" value = {q(GAP_TEXT[kind])} }}{comma}'
        body = PLACEHOLDER_RE.sub(repl, body)

        if body != before:
            changed[key] = (len(set_skills(lpc)), has_recruit(lpc), len(grants))
    out.append(header)
    out.append(body)
    i += 3

new_text = ''.join(out)
combat_after = re.findall(r'combat = \{.*?\n  \}', new_text, re.S)
assert combat_before == combat_after, 'combat block changed!'
assert len(changed) == 24, (len(changed), sorted(changed))

with open(UCL, 'w', encoding='utf-8', newline='') as f:
    f.write(new_text)

for k, v in sorted(changed.items()):
    print(f'{k:18} skills={v[0]:2} appr={int(v[1])} grants={v[2]}')
print(f'OK: {len(changed)} emei blocks updated, combat blocks byte-identical')
