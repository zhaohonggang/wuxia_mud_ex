from pathlib import Path

p = Path(r"C:\files\git\wuxia_mud_ex\data\world\clone_lib.ucl")
text = p.read_bytes().decode("utf-8")

PERMIT = '''    betray_sect_deny = "我们红花会四大戒条你还记得吗？亏你还有脸回来！"
    betray_times_deny = "哼，阁下不忠不信，我们红花会可不会收留。"
    other_family_deny = "阁下既有了师承，还来我们红花会做什么？"
'''

CHAT = {
    "honghua_chang1": ("100", ["strike.cui", "powerup", "recover"]),
    "honghua_chang2": ("100", ["strike.cui", "powerup", "recover"]),
    "honghua_chen": ("100", ["unarmed.luan", "unarmed.yi", "unarmed.hong", "whip.qian", "whip.fu", "dodge.hua", "powerup", "shield", "recover"]),
    "honghua_jiang": ("100", ["staff.lun", "powerup", "recover"]),
    "honghua_lu": ("100", ["unarmed.xuan", "sword.tao", "throwing.xian", "shield", "powerup", "recover"]),
    "honghua_luo": ("100", ["blade.ying", "powerup", "recover"]),
    "honghua_shi": ("100", ["staff.lun", "powerup", "recover"]),
    "honghua_wen": ("100", ["strike.lei", "powerup", "recover"]),
    "honghua_yang": ("100", ["staff.lun", "powerup", "recover"]),
    "honghua_yu": ("100", ["unarmed.xuan", "sword.tao", "throwing.xian", "shield", "powerup", "recover"]),
    "honghua_zhao": ("100", ["sword.chan", "throwing.cang", "powerup", "recover"]),
}


def block_bounds(key):
    start = text.index('    characters "%s" {' % key)
    end = text.find('\n# LPC:', start)
    if end < 0:
        end = len(text)
    return start, end


def replace_in(key, old, new, count=1):
    global text
    start, end = block_bounds(key)
    seg = text[start:end]
    found = seg.count(old)
    assert found == count, (key, found, count, old[:80])
    seg = seg.replace(old, new)
    text = text[:start] + seg + text[end:]


def insert_in(key, marker, addition):
    global text
    start, end = block_bounds(key)
    seg = text[start:end]
    assert seg.count(marker) == 1, (key, marker, seg.count(marker))
    seg = seg.replace(marker, addition + marker, 1)
    text = text[:start] + seg + text[end:]


def add_chat(key):
    chance, msgs = CHAT[key]
    addition = '  chat_chance_combat = %s\n  chat_msg_combat = [%s]\n\n' % (
        chance,
        ", ".join('"%s"' % m for m in msgs),
    )
    for marker in ('  inquiries =', '  teach =', '  skills ='):
        start, end = block_bounds(key)
        if marker in text[start:end]:
            insert_in(key, marker, addition)
            return
    raise AssertionError("no marker for " + key)


# 常赫志 / 常伯志：permit 三句 + shen 5000 + 红花心法 50
old_chang = '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    min_shen = 5000
    min_skills = {
      honghua_xinfa = 50
    }
  }
'''
new_chang = '''  apprentice = {
    family = "红花会"
    permit_recruit = true
%s    min_shen = 5000
    min_shen_deny = "你非我侠义中人，我不能收你。"
    min_skills = {
      honghua_xinfa = 50
    }
    min_skills_deny = {
      honghua_xinfa = "你把本门的心法练好了再来。"
    }
    accept_msg = "以后你就跟着老子吧。"
  }
''' % PERMIT
for key in ("honghua_chang1", "honghua_chang2"):
    replace_in(key, old_chang, new_chang)

# 蒋四根 / 骆冰 / 杨成协：permit 三句 + shen -1000，accept 逐 NPC
old_low = '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    min_shen = -1000
  }
'''
for key, accept in (
    ("honghua_jiang", "嗯。那我就收下你吧。"),
    ("honghua_luo", "既然这样，我就收下你好了。"),
    ("honghua_yang", "嗯。那你以后跟着我好了。"),
):
    new = '''  apprentice = {
    family = "红花会"
    permit_recruit = true
%s    min_shen = -1000
    min_shen_deny = "我红花会不收不义之人，你还是走吧。"
    accept_msg = "%s"
  }
''' % (PERMIT, accept)
    replace_in(key, old_low, new)

# 文泰来：shen 10000 → exp 150000 → 红花心法 60
replace_in(
    "honghua_wen",
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    min_shen = 10000
    min_exp = 150000
    min_skills = {
      honghua_xinfa = 60
    }
  }
''',
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
%s    min_shen = 10000
    min_shen_deny = "哼，我文泰来从不收无义之人。"
    min_exp = 150000
    min_exp_deny = "你的江湖经验太浅，就算收了你，恐怕也难有作为。"
    min_skills = {
      honghua_xinfa = 60
    }
    min_skills_deny = {
      honghua_xinfa = "你连本门内功心法都没练好，怎么习我高深的掌法？"
    }
    accept_msg = "不错，不错，你以后就跟着我吧。"
  }
''' % PERMIT,
)

# 赵半山：shen 15000 → exp 200000 → 红花心法 80
replace_in(
    "honghua_zhao",
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    min_shen = 15000
    min_exp = 200000
    min_skills = {
      honghua_xinfa = 80
    }
  }
''',
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
%s    min_shen = 15000
    min_shen_deny = "你侠义之事做得太少，需要多多注意。"
    min_exp = 200000
    min_exp_deny = "你的江湖经验太浅，还是先跟着其它几位当家练练吧。"
    min_skills = {
      honghua_xinfa = 80
    }
    min_skills_deny = {
      honghua_xinfa = "你下去把本门的心法练好了再来找我。"
    }
    accept_msg = "念在你如此有心，我便收下你好了。"
  }
''' % PERMIT,
)

# 陈家洛：独立门序 permit → shen → exp → 红花心法 → max_neili
replace_in(
    "honghua_chen",
    '''  apprentice = {
    family = "红花会"
    min_shen = 65000
    min_exp = 400000
    min_max_neili = 2000
    min_skills = {
      honghua_xinfa = 100
    }
    max_neili_deny = "大侠内力修为不足，暂不宜学红花会绝技。\\n"
  }
''',
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    gate_order = "lpc_honghua_chen"
%s    min_shen = 65000
    min_shen_deny = "我红花会乃为救天下苍生而建，所做的一切无不以侠义为重。阁下在德行方面，似乎还做得不够。"
    min_exp = 400000
    min_exp_deny = "你的江湖经验太浅，我就算收了你，恐怕你也难有所作为。"
    min_skills = {
      honghua_xinfa = 100
    }
    min_skills_deny = {
      honghua_xinfa = "你本门的内功心法都未练透，如何跟我习高深的武学？"
    }
    min_max_neili = 2000
    max_neili_deny = "我的武功全需强大的内功为辅，阁下似乎应该多练练内力。"
    accept_msg = "不错，不错。念在你如此有心，又乃我侠义中人，今日我便收下你。希望阁下日后多行善事，为我红花会发扬壮大。"
  }
''' % PERMIT,
)

# 石双英：不调用 permit，直接无条件拒绝（deny_all）
insert_in(
    "honghua_shi",
    "  carry = [",
    '''  apprentice = {
    family = "红花会"
    deny_all = true
    deny_msg = "你不收徒，你找其余当家的吧。"
  }

''',
)

# 陆菲青：不调用 permit，直接无条件拒绝（deny_all）
insert_in(
    "honghua_lu",
    "  carry = [",
    '''  apprentice = {
    family = "红花会"
    deny_all = true
    deny_msg = "我不收徒，若要拜师你直接去武当山好了。"
  }

''',
)

# 余鱼同：先 permit 三问，再无条件拒绝（不能用 deny_all 跳过 permit）
insert_in(
    "honghua_yu",
    "  carry = [",
    '''  apprentice = {
    family = "红花会"
    permit_recruit = true
    gate_order = "lpc_honghua_yu"
%s    deny_msg = "我不收徒，你找其余几位当家的好了。"
  }

''' % PERMIT,
)

for key in CHAT:
    add_chat(key)

p.write_bytes(text.replace("\r\n", "\n").encode("utf-8"))
print("step A ok:", len(text), "chars")
