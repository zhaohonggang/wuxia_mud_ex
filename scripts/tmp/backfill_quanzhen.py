"""Idempotent backfill for kungfu/class/quanzhen teaching data."""
from pathlib import Path
import re

PATH = Path(r"C:\files\git\wuxia_mud_ex\data\world\clone_lib.ucl")
text = PATH.read_text(encoding="utf-8")

CLASS_NPCS = [
    "quanzhen_chen", "quanzhen_cheng", "quanzhen_cui", "quanzhen_fang",
    "quanzhen_hao", "quanzhen_ji", "quanzhen_li", "quanzhen_liu",
    "quanzhen_ma", "quanzhen_pi", "quanzhen_qi", "quanzhen_qiu",
    "quanzhen_shen", "quanzhen_sun", "quanzhen_tan", "quanzhen_wang",
    "quanzhen_wangchuyi", "quanzhen_wangzhi", "quanzhen_yin",
    "quanzhen_zhang", "quanzhen_zhao", "quanzhen_zhou",
]

NEIGONG_DENY = "你的本门内功心法火候不足，难以领略更高深的武功。"
TAOISM_DENY = "你在修身养性方面还需多加锻炼，等你道学心法够高后再来吧。"
SHEN_DENY = "你这人行侠仗义的事情做得太少！"
GX_DENY = "你在我全真教内甚无作为，这招我暂时还不能传你。"

# recruit profile -> exact LPC gates and literal texts
APPRENTICES = {
    "quanzhen_chen": {"profile": "simple", "accept": "好吧，我就收下你这个徒弟。"},
    "quanzhen_cheng": {"profile": "simple", "accept": "…嗯…那我就暂时收下你好了。"},
    "quanzhen_cui": {"profile": "simple", "accept": "好吧，我就收下你这个徒弟。"},
    "quanzhen_fang": {"profile": "simple", "accept": "那你以后就跟着我吧。"},
    "quanzhen_ji": {"deny_all": True, "deny_msg": "对…对不起。我也是刚入门不久。"},
    "quanzhen_li": {
        "profile": "shen", "min_shen": 3000,
        "min_shen_deny": "你行侠仗义之事做得太少，我不能收你。",
        "accept": "好吧，我就收下你这个徒弟了。",
    },
    "quanzhen_pi": {"deny_all": True, "deny_msg": "我…我也才刚拜师不久，怎能收徒。"},
    "quanzhen_qi": {
        "profile": "shen", "min_shen": 2000,
        "min_shen_deny": "你行侠仗义之事做得太少，我不能收你。",
        "accept": "好吧，那你就跟着我，没事帮忙打打下手也好。",
    },
    "quanzhen_shen": {"profile": "simple", "accept": "那你就跟着我吧。"},
    "quanzhen_wangzhi": {"profile": "simple", "accept": "那你就跟着我吧。"},
    "quanzhen_zhang": {"profile": "simple", "accept": "好吧，我就收下你这个徒弟。"},
    "quanzhen_zhao": {"profile": "simple", "accept": "好吧，我就收下你这个徒弟。"},
    "quanzhen_hao": {
        "profile": "hao", "any": 60, "taoism": 60, "min_shen": 8000,
        "accept": "好吧，我就收下你了。",
    },
    "quanzhen_liu": {
        "profile": "liu", "any": 100, "taoism": 100, "min_shen": 25000,
        "accept": "既然如此，那你以后就跟着我吧。",
    },
    "quanzhen_ma": {
        "profile": "ma", "any": 120, "taoism": 120, "min_exp": 200000,
        "min_exp_deny": "你的实战经验太差，看来难以领略更高深的武功。",
        "min_shen": 30000,
        "min_shen_deny": "行侠仗义是我辈学武人的宗旨，你这方面还做得不够。",
        "accept": "不错，不错。念你如此有心，我就收下你。",
    },
    "quanzhen_sun": {
        "profile": "sun", "any": 60, "taoism": 60, "min_shen": 8000,
        "accept": "好吧，我就收下你了。",
    },
    "quanzhen_tan": {
        "profile": "tan", "any": 100, "taoism": 100, "min_shen": 30000,
        "accept": "甚好，甚好。",
    },
    "quanzhen_wangchuyi": {
        "profile": "wangchuyi", "any": 80, "taoism": 80, "min_shen": 10000,
        "accept": "好吧，我就收下你了。",
    },
    "quanzhen_yin": {
        "profile": "yin", "any": 30,
        "any_min_skills_deny": "你的内功心法火候不足，再多练练吧。",
        "min_shen": 3000,
        "min_shen_deny": "你行侠仗义之事做得太少，我不能收你。",
        "accept": "既然如此，我就收下你这个徒弟。",
    },
    "quanzhen_qiu": {
        "profile": "qiu", "any": 100,
        "any_min_skills_deny": "你连本门最基本的内功都未练足，叫我如何收你？",
        "sword": 100,
        "sword_deny": "你的剑法差成这样，如何能够杀敌？",
        "min_shen": 25000,
        "min_shen_deny": "你目前表现太差！多做点行侠仗义的事再来找我！",
        "accept": "我收下你便是，但你可别坏了我们全真七子的名头。假如某日我知道你在外面作恶，照样会杀了你。",
    },
    "quanzhen_wang": {
        "profile": "wang", "hard_min_int": 35,
        "int_deny": "你的悟性还不够，还是先找我那几个徒弟学习吧。",
        "any": 120,
        "any_min_skills_deny": "你的本门内功心法火候不足，只怕难以领略更高深的武功。",
        "min_exp": 450000,
        "min_exp_deny": "你的实战经验太差，看来难以领略更高深的武功。",
        "min_shen": 80000,
        "min_shen_deny": "行侠仗义是我辈学武人的宗旨，你多做些侠义之事，我方能收你为徒。",
        "accept": "不错，以你资质定可传我衣钵！我就收下你这个徒弟了。",
    },
    "quanzhen_zhou": {
        "profile": "zhou", "min_exp": 400000,
        "min_exp_deny": "你经验这么差，还是去找我那几个师侄教你吧。",
        "min_shen": 50000,
        "min_shen_deny": "你这人品行不好，跟你一起肯定做不了什么好事。",
        "accept": "反正最近也没啥事干，就收下你玩玩吧。",
    },
}

CHAT = {
    "quanzhen_chen": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_cheng": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_cui": ["recover", "perform sword.xing", "perform strike.lian"],
    "quanzhen_fang": ["recover", "perform sword.xing", "perform strike.lian"],
    "quanzhen_hao": ["perform hand.po", "powerup", "recover"],
    "quanzhen_ji": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_li": ["recover", "perform sword.chan", "perform sword.ding", "perform strike.lian"],
    "quanzhen_liu": ["perform sword.ding", "perform sword.chan", "perform hand.po", "perform strike.ju", "powerup", "recover"],
    "quanzhen_ma": ["perform hand.po", "perform parry.suo", "perform strike.ju", "recover", "powerup"],
    "quanzhen_pi": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_qi": ["recover", "perform sword.xing", "perform finger.zhi", "perform strike.lian"],
    "quanzhen_qiu": ["perform sword.ding", "perform sword.chan", "perform hand.po", "perform strike.ju", "powerup", "recover"],
    "quanzhen_shen": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_sun": ["perform whip.bai", "perform finger.zhi", "perform strike.lian", "powerup", "recover"],
    "quanzhen_tan": ["perform hand.po", "perform strike.ju", "powerup", "recover"],
    "quanzhen_wang": ["perform unarmed.hun", "perform unarmed.fen", "perform unarmed.dang", "perform unarmed.jian", "perform parry.suo", "hup", "shield", "recover", "powerup"],
    "quanzhen_wangchuyi": ["perform sword.chan", "perform sword.ding", "perform strike.ju", "powerup", "recover"],
    "quanzhen_wangzhi": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_yin": ["perform sword.xing", "perform finger.zhi", "perform strike.lian", "powerup", "recover"],
    "quanzhen_zhang": ["recover", "perform sword.xing", "perform strike.lian"],
    "quanzhen_zhao": ["recover", "perform sword.xing", "perform finger.zhi"],
    "quanzhen_zhou": ["perform unarmed.ruo and unarmed.kong", "perform parry.suo and unarmed.kong", "perform unarmed.kong twice", "perform dodge.guiyuan", "recover", "powerup"],
}

APPLY = {
    "quanzhen_liu": (100, 100, 200),
    "quanzhen_ma": (100, 100, 200),
    "quanzhen_qiu": (100, 100, 200),
    "quanzhen_tan": (100, 100, 200),
    "quanzhen_wang": (100, 100, 200),
    "quanzhen_zhou": (200, 200, 600),
}

NO_TEACH_EXTRA = {
    "quanzhen_wang": '      yiyang_zhi = "一阳指乃是段家秘传，我不能教你。"\n',
    # LPC zhou.c:83-85 三个 no_teach 文本（硬拒），此前漏建。
    "quanzhen_zhou": (
        '      xiantian_gong = "这个我也没弄清楚，你还是去找我师兄学吧。"\n'
        '      yijin_duangu = "这玩意我还正在想法忘记，不能教你。"\n'
        '      shexing_lifan = "这玩意我还正在想法忘记，不能教你。"\n'
    ),
}

# 周伯通 recognize_apprentice 的标志门（LPC zhou.c:151-168）：
# 只有带 `can_learn/zuoyou-hubo/zhou` 标记（由 accept_fight->lost() 写入）才教左右互搏，
# 经验再多也不能解锁；其余技能走「你教我还差不多」。
ZHOU_UNLOCK_ENTRY = """      zuoyou_hubo = {
        unlock = {
          mark = "can_learn/zuoyou-hubo/zhou"
          require_mark_only = true
          restricted_skill = "zuoyou-hubo"
          locked = "做了个鬼脸，说道：我又不是你师父，为啥要教你？"
          wrong_skill_deny = "你的武功比我还好，你教我还差不多。"
        }
      }
"""

# 绝招门的 shen 拒绝文案：LPC 每个 ask_skill* 都写同一句侠义文案，
# 旧 UCL 误抄成收徒文案（收徒文案仍是另一句，min_shen_deny 保留）。
GRANT_SHEN_LPC = "你的侠义正事还做得不够，这招我暂时还不能传你。"
GRANT_NEILI_DENY = "你的内力修为仍不足，还是练高点再来吧。"

COAGENTS_QIU = """  coagents = [
    { id = "ma yu" startroom = "quanzhen:shiweishi" },
    { id = "wang chuyi" startroom = "quanzhen:wanwutang" }
  ]
"""

LIU_INQUIRIES = """  inquiries = [
    { key = "连环掌" value = {
      kind = "sect_master_grant"
      perform_id = "chongyang-shenzhang/lian"
      skill = "chongyang-shenzhang"
      gate_order = "lpc_quanzhen"
      family = "全真教"
      min_gongxian = 100
      cost_gongxian = 100
      min_shen = 10000
      family_deny = "阁下与贫道素不相识，不知此话从何说起？"
      skill_deny = "你连重阳神掌都没学，何谈绝招可言？"
      gongxian_deny = "你在我全真教内甚无作为，这招我暂时还不能传你。"
      shen_deny = "你的侠义正事还做得不够，这招我暂时还不能传你。"
      level_deny = {
        chongyang_shenzhang = "你的重阳神掌不够娴熟，练高点再来吧。"
        force = "你的内功修为不够，修炼高后再来找我吧。"
      }
      min_levels = {
        chongyang_shenzhang = 100
        force = 120
      }
      level_order = ["chongyang-shenzhang", "force"]
      maxed = "这招我不是已经教会你了吗？"
      msg_one = "$n眉头一皱，上下打量了$N一番，当下更不答话，衣袖轻轻一抖，猛然大喝一声，顿时双掌纷飞，掌劲朝四面八方云贯而出，气势恢弘之极。"
      learned = "你学会了「重阳连环掌」。"
      improve_skills = ["strike", "chongyang-shenzhang", "martial-cognize"]
    } },
    { key = "重阳连环掌" value = {
      kind = "sect_master_grant"
      perform_id = "chongyang-shenzhang/lian"
      skill = "chongyang-shenzhang"
      gate_order = "lpc_quanzhen"
      family = "全真教"
      min_gongxian = 100
      cost_gongxian = 100
      min_shen = 10000
      family_deny = "阁下与贫道素不相识，不知此话从何说起？"
      skill_deny = "你连重阳神掌都没学，何谈绝招可言？"
      gongxian_deny = "你在我全真教内甚无作为，这招我暂时还不能传你。"
      shen_deny = "你的侠义正事还做得不够，这招我暂时还不能传你。"
      level_deny = {
        chongyang_shenzhang = "你的重阳神掌不够娴熟，练高点再来吧。"
        force = "你的内功修为不够，修炼高后再来找我吧。"
      }
      min_levels = {
        chongyang_shenzhang = 100
        force = 120
      }
      level_order = ["chongyang-shenzhang", "force"]
      maxed = "这招我不是已经教会你了吗？"
      msg_one = "$n眉头一皱，上下打量了$N一番，当下更不答话，衣袖轻轻一抖，猛然大喝一声，顿时双掌纷飞，掌劲朝四面八方云贯而出，气势恢弘之极。"
      learned = "你学会了「重阳连环掌」。"
      improve_skills = ["strike", "chongyang-shenzhang", "martial-cognize"]
    } }
  ]
"""


def block_span(src, key):
    marker = '    characters "%s" {' % key
    start = src.index(marker)
    starts = [m.start() for m in re.finditer(r'(?m)^    characters "', src)]
    next_start = min((s for s in starts if s > start), default=len(src))
    close = src.rfind("\n    }\n", start, next_start)
    if close == -1:
        raise RuntimeError("unterminated block: " + key)
    return start, close + len("\n    }\n")


def value_span(src, start):
    """Given a match start of a top-level field line, return full assignment span."""
    eq = src.index("=", start)
    i = eq + 1
    while i < len(src) and src[i] in " \t":
        i += 1
    if i < len(src) and src[i] in "{[":
        stack = []
        in_str = False
        esc = False
        while i < len(src):
            c = src[i]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c in "{[":
                    stack.append(c)
                elif c in "}]":
                    if not stack:
                        raise RuntimeError("unbalanced at %d" % i)
                    stack.pop()
                    if not stack:
                        i += 1
                        break
            i += 1
    else:
        while i < len(src) and src[i] not in "\r\n":
            i += 1
    j = src.find("\n", i)
    return start, (j + 1 if j != -1 else i)


def field_span(src, field):
    match = re.search(r"(?m)^  %s\s*=" % re.escape(field), src)
    return value_span(src, match.start()) if match else None


def set_field(src, field, body):
    span = field_span(src, field)
    if span:
        return src[:span[0]] + body + src[span[1]:]
    # 缺字段时插在引用它的后一个字段之前（字段顺序稳定、diff 干净）：
    # teach / no_teach_unlock / apprentice 三者互相引用，不能插在 carry 之后。
    successors = {
        "teach": ["apprentice", "engage", "combat_event", "carry"],
        "no_teach_unlock": ["apprentice", "engage", "combat_event", "carry"],
        "apprentice": ["engage", "combat_event", "carry"],
    }
    for succ in successors.get(field, []):
        anchor = src.find("\n  %s = " % succ)
        if anchor != -1:
            return src[:anchor + 1] + body + src[anchor + 1:]
    anchor = src.rfind("\n    }")
    return src[:anchor + 1] + body + src[anchor + 1:]


# 每个 (NPC, 绝招 key) 的有序等级门配置，逐字抄自 LPC ask_skill*：
#   (min_levels, level_order, level_deny, maxed 文案覆写 or None)
# - `min_levels` / `level_deny` 的键必须是 **UCL 合法标识符**：下划线形态
#   （`tonggui_jian`），不能写连字符 `tonggui-jian`——后者 Elias 直接
#   `syntax error before: "-"`（loader 再统一归一为连字符）。
# - `level_order` 是字符串数组，用连字符 id（与 loader 归一结果一致）。
# - `max_neili` 是伪技能键，loader 归一成 `max-neili`。
# 老 UCL 已确认的三类静默偏差，本表逐条修掉：
#   1) level_deny 漏 `max_neili` 整行（内力不足时落回通用「你的修为还不够…」）；
#   2) 把「未学该技能」塞进 level_deny（LPC 里 `< 1` 属 skill_deny，`< N` 才是等级门）；
#   3) 王重阳「一气化三清」把 `quanzhen_jian` 写成连字符（同名技能键不一致）。
GRANT_LEVELS = {
    ("quanzhen_hao", "破穹云蛟"): (
        {"qixing_shou": 150, "force": 200},
        ["qixing-shou", "force"],
        {
            "qixing_shou": "你的七星分天手不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_liu", "连环掌"): (
        {"chongyang_shenzhang": 100, "force": 120},
        ["chongyang-shenzhang", "force"],
        {
            "chongyang_shenzhang": "你的重阳神掌不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_ma", "玄门金锁"): (
        {"jinguan_yusuo": 150, "force": 200},
        ["jinguan-yusuo", "force"],
        {
            "jinguan_yusuo": "你的金关玉锁不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_qiu", "玉石俱焚"): (
        {"tonggui_jian": 120, "force": 150, "max_neili": 1500},
        ["tonggui-jian", "force", "max-neili"],
        {
            "tonggui_jian": "你的同归剑法不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
            "max_neili": "你的内力修为不够，修炼高后再来找我吧。",
        },
        "我不是已经教你了吗，你这人怎么凭的罗嗦！",
    ),
    ("quanzhen_sun", "朝拜天罡"): (
        {"tiangang_chenfa": 120, "max_neili": 1500},
        ["tiangang-chenfa", "max-neili"],
        {
            "tiangang_chenfa": "你的天罡尘法不够娴熟，练高点再来吧。",
            "max_neili": "你的内力修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_tan", "三花聚顶"): (
        {"haotian_zhang": 120, "force": 180},
        ["haotian-zhang", "force"],
        {
            "haotian_zhang": "你的昊天掌不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_wang", "五气朝元"): (
        {"xiantian_gong": 200, "max_neili": 2000},
        ["xiantian-gong", "max-neili"],
        {
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        None,
    ),
    ("quanzhen_wang", "一气化三清"): (
        {"quanzhen_jian": 200, "xiantian_gong": 100, "max_neili": 4500},
        ["quanzhen-jian", "xiantian-gong", "max-neili"],
        {
            "quanzhen_jian": "你对我派剑法的了解还不够透彻，研究透了再来找我吧。",
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        "你全真剑法已达如此造诣，我已没什么可教的了。",
    ),
    # 化三清 = 一气化三清的别名条目（同一 perform_id），阈值/文案完全一致。
    ("quanzhen_wang", "化三清"): (
        {"quanzhen_jian": 200, "xiantian_gong": 100, "max_neili": 4500},
        ["quanzhen-jian", "xiantian-gong", "max-neili"],
        {
            "quanzhen_jian": "你对我派剑法的了解还不够透彻，研究透了再来找我吧。",
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        "你全真剑法已达如此造诣，我已没什么可教的了。",
    ),
    ("quanzhen_wang", "天地混元"): (
        {"xiantian_gong": 200, "max_neili": 4000},
        ["xiantian-gong", "max-neili"],
        {
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        "这招你不是已经学会了吗？",
    ),
    ("quanzhen_wang", "五阴焚灭"): (
        {"xiantian_gong": 240, "max_neili": 4000},
        ["xiantian-gong", "max-neili"],
        {
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        None,
    ),
    ("quanzhen_wang", "神威浩荡"): (
        {"xiantian_gong": 240, "max_neili": 5000},
        ["xiantian-gong", "max-neili"],
        {
            "xiantian_gong": "你先天功的修为不够，还是练高了再来吧。",
            "max_neili": "你的内力修为仍不足，还是练高点再来吧。",
        },
        "这招你不是已经学会了吗？",
    ),
    ("quanzhen_wangchuyi", "缠字诀"): (
        {"quanzhen_jian": 80, "force": 100},
        ["quanzhen-jian", "force"],
        {
            "quanzhen_jian": "你的全真剑法不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_wangchuyi", "定阳针"): (
        {"quanzhen_jian": 100, "force": 150},
        ["quanzhen-jian", "force"],
        {
            "quanzhen_jian": "你的全真剑法不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_yin", "剑指南山"): (
        {"zhongnan_zhi": 60, "force": 80},
        ["zhongnan-zhi", "force"],
        {
            "zhongnan_zhi": "你的终南指法不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_yin", "群星璀璨"): (
        {"qixing_jian": 60, "force": 80},
        ["qixing-jian", "force"],
        {
            "qixing_jian": "你的七星剑法不够娴熟，练高点再来吧。",
            "force": "你的内功修为不够，修炼高后再来找我吧。",
        },
        None,
    ),
    ("quanzhen_yin", "三连环"): (
        {"quanzhen_jian": 180, "max_neili": 2500},
        ["quanzhen-jian", "max-neili"],
        {
            "quanzhen_jian": "你的全真剑法不够娴熟，练高点再来吧。",
            "max_neili": "你的内力修为不够，还是练高点再来吧。",
        },
        None,
    ),
    ("quanzhen_zhou", "空明若玄"): (
        {"kongming_quan": 100, "max_neili": 1000},
        ["kongming-quan", "max-neili"],
        {
            "kongming_quan": "你的空明拳还练得不够好，下次再说吧。",
            "max_neili": "你的内力差成这样，真不知道你是怎么练功的。",
        },
        None,
    ),
    ("quanzhen_zhou", "空空如也"): (
        {"kongming_quan": 150, "max_neili": 2000},
        ["kongming-quan", "max-neili"],
        {
            "kongming_quan": "你的空明拳还练得不够好，下次再说吧。",
            "max_neili": "你的内力差成这样，真不知道你是怎么练功的。",
        },
        None,
    ),
}


def fix_grant_levels(block):
    """逐条重写 quanzhen 绝招门的 min_levels / level_order / level_deny（+ 个别 maxed）。

    老 UCL 里这三项只按「第一个技能」生成，与 LPC ask_skill* 的真实门序/阈值
    有系统性偏差（尤其 max_neili 整行缺失、force 门缺失），这里按
    (NPC, 绝招名) 查表一次性对齐。表外条目原样保留，零改动。"""
    m = re.search(r'(?m)^    characters "(\w+)" \{', block)
    if not m:
        return block
    key = m.group(1)

    # 单块匹配：老 UCL 里 `min_levels` / `level_order` / `level_deny` 的**排列顺序
    # 本身就不一致**（有的NPC是 min_levels→level_deny→level_order），不能用
    # 「三段连着」的大正则一次吞；逐块查表重写更稳。
    def block_repl(field, builder):
        def _do(m):
            indent = re.match(r"^(\s*)", m.group(0)).group(1)
            head = m.string[: m.start()]
            names = re.findall(r'(?m)^    \{ key = "([^"]+)" value = \{', head)
            name = names[-1] if names else None
            spec = GRANT_LEVELS.get((key, name))
            if not spec:
                return m.group(0)
            return builder(spec, indent)

        return _do

    def build_levels(spec, indent):
        levels = spec[0]
        inner = indent + "  "
        out = "%smin_levels = {\n" % indent
        for k, v in levels.items():
            out += "%s%s = %d\n" % (inner, k, v)
        return out + "%s}\n" % indent

    def build_order(spec, indent):
        order = spec[1]
        return "%slevel_order = [%s]\n" % (
            indent,
            ", ".join('"%s"' % k for k in order),
        )

    def build_denies(spec, indent):
        denies = spec[2]
        inner = indent + "  "
        out = "%slevel_deny = {\n" % indent
        for k, v in denies.items():
            out += '%s%s = "%s"\n' % (inner, k, v)
        return out + "%s}\n" % indent

    block = re.sub(
        r"(?ms)^[ \t]*min_levels = \{\n.*?^[ \t]*\}\n",
        block_repl("levels", build_levels),
        block,
    )
    block = re.sub(
        r"(?m)^[ \t]*level_order = \[[^\]]*\][ \t]*\n",
        block_repl("order", build_order),
        block,
    )
    block = re.sub(
        r"(?ms)^[ \t]*level_deny = \{\n.*?^[ \t]*\}\n",
        block_repl("denies", build_denies),
        block,
    )
    return block


def coagents_block(src, field):
    """按 `  field = [` 起、值域内括号配平找到结尾 `  ]` 行，返回 (start, end)。
    不能用非贪婪正则——UCL 里 coagents 元素本身也是 {}。"""
    match = re.search(r"(?m)^  %s\s*=\s*\[" % re.escape(field), src)
    if not match:
        return None
    start = match.start()
    i = src.index("[", match.start())
    depth = 0
    while i < len(src):
        c = src[i]
        if c == '"':
            i += 1
            while i < len(src) and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
        elif c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
            if depth == 0:
                end = src.find("\n", i)
                return start, (end + 1 if end != -1 else i)
        i += 1
    raise RuntimeError("unbalanced %s" % field)


def fix_grant_shen_deny(block):
    """绝招门（kind = sect_master_grant）的 shen_deny 按 LPC ask_skill* 逐字统一；
    收徒门（min_shen_deny）的文案是另一句，不能一起改。"""
    parts = re.split(r"(?m)(?=      kind = \")", block)
    out = [parts[0]]
    for part in parts[1:]:
        if part.startswith('      kind = "sect_master_grant"'):
            part = re.sub(
                r"(?m)^(      shen_deny = )\"[^\"]*\"",
                lambda m: m.group(1) + '"%s"' % GRANT_SHEN_LPC,
                part,
                count=1,
            )
        out.append(part)
    return "".join(out)


def has_no_teach_unlock(src):
    """只认真正的 `no_teach_unlock = {` 段；不能写 `"no_teach_unlock" not in block`——
    每次重写 teach 时旧值已被自己的正文命中，导致永久跳过。"""
    return re.search(r"(?m)^(\s*)no_teach_unlock\s*=\s*\{", src) is not None


def teach_body(block, key):
    pairs = []
    for skill, level in re.findall(r'\{ skill = "([^"]+)" level = (\d+) \}', block):
        var = skill.replace("-", "_")
        if var not in [p[0] for p in pairs]:
            pairs.append((var, int(level)))
    lines = ["  teach = {", '    family = "全真教"', "    teach_skills = {"]
    for var, level in pairs:
        lines.append("      %s = { max = %d gongxian = 0 }" % (var, level))
    lines.append("    }")
    extra = NO_TEACH_EXTRA.get(key)
    if extra:
        lines.append("    no_teach = {")
        lines.append(extra.rstrip("\n"))
        lines.append("    }")
    # #968 周伯通 recognize_apprentice：左右互搏只在 accept_fight->lost() 落 mark 后教。
    # 走 `no_teach` 的 map 形态（`zuoyou_hubo = { unlock = { ... } }`），与苗家
    # miaojiajian 同形，loader 的 no_teach_unlock 抽取只认 `unlock` 子键。
    # 该键由下面统一并入 no_teach 段（见 merge_zhou_unlock），不在这里追加，
    # 否则会与 NO_TEACH_EXTRA 的 no_teach 段重复两块。
    lines.append("  }")
    return "\n".join(lines) + "\n"


def merge_zhou_unlock(block):
    """把 zuoyou_hubo 的 unlock 条件并入已有 no_teach 段（同一块内，不另开段）。
    LPC zhou.c:83-85 的三个 no_teach 文本 + zuoyou_hubo 的条件解锁必须并存于
    `teach.no_teach` map，loader 才能同时抽出 no_teach_deny 与 no_teach_unlock。"""
    if not re.search(r"(?m)^    no_teach = \{", block):
        return block

    # 已是目标形态 → 不动（幂等）。
    if re.search(r"(?m)^      zuoyou_hubo = \{\n        unlock = \{", block):
        return block

    # 旧形态（独立 no_teach_unlock 段）：整段丢掉，改用 map 形态。
    block = re.sub(
        r"(?ms)^    no_teach_unlock = \{\n.*?^    \}\n",
        "",
        block,
        count=1,
    )

    return re.sub(
        r"(?ms)^(    no_teach = \{\n(?:      \w+ = \"[^\"]*\"\n)+)(    \}\n)",
        lambda m: m.group(1) + ZHOU_UNLOCK_ENTRY + m.group(2),
        block,
        count=1,
    )


def apprentice_body(cfg):
    if cfg.get("deny_all"):
        return (
            '  apprentice = {\n'
            '    family = "全真教"\n'
            '    deny_all = true\n'
            '    deny_msg = "%s"\n'
            '  }\n' % cfg["deny_msg"]
        )
    lines = [
        "  apprentice = {",
        '    family = "全真教"',
        "    permit_recruit = true",
        '    gate_order = "lpc_quanzhen"',
        '    recruit_profile = "%s"' % cfg["profile"],
    ]
    if cfg.get("hard_min_int"):
        lines += [
            "    hard_min_int = %d" % cfg["hard_min_int"],
            '    int_deny = "%s"' % cfg["int_deny"],
        ]
    if cfg.get("any"):
        lines += [
            "    any_min_skills = {",
            "      xuanmen_neigong = %d" % cfg["any"],
            "      quanzhen_xinfa = %d" % cfg["any"],
            "    }",
        ]
    if cfg.get("any_min_skills_deny"):
        lines.append('    any_min_skills_deny = "%s"' % cfg["any_min_skills_deny"])
    elif cfg.get("any"):
        lines.append('    any_min_skills_deny = "%s"' % NEIGONG_DENY)
    if cfg.get("sword"):
        lines += [
            "    min_skills = {",
            "      sword = %d" % cfg["sword"],
            "    }",
            '    sword_deny = "%s"' % cfg["sword_deny"],
        ]
    elif cfg.get("taoism"):
        lines += [
            "    min_skills = {",
            "      taoism = %d" % cfg["taoism"],
            "    }",
            '    taoism_deny = "%s"' % cfg.get("taoism_deny", TAOISM_DENY),
        ]
    if cfg.get("min_exp"):
        lines += [
            "    min_exp = %d" % cfg["min_exp"],
            '    min_exp_deny = "%s"' % cfg["min_exp_deny"],
        ]
    if cfg.get("min_shen"):
        lines += [
            "    min_shen = %d" % cfg["min_shen"],
            '    min_shen_deny = "%s"' % cfg.get("min_shen_deny", SHEN_DENY),
        ]
    lines += ['    accept_msg = "%s"' % cfg["accept"], "  }"]
    return "\n".join(lines) + "\n"


def add_apply(block, key):
    if not re.search(r"(?m)^    apply\s*=", block):
        damage, unarmed, armor = APPLY[key]
        insertion = (
            "    apply = {\n"
            "      damage = %d\n"
            "      unarmed_damage = %d\n"
            "      armor = %d\n"
            "    }\n" % (damage, unarmed, armor)
        )
        marker = "  combat = {\n"
        block = block.replace(marker, marker + insertion, 1)
    return block


changed = []
for key in CLASS_NPCS:
    start, end = block_span(text, key)
    block = text[start:end]
    original = block

    # Display text must not contain literal backslash-n (does not render in Kantele).
    block = block.replace("\\n", "")
    block = fix_grant_levels(block)
    block = fix_grant_shen_deny(block)

    block = set_field(block, "teach", teach_body(block, key))
    block = set_field(block, "apprentice", apprentice_body(APPRENTICES[key]))
    if key == "quanzhen_liu":
        block = set_field(block, "inquiries", LIU_INQUIRIES)
    block = block.replace('gate_order = "lpc_kunlun"', 'gate_order = "lpc_quanzhen"')
    if key in APPLY:
        block = add_apply(block, key)
    if key == "quanzhen_zhou":
        block = merge_zhou_unlock(block)
    if key == "quanzhen_qiu":
        # 已有 coagents 时按值域配平整体替换（不能 set_field：值域嵌套 {} 会吞掉后续字段）。
        span = coagents_block(block, "coagents")
        if span:
            block = block[: span[0]] + COAGENTS_QIU + block[span[1] :]
        else:
            block = set_field(block, "coagents", COAGENTS_QIU)

    chat = CHAT[key]
    block = set_field(block, "chat_chance_combat", "  chat_chance_combat = 120\n")
    block = set_field(
        block,
        "chat_msg_combat",
        "  chat_msg_combat = [%s]\n" % ", ".join('"%s"' % item for item in chat),
    )

    if block != original:
        text = text[:start] + block + text[end:]
        changed.append(key)

with PATH.open("w", encoding="utf-8", newline="\n") as fh:
    fh.write(text)
print("UPDATED:", ", ".join(changed) if changed else "none (idempotent)")
