from pathlib import Path

p = Path(r"C:\files\git\wuxia_mud_ex\data\world\clone_lib.ucl")
text = p.read_bytes().decode("utf-8")


def block_bounds(key):
    start = text.index('    characters "%s" {' % key)
    end = text.find('\n# LPC:', start)
    if end < 0:
        end = len(text)
    return start, end


def replace_section(key, start_marker, end_marker, new_text):
    global text
    start, end = block_bounds(key)
    seg = text[start:end]
    assert seg.count(start_marker) == 1, (key, "start", seg.count(start_marker))
    i = seg.index(start_marker)
    j = seg.index(end_marker, i)
    seg = seg[:i] + new_text + seg[j:]
    text = text[:start] + seg + text[end:]


def replace_exact(key, old, new, count=1):
    global text
    start, end = block_bounds(key)
    seg = text[start:end]
    found = seg.count(old)
    assert found == count, (key, found, count, old[:100])
    text = text[:start] + seg.replace(old, new) + text[end:]


def insert_in(key, marker, addition):
    global text
    start, end = block_bounds(key)
    seg = text[start:end]
    assert seg.count(marker) == 1, (key, marker, seg.count(marker))
    text = text[:start] + seg.replace(marker, addition + marker, 1) + text[end:]


# ---------------- 常赫志：催魂掌 ----------------
replace_section(
    "honghua_chang1",
    "  inquiries = [",
    "  teach = {",
    '''  inquiries = [
    { key = "催魂掌" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "heisha-zhang/cui"
      skill = "heisha-zhang"
      min_levels = {
        force = 150
        heisha_zhang = 100
      }
      level_order = ["force", "heisha_zhang"]
      level_deny = {
        force = "你龟儿内功都没学好，学啥子这招哦！"
        heisha_zhang = "你黑砂掌学成这副龟儿子德性，咋个练催魂掌嘛？"
      }
      min_gongxian = 150
      min_shen = 5000
      cost_gongxian = 150
      family = "红花会"
      maxed = "老子把啥子都给你说完了，你龟儿咋那么烦哦！"
      family_deny = "你龟儿子是哪儿来的？老子认不到你。"
      skill_deny = "你龟儿黑砂掌都没学，还说啥子催魂掌哦！"
      gongxian_deny = "你龟儿贡献都做得不够，喊我咋个传你嘛？"
      shen_deny = "你连行侠仗义都搞忘了，我还敢传你啥子嘛？"
      msg_one = "$n看了看$N，哈哈一笑，说道：“要得，要得！看你娃学得还可以，今天我就教你催魂掌。”$n说罢，便轻轻拍出一掌，看似不着半点力道。正当$N纳闷间，听得“噗”的一声，随即尘沙滚滚，飘然四起，身前沙地豁然留下一个乌黑的掌印，煞是惊人。"
      learned = "你学会了「催魂掌」。"
      improve_skills = ["strike", "heisha_zhang", "martial_cognize"]
    } }
  ]

''',
)

# ---------------- 陈家洛：6 绝招 + 剑盾珠索 ----------------
replace_section(
    "honghua_chen",
    "  inquiries = {",
    "  teach = {",
    '''  inquiries = [
    { key = "剑盾珠索" value = {
      kind = "give_item"
      item = "clone_lib:jiansuo"
      match = "jiansuo"
      unique = true
      family = "红花会"
      master_id = true
      master_before_gates = true
      min_shen = 80000
      min_skill_levels = {
        jiandun_zhusuo = 120
      }
      family_deny = "你又不是我们红花会的兄弟，打听它干什么？"
      master_deny = "只有我的弟子才能用我这剑盾珠索。"
      min_shen_deny = "你侠义正事做得还不够，这剑盾珠索我不能教给你。"
      min_skill_deny = "你连剑盾珠索都没学好，就算用也是白搭。"
      already = "剑盾珠索现在不就在你手里吗？"
      vision_name = "陈家洛"
      success = "这剑盾珠索你就拿去，多用它行侠仗义，惩奸除恶。"
    } },
    { key = "缚字诀" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "jiandun-zhusuo/fu"
      skill = "jiandun-zhusuo"
      min_levels = {
        max_neili = 600
        jiandun_zhusuo = 50
      }
      level_order = ["max_neili", "jiandun_zhusuo"]
      level_deny = {
        max_neili = "你的内力修为不够，学不成这招。"
        jiandun_zhusuo = "你的剑盾珠索还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 200
      min_shen = 60000
      cost_gongxian = 200
      family = "红花会"
      maxed = "这招我不是早就传授给你了吗？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连剑盾珠索都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n点了点头，将$N招至身边，在耳旁低声细说良久，$N听后会心的一笑，看来大有所悟。"
      learned = "你学会了「缚字诀」。"
      improve_skills = ["whip", "jiandun_zhusuo", "martial_cognize"]
    } },
    { key = "千头万绪" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "jiandun-zhusuo/qian"
      skill = "jiandun-zhusuo"
      min_levels = {
        force = 180
        jiandun_zhusuo = 120
      }
      level_order = ["force", "jiandun_zhusuo"]
      level_deny = {
        force = "你的内力修为不够，学不成这招。"
        jiandun_zhusuo = "你的剑盾珠索还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 1200
      min_shen = 100000
      cost_gongxian = 1200
      family = "红花会"
      maxed = "这招我不是早就传授给你了吗？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连剑盾珠索都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n对$N赞许地点了点头，道：“既然你如此有心，今日我便传你此招。”$n招了招手，$N连忙走上前去，只见$n轻声在$N说了些话，接着手中长索一抖，登时幻出漫天鞭影，宛如蛟龙通天，无数鞭影向四面八方劲点而去。"
      learned = "你学会了「千头万绪」。"
      improve_skills = ["whip", "jiandun_zhusuo", "martial_cognize"]
    } },
    { key = "化蝶" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "zhuangzi-wu/hua"
      skill = "zhuangzi-wu"
      min_levels = {
        dex = 32
        max_neili = 2000
        zhuangzi_wu = 150
      }
      level_order = ["dex", "max_neili", "zhuangzi_wu"]
      level_deny = {
        dex = "你的身法灵动性不足，学不成这招。"
        max_neili = "你的内力修为不够，学不成这招。"
        zhuangzi_wu = "你的庄子舞还练得不到家，自己下去练练再来吧！"
      }
      min_dex = 32
      min_gongxian = 1000
      min_shen = 100000
      cost_gongxian = 1000
      family = "红花会"
      maxed = "这招我不是已经教给你了吗？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连庄子舞都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n微微一笑，对$N点头道：“你今日有此造诣，传你这招，又有何难？”说话随即一声清啸，身形一展，舞步宛如行云流水、彩蝶飞扬般，速度变得异常敏捷。$N见得如此神妙的舞步，不禁赞叹不已。"
      learned = "你学会了「化蝶」。"
      improve_skills = ["dodge", "force", "zhuangzi_wu", "martial_cognize"]
    } },
    { key = "百花错乱" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "baihua-cuoquan/luan"
      skill = "baihua-cuoquan"
      min_levels = {
        max_neili = 2000
        baihua_cuoquan = 120
      }
      level_order = ["max_neili", "baihua_cuoquan"]
      level_deny = {
        max_neili = "你的内力修为不够，学不成这招。"
        baihua_cuoquan = "你的百花错拳还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 400
      min_shen = 80000
      cost_gongxian = 400
      family = "红花会"
      maxed = "这招我不是已经教给你了吗？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连百花错拳都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n对$N点了点头，说道：“我给你演示一遍，可要仔细看好了。”说罢只见$n顿步沉身，双掌交错打出，掌锋拳影重重叠叠，虚实难辨。"
      learned = "你学会了「百花错乱」。"
      improve_skills = ["unarmed", "baihua_cuoquan", "martial_cognize"]
    } },
    { key = "百花错易" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "baihua-cuoquan/yi"
      skill = "baihua-cuoquan"
      min_levels = {
        max_neili = 3000
        force = 280
        baihua_cuoquan = 150
      }
      level_order = ["max_neili", "force", "baihua_cuoquan"]
      level_deny = {
        max_neili = "你的内力修为不够，学不成这招。"
        force = "你的内功修为不够，学不成这招。"
        baihua_cuoquan = "你的百花错拳还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 1000
      min_shen = 100000
      cost_gongxian = 1000
      family = "红花会"
      maxed = "这招我不是已经教给你了吗？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连百花错拳都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n对$N微微一笑，说道：“看好了！”只听$n话音刚落，随即大喝一声，双掌纷飞，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻出去八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，铺天盖地连续贯出。气势恢弘，无与伦比。只看得$N呆立当场，不知所措。"
      learned = "你学会了「百花错易」。"
      improve_skills = ["unarmed", "baihua_cuoquan", "martial_cognize"]
    } },
    { key = "战神轰天诀" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "baihua-cuoquan/hong"
      skill = "baihua-cuoquan"
      min_levels = {
        max_neili = 5000
        baihua_cuoquan = 250
        zhanshen_xinjing = 250
      }
      level_order = ["max_neili", "baihua_cuoquan", "zhanshen_xinjing"]
      level_deny = {
        max_neili = "你的内力修为不够，学不成这招。"
        baihua_cuoquan = "你的百花错拳还练得不到家，自己下去练练再来吧！"
        zhanshen_xinjing = "你的战神心经修为不够，自己下去练练再来吧！"
      }
      min_gongxian = 2500
      min_shen = 150000
      cost_gongxian = 2500
      family = "红花会"
      maxed = "我已将拳诀尽数传予了你，还有什么疑问？"
      family_deny = "和本会素无瓜葛，何出此言？"
      skill_deny = "你连百花错拳都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n对$N微微一笑，叹道：“你今日造诣非凡，确有能力继承我这拳法，我先将总诀说予你听罢。方今之时，臣以神遇，而不以目视，官知止而神欲行，依乎天理，批大却，导大窍，因其固然……”$N听得满脸迷茫，问道：“师父，这…不是《庄子》中庖丁解……”$n笑道：“起初我也是这般的怀疑，但破敌秘诀，却尽都在此。”说完便接着沉吟道：“行为迟，动刀甚微，孑然已解，如土委地，提刀而立，为之四顾，为之踌躇满志……”良久，良久……。"
      learned = "你学会了「战神轰天诀」。"
      improve_skills = ["unarmed", "unarmed", "unarmed", "baihua_cuoquan", "baihua_cuoquan", "baihua_cuoquan", "force", "force", "force", "zhanshen_xinjing", "zhanshen_xinjing", "zhanshen_xinjing", "martial_cognize"]
    } }
  ]

''',
)

# ---------------- 陆菲青：3 绝招 + 2 物品 + 库存 ----------------
insert_in(
    "honghua_lu",
    "  inquiries = [",
    '''  inquiry_state = {
    zhen_count = 3
  }

''',
)
replace_section(
    "honghua_lu",
    "  inquiries = [",
    "  teach = {",
    '''  inquiries = [
    { key = "芙蓉金针" value = {
      kind = "give_item"
      item = "kaifeng:jinzhen"
      match = "jinzhen"
      count = "zhen_count"
      unique = false
      allowed_families = ["红花会", "武当派"]
      min_skill_levels = {
        furong_jinzhen = 80
      }
      min_skill_deny = "你芙蓉金针的手法还不到家，拿了芙蓉金针也没什么用。"
      exhausted = "我又不是卖这个的，哪里带得了这么多。"
      vision_name = "陆菲青"
      success = "既然这样，我这儿的芙蓉金针你就先拿去用吧。"
    } },
    { key = "白龙剑" value = {
      kind = "give_item"
      item = "clone_lib:bailongjian"
      match = "bailongjian"
      unique = true
      allowed_families = ["红花会", "武当派"]
      family_denies = {
        武当派 = "你虽和我同在武当，但这配剑是我随身之物，现大敌当前，不便交予。"
      }
      allowed_master_ids = ["chen jialuo", "wuchen daozhang", "zhao banshan"]
      master_before_gates = true
      min_shen = 30000
      min_skill_levels = {
        rouyun_jian = 150
      }
      family_deny = "贫道与阁下素不相识，不知阁下无故打听在下的配剑究是为何？"
      master_deny = "我与你师父不熟，这白龙剑不能交给你。"
      min_shen_deny = "学武之人，自应以德义为先。我的配剑不会随便给人，你走吧。"
      min_skill_deny = "你还是先在贫道这里把柔云剑法练成之后再说吧。"
      already = "嗯？贫道的白龙宝剑不就在你身上吗？"
      vision_name = "陆菲青"
      success = "配剑你拿去吧，但切记行走江湖侠义为重，莫坏了红花会的名声。"
    } },
    { key = "金针现影" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "furong-jinzhen/xian"
      skill = "furong-jinzhen"
      allowed_families = ["红花会", "武当派"]
      min_levels = {
        force = 120
        furong_jinzhen = 80
      }
      level_order = ["force", "furong_jinzhen"]
      level_deny = {
        force = "你的内功火候不足，用不了这一招！"
        furong_jinzhen = "你芙蓉金针尚未修炼得精深，难以运用此招。"
      }
      min_gongxian = 300
      min_shen = 30000
      cost_gongxian = 300
      maxed = "自己下去练，能教的我都尽数教给你了。"
      family_deny = "贫道与阁下素无渊源，不知阁下这话从何而来？"
      skill_deny = "你连芙蓉金针都没学，还谈什么绝招可言？"
      gongxian_deny = "嗯，你对本门所作的贡献不够，这招我不传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n对$N笑了笑，俯身从腰囊中拈出一根金针，轻轻弹出，顿时只听“飕”的一声，金针化作一道金芒，没入$N脚跟前的青石地，只留下一个小孔。"
      learned = "你学会了「金针现影」。"
      improve_skills = ["throwing", "furong_jinzhen", "martial_cognize"]
    } },
    { key = "三环套月" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "rouyun-jian/tao"
      skill = "rouyun-jian"
      allowed_families = ["红花会", "武当派"]
      min_levels = {
        force = 180
        dodge = 180
        rouyun_jian = 140
      }
      level_order = ["force", "dodge", "rouyun_jian"]
      level_deny = {
        force = "你的内功修行太浅，用不了这一招！"
        dodge = "你的轻功修为不够，用不了这一招！"
        rouyun_jian = "你柔云剑法尚未修炼得精深，难以运用此招。"
      }
      min_gongxian = 700
      min_shen = 60000
      cost_gongxian = 700
      maxed = "这招你不是已经学会了吗？"
      family_deny = "贫道与阁下素无渊源，不知阁下这话从何而来？"
      skill_deny = "你连柔云剑法都没学，还谈什么绝招可言？"
      gongxian_deny = "嗯，你对本门所作的贡献不够，这招我不传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n微微一笑，从怀中轻轻取出了一本剑谱，指着其中一段对$N细说良久，$N一边听一边点头。"
      learned = "你学会了「三环套月」。"
      improve_skills = ["sword", "rouyun_jian", "martial_cognize"]
    } },
    { key = "玄功无极劲" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "xuangong-quan/xuan"
      skill = "xuangong-quan"
      allowed_families = ["红花会", "武当派"]
      min_levels = {
        force = 160
        xuangong_quan = 120
      }
      level_order = ["force", "xuangong_quan"]
      level_deny = {
        force = "你的内功修行太浅，用不了这一招！"
        xuangong_quan = "你无极玄功拳尚未修炼得精深，难以运用此招。"
      }
      min_gongxian = 400
      min_shen = 50000
      cost_gongxian = 400
      maxed = "这招我已经教过你了，自己下去练吧。"
      family_deny = "贫道与阁下素无渊源，不知阁下这话从何而来？"
      skill_deny = "你连无极玄功拳都没学，还谈什么绝招可言？"
      gongxian_deny = "嗯，你对本门所作的贡献不够，这招我不传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n点了点头，将$N招至身边，在耳旁低声细说良久，$N听后会心的一笑，看来大有所悟。"
      learned = "你学会了「玄功无极劲」。"
      improve_skills = ["unarmed", "xuangong_quan", "martial_cognize"]
    } }
  ]

''',
)

# ---------------- 骆冰：刀影重重 ----------------
replace_section(
    "honghua_luo",
    "  inquiries = [",
    "  teach = {",
    '''  inquiries = [
    { key = "刀影重重" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "hanwang-qingdao/ying"
      skill = "hanwang-qingdao"
      min_levels = {
        force = 120
        hanwang_qingdao = 80
      }
      level_order = ["force", "hanwang_qingdao"]
      level_deny = {
        force = "你的内功火候不足，学不了这一招！"
        hanwang_qingdao = "你的韩王青刀还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 80
      min_shen = 5000
      cost_gongxian = 80
      family = "红花会"
      maxed = "你不是已经会了吗？"
      family_deny = "和本教素无瓜葛，何出此言？"
      skill_deny = "你连韩王青刀都没学，何谈此言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n点了点头，将$N招至身边，在耳旁低声细说良久，$N听后会心的一笑，看来大有所悟。"
      learned = "你学会了「刀影重重」。"
      improve_skills = ["blade", "hanwang_qingdao", "martial_cognize"]
    } }
  ]

''',
)

# ---------------- 文泰来：雷霆万钧 ----------------
replace_section(
    "honghua_wen",
    "  inquiries = [",
    "  teach = {",
    '''  inquiries = [
    { key = "雷霆万钧" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "benlei-zhang/lei"
      skill = "benlei-zhang"
      min_levels = {
        force = 200
        benlei_zhang = 120
      }
      level_order = ["force", "benlei_zhang"]
      level_deny = {
        force = "你的内功火候不足，学不成这一招。"
        benlei_zhang = "你的霹雳奔雷掌还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 600
      min_shen = 20000
      cost_gongxian = 600
      family = "红花会"
      maxed = "这招俺不是已经教给你了吗？"
      family_deny = "和本教素无瓜葛，何出此言？"
      skill_deny = "你连霹雳奔雷掌都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n大笑数声，对$N说道：“想不到你的掌法居然能有如此造诣，今日我传你这招又何妨？”说罢，$n随即摆开架势，慢慢的演示招数。"
      learned = "你学会了「雷霆万钧」。"
      improve_skills = ["strike", "benlei_zhang", "martial_cognize"]
    } }
  ]

''',
)

# ---------------- 赵半山：掌藏龙 + 回龙璧 ----------------
replace_section(
    "honghua_zhao",
    "  inquiries = [",
    "  teach = {",
    '''  inquiries = [
    { key = "回龙璧" value = {
      kind = "give_item"
      item = "clone_lib:huilongbi"
      match = "huilongbi"
      unique = true
      family = "红花会"
      allowed_master_ids = ["chen jialuo", "wuchen daozhang", "zhao banshan"]
      master_before_gates = true
      skill_before_shen = true
      min_skill_levels = {
        huilong_bifa = 150
      }
      min_shen = 30000
      family_deny = "嘿，你是哪里来的？我可不认识你。"
      master_deny = "这个…你师父说了，不能太宠着你，过些日子吧。"
      min_skill_deny = "等你回龙璧法练成后再来找我，快下去练练。"
      min_shen_deny = "哎呀呀，我这倒不是吝啬，可是你的德行也……"
      already = "我的回龙璧不正是你拿着在用吗，为何还反倒问起我来了？"
      exhausted = "你来晚了，回龙璧现在并不在我手中。"
      vision_name = "赵半山"
      success = "既然这样，我这支回龙璧你就暂时拿去用吧。"
    } },
    { key = "掌藏龙" value = {
      kind = "sect_master_grant"
      gate_order = "lpc_honghua"
      perform_id = "huilong-bifa/cang"
      skill = "huilong-bifa"
      min_levels = {
        force = 160
        huilong_bifa = 120
      }
      level_order = ["force", "huilong_bifa"]
      level_deny = {
        force = "你的内功火候不足，学不成这一招。"
        huilong_bifa = "你的回龙璧法还练得不到家，自己下去练练再来吧！"
      }
      min_gongxian = 600
      min_shen = 30000
      cost_gongxian = 600
      family = "红花会"
      maxed = "这招我不是早传授给你了吗？"
      family_deny = "和本教素无瓜葛，何出此言？"
      skill_deny = "你连回龙璧法都没学，还谈什么绝招可言？"
      gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
      shen_deny = "你侠义正事做得不够，这招我不能传你。"
      msg_one = "$n哈哈一笑，将$N招至跟前，轻声在耳旁秘密说了些什么。随后又伸出右手，十指箕张，一伸一缩，看样子是一种很特别的暗器法门。"
      learned = "你学会了「掌藏龙」。"
      improve_skills = ["throwing", "huilong_bifa", "martial_cognize"]
    } }
  ]

''',
)

p.write_bytes(text.replace("\r\n", "\n").encode("utf-8"))
print("step B ok:", len(text), "chars")
