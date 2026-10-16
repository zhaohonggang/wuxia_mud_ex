#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P1a: plan the mapping from lost LPC `set()` keys to UCL/loader fields.

Reads `tmp/lost_key_triage.json` and, for each key, answers the three questions
from
`docs/data-world-conversion-framework-first.zh-CN.md` §1:

    Q1  can the value be written into UCL at all (is elias able to lex it)?
        no  -> "L3-framework"  (must fix the schema first; converting is useless)
    Q2  does the loader have a field for it?
        no  -> "L2"  (add the field first, then backfill)
        yes -> "L1"  (pure data backfill)
    Q3  is there a consumer?  -- does NOT block conversion; only decides whether
        the value takes effect.  Recorded in `reason`, not used as a gate.

Output `tmp/key_field_map.json`:

    {"key", "occ", "bucket", "target", "decision", "reason"}

`bucket` is `missing` (no field anywhere) or `engine` (the name occurs in lib/,
so a field/consumer probably already exists -> usually L1).

`decision` is one of L1 | L2 | L3-framework | noop | manual.

Both buckets are processed: the plan's P1/P2 batches (B2/B3/B5/B7) draw on
`engine`-bucket keys as well, so planning only the `missing` bucket would leave
the batches unmapped.

IMPORTANT: this is a *draft*.  The plan (§3 P1 step 1) requires a human pass over
every `decision` before any backfill runs.  Anything the script is not confident
about is emitted as `manual`, not guessed.

Read-only: touches nothing under data/world.

Usage:
    python scripts/plan_key_field_map.py
"""
import os
import re
import json
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = os.path.join(ROOT, "tmp")
CORPUS = r"C:\files\git\mud\d"

# Which object kind sets each key?  The same key can land on a room, an item or
# an NPC, and that decides the target (room.flags vs item.meta.flag vs ...).
# NOTE: no trailing \b -- LPC inherits like `COMBINED_ITEM` / `F_ROOM` end the
# token with `_`-joined text, so \bROOM\b would not match `COMBINED_ITEM`.
ROOM_RE = re.compile(r"^\s*inherit\s+[^\n]*ROOM", re.M | re.I)
ITEM_RE = re.compile(r"^\s*inherit\s+[^\n]*(ITEM|OBJECT)", re.M | re.I)
SET_RE = re.compile(r'\bset\s*\(\s*"([^"]+)"')

# ---------------------------------------------------------------------------
# noop -- already decided to be suppressed.  Kept in sync with
# docs/data-world-comments-progress.zh-CN.md §11 and plan §3 P2 "明确免除".
# ---------------------------------------------------------------------------
SUPPRESS = {
    "no_clean_up": "生命周期：房间重置提示，引擎已覆盖",
    "no_cleanup": "同 no_clean_up（拼写变体）",
    "no_map": "显示开关，无消费端",
    "no_shown": "显示开关，无消费端",
    "no_user": "显示开关，无消费端",
    "no_magic": "显示开关，无消费端",
    "max_room": "容量提示，无消费端",
    "env/wimpy": "玩家环境设置（自动逃跑阈值），非对象数据；属玩家侧",
}

# ---------------------------------------------------------------------------
# KNOWN -- keys verified by hand against the loader whitelist / consumers.
# value = (target, decision, reason)
#
# Loader whitelists (plan §2.1):
#   Item.Meta     : damage skill_type armor value weight unit material food
#                   medicine book armor_type weapon_prop armor_prop flag
#                   storage_bag aliases no_sell no_put owner owner_id
#   Room          : id key zone_id name description map_color map_icon x y z
#                   flags features item_desc exit_vetoes behavior behavior_config
#   NonPlayerMeta : ... vitals stats combat_config ... engage carry ...
# ---------------------------------------------------------------------------
KNOWN = {
    # --- B1: NOT a synonym.  `set_weight(N)` writes the private `weight` var;
    #     `set("base_weight", N)` is a *separate* per-unit weight read only for
    #     stackable objects (cmds/std/hand.c L37).  Engine has no `amount` and
    #     no `base_weight` -> needs a stackable-item subsystem.
    "base_weight": (None, "L3-framework",
                    "堆叠物品的『单件重量』，与 weight（总重）语义不同；"
                    "hand.c L37 用 query_amount()?base_weight:query_weight() 区分。"
                    "引擎无 amount / base_weight 字段，属框架优先"),

    # --- B2: sub-keys rejected by sanitize_prop (Combat.applies_keys/0)
    "armor_prop/personality": ("item.meta.armor_prop", "L2",
                               "子键 personality 不在 Combat.applies_keys()，"
                               "写进 armor_prop 也会被 sanitize_prop 静默丢弃（风险 R2）"),
    "weapon_prop/personality": ("item.meta.weapon_prop", "L2",
                                "同 armor_prop/personality（R2）"),
    "armor_prop/warm": ("item.meta.armor_prop", "L2",
                        "子键 warm 不在 applies_keys（R2）"),
    "armor_prop/armor_vs_force": ("item.meta.armor_prop", "L2",
                                  "子键 armor_vs_force 不在 applies_keys（R2）"),

    # --- B2: base_unit / base_value are **NOT** synonyms of unit / value.
    #     Same trap as base_weight: the bare name describes the *whole stack*,
    #     base_* describes ONE unit of it.
    #       inherit/item/combined.c   set_amount(): set("value", amount * base_value);
    #                                 short():      chinese_number(amount) + base_unit + ...
    #                                 setup():      unit defaults to "些"
    #       clone/money/coin.c        unit="些"   base_unit="文"     (both set, differ)
    #       d/beijing/npc/obj/jinbiao.c  unit="些" value=2000  base_unit="支" base_value=4000
    #     Engine has no `amount` field -> cannot represent stackables at all.
    "base_unit": (None, "L3-framework",
                  "堆叠物品的『单件量词』，与 unit（整叠量词）语义不同："
                  "combined.c short() 用 base_unit，setup() 把 unit 默认成『些』；"
                  "coin.c unit=些/base_unit=文 并存。引擎无 amount 字段 → 框架优先"),
    "base_value": (None, "L3-framework",
                   "堆叠物品的『单件价值』，与 value（整叠价值）语义不同："
                   "combined.c set_amount() 里 set(\"value\", amount*base_value)；"
                   "jinbiao.c value=2000/base_value=4000 并存。引擎无 amount/base_value → 框架优先"),
    "food_supply": ("item.meta.food", "L1",
                    "别名 food_supply→food；item_meta_backfill.py 已处理，本批只对账"),

    # --- B5: equipment messages.  Item.Meta has NO *_msg field -> add field.
    "remove_msg": ("item.meta.remove_msg", "L2", "装备文案；Item.Meta 白名单无此字段"),
    "unequip_msg": ("item.meta.unequip_msg", "L2", "装备文案；同上"),
    "wield_msg": ("item.meta.wield_msg", "L2", "装备文案；Item.Meta 白名单无此字段"),
    "unwield_msg": ("item.meta.unwield_msg", "L2", "装备文案；同上"),
    "wear_msg": ("item.meta.wear_msg", "L2", "装备文案；同上"),

    # --- B6: NPC combat chatter -> NonPlayerMeta add fields
    "chat_msg_combat": ("npc.chat_msg_combat", "L2",
                        "NPC 战斗喊话；NonPlayerMeta 白名单无此字段"),
    "chat_chance_combat": ("npc.chat_chance_combat", "L2",
                           "NPC 战斗喊话概率；同上"),

    # --- B7: room flags.  Room whitelist HAS `flags` (parse_flags/1, loader L428)
    #     and room.ex L223 reads data.flags -> attrs.  So these are pure data.
    "female_only": ("item.meta.female_only", "L2",
                    "**物品**属性（qingpao.c/shoe.c 等 obj/ 下），源消费端 cmds/std/wear.c L75；"
                    "Item.Meta 的 flag 是**武器类型位掩码**（wield_command.ex L101 默认 1=ONE_HANDED，"
                    "loader L1274 `|| 1`，战斗按 & TWO_HANDED 取值）——塞 female_only 会污染武器语义 "
                    "→ 必须新增独立字段"),
    "no_beg": ("room.flags", "L1", "房间 flag：写入已有 flags 列表"),
    "sleep_room": ("room.flags", "L1",
                   "房间 flag：消费端已存在（room.ex L238 → attrs[sleep_room]）；"
                   "只缺数据（全库 .ucl 的 flags 出现 0 次）"),
    "no_sleep_room": ("room.flags", "L1",
                      "房间 flag：消费端已存在（room.ex L239）；只缺数据"),
    "no_steal": ("room.flags", "L1",
                 "房间 flag：消费端已存在（room.ex L1462 context.data.no_steal）；只缺数据"),
    "valid_startroom": ("room.flags", "L1",
                        "出生点标记；引擎消费的是 flag **\"startroom\"**"
                        "（home_command.ex L54 / recall_command.ex L50 `\"startroom\" in room.flags`），"
                        "不是键名本身 → P1b 用 FLAG_NAME 映射为 startroom"),

    # --- B8: container / drink -> add fields
    "max_liquid": ("item.meta.max_liquid", "L2", "容器容量；Item.Meta 白名单无此字段"),
    "can_make": ("item.meta.can_make", "L2", "打造系统；需加字段"),

    # --- field exists in NonPlayerMeta, but the SHAPE does not match -> manual.
    #     LPC value is an array of mappings: ({ ([ "startroom": "/x", "id": "y" ]) })
    #     loader parse_coagents/1 does Enum.map(&to_string/1) -> crashes on a map;
    #     combat_event.ex L435 iterates string ids; guarder.ex L73 expects maps.
    #     The two consumers disagree -> a schema decision is required, not a clean L1.
    "coagents": (None, "manual",
                 "NonPlayerMeta 白名单已含 coagents，但**形状不符**：源值是 mapping 列表"
                 "（startroom+id），parse_coagents/1 做 to_string/1 会崩（String.Chars 无 Map 实现）；"
                 "且消费端不一致（combat_event.ex 要 id 字符串 / guarder.ex 要 map）→ 需先定 schema"),

    # --- B9: crafting -> add fields
    "power_point": ("item.meta.power_point", "L2", "打造系统；需加字段"),
    "item_origin": ("item.meta.item_origin", "L2", "打造系统；需加字段"),
    "not_make": ("item.meta.not_make", "L2", "打造系统；需加字段"),

    # --- B11: room ownership -> add fields
    "room_owner": ("room.room_owner", "L2", "房间归属；Room 白名单无此字段"),
    "room_name": ("room.room_name", "L2", "房间归属；同上"),
    "room_position": ("room.room_position", "L2", "房间归属；同上"),
    "room_owner_id": ("room.room_owner_id", "L2", "房间归属；同上"),

    # --- explicitly unresolved in the plan -> do NOT guess
    "max_force": (None, "manual", "NPC vitals；计划 B4 明确要求『先查 vitals 结构再定』"),
    "force_factor": (None, "manual", "NPC vitals/combat；同 B4"),
    "max_mana": (None, "manual", "NPC vitals；同 B4"),
    "mana": (None, "manual", "NPC vitals；同 B4"),
    "max_kee": (None, "manual", "NPC vitals（kee=qi 旧名）；同 B4"),
    "max_sen": (None, "manual", "NPC vitals（sen=jing 旧名）；同 B4"),
    "max_gin": (None, "manual", "NPC vitals（gin=精 旧名）；同 B4"),
    "max_neli": (None, "manual", "NPC vitals（neili=内力）；同 B4"),
    "mana_factor": (None, "manual", "NPC vitals；同 B4"),
    "jingli_factor": (None, "manual", "NPC vitals；同 B4"),
    "eff_qi": (None, "manual", "NPC vitals；同 B4"),
    "eff_jing": (None, "manual", "NPC vitals；同 B4"),
    "parts": (None, "manual",
              "源对象是**物品**（item×1），而 NonPlayerMeta.parts 是 NPC 字段 → 目标不匹配，需人工定"),
    "default_long": (None, "manual", "疑似房间兜底描述，但可能是动态生成 → 需回源确认"),
    "liquid_type": (None, "manual", "容器/酒水；需先确认 liquid 通道（B8 未决）"),
    "water_supply": (None, "manual", "食物/水供给；语义待确认"),
}

# ---------------------------------------------------------------------------
# Q1: elias 0.2.8 hard limits (probe, plan §2.5).
#   - key containing a digit        -> FAIL
#   - key containing a hyphen       -> FAIL
#   - key containing '+' / quotes   -> FAIL
#   - uppercase in the key          -> NOT TESTED by the probe -> manual
# Only the UCL-side name matters, so we look at the last `/` segment.
# ---------------------------------------------------------------------------
DIGIT_OR_SPECIAL = re.compile(r"[0-9\-+'\"]")
UPPERCASE = re.compile(r"[A-Z]")

# ---------------------------------------------------------------------------
# Runtime / quest state heuristics.  These are per-object dynamic state in LPC,
# not load-time data; the engine has no persistent custom-attrs channel
# (Character.meta.temp is session-only and is NOT persisted).
# ---------------------------------------------------------------------------
STATE_SUFFIX = re.compile(
    r"_(count|times|got|improve|percent|number|level|mark|marks|record|trigger"
    r"|owner|type|id|key|content|info|desc|exits|cost|story|header|type)$"
)
STATE_PREFIX = re.compile(r"^(no|not|is|can|had|has|get|got|yell|hs|yl|th)_")


def ucl_name(key):
    """The name that would actually be written into UCL."""
    return key.split("/")[-1]


def file_kind(path, src):
    """room | item | npc -- decided from inherit, with a path fallback."""
    if ROOM_RE.search(src):
        return "room"
    if ITEM_RE.search(src):
        return "item"
    low = path.replace("\\", "/").lower()
    if "/obj/" in low:
        return "item"
    return "npc"


def scan_kinds():
    """{key: Counter({kind: n_files})} over the whole corpus."""
    kinds = {}
    if not os.path.isdir(CORPUS):
        return kinds
    for zone in sorted(os.listdir(CORPUS)):
        zdir = os.path.join(CORPUS, zone)
        if not os.path.isdir(zdir):
            continue
        for root, _, files in os.walk(zdir):
            for fn in files:
                if not fn.endswith(".c"):
                    continue
                p = os.path.join(root, fn)
                try:
                    with open(p, encoding="gbk", errors="replace") as fh:
                        src = fh.read()
                except Exception:
                    continue
                kind = file_kind(p, src)
                for m in SET_RE.finditer(src):
                    kinds.setdefault(m.group(1), Counter())[kind] += 1
    return kinds


def classify(key, occ, kinds=None):
    if key in SUPPRESS:
        return None, "noop", SUPPRESS[key]
    if key in KNOWN:
        return KNOWN[key]

    name = ucl_name(key)
    kc = (kinds or {}).get(key)
    kind_hint = ""
    if kc:
        kind_hint = "（源对象类型：" + "/".join(f"{k}×{n}" for k, n in kc.most_common()) + "）"

    # `base_*` family: describes ONE unit of a stackable object, while the bare
    # name describes the whole stack (base_weight / base_unit / base_value).
    # Never treat base_* as a synonym of the bare name -- the engine has no
    # `amount`/stackable subsystem, so it is framework-first by construction.
    if name.startswith("base_"):
        return None, "L3-framework", (
            f"base_* 属『单件』语义族（{name}），与裸名（整叠）不同；"
            "引擎无 amount / stackable 子系统 → 框架优先" + kind_hint
        )

    # Q1 -- elias cannot lex it; must fix schema first (never write it).
    if DIGIT_OR_SPECIAL.search(name):
        return None, "L3-framework", (
            f"Q1 ❌：UCL 侧名字 {name!r} 含数字/连字符/特殊字符，"
            "elias 词法化失败（探针实测），必须改命名方案才能转" + kind_hint
        )
    if UPPERCASE.search(name):
        return None, "manual", (
            f"Q1 ?：UCL 侧名字 {name!r} 含大写，探针未覆盖此情形，需先实测" + kind_hint
        )

    # Q3-only concerns -- runtime state, no persistent channel.
    if "/" in key:
        return None, "L3-framework", (
            "命名空间状态（a/b）：LPC 里是对象动态状态，非加载期数据；"
            "引擎无通用持久 attrs 通道（Character.meta.temp 是会话级、不落盘）" + kind_hint
        )
    if STATE_SUFFIX.search(key):
        return None, "L3-framework", (
            "运行态计数器/任务进度 flag：LPC 里是对象动态状态，非加载期数据；"
            "引擎无通用持久 attrs 通道（Character.meta.temp 是会话级、不落盘）" + kind_hint
        )
    if STATE_PREFIX.search(key):
        return None, "manual", (
            f"疑似 flag（{name}）：需确认承载通道（room.flags / item.flag）"
            "以及是否有消费端" + kind_hint
        )

    return None, "manual", "未归类：需人工判断三问（脚本不做猜测）" + kind_hint


def main():
    src = os.path.join(TMP, "lost_key_triage.json")
    with open(src, encoding="utf-8") as fh:
        triage = json.load(fh)

    rows = []
    kinds = scan_kinds()
    for bucket in ("engine", "missing"):
        for key, occ in triage[bucket].items():
            target, decision, reason = classify(key, occ, kinds)
            kc = kinds.get(key)
            rows.append({
                "key": key,
                "occ": occ,
                "bucket": bucket,
                "kinds": dict(kc) if kc else {},
                "target": target,
                "decision": decision,
                "reason": reason,
            })
    rows.sort(key=lambda r: (-r["occ"], r["key"]))

    out = os.path.join(TMP, "key_field_map.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=1)

    # ---- report ----------------------------------------------------------
    from collections import Counter, defaultdict
    by_decision = defaultdict(list)
    for r in rows:
        by_decision[r["decision"]].append(r)

    print(f"keys: {len(rows)}   occ: {sum(r['occ'] for r in rows)}")
    print(f"wrote {os.path.relpath(out, ROOT)}\n")
    print("-- decision summary --")
    for d in ("L1", "L2", "L3-framework", "noop", "manual"):
        rs = by_decision[d]
        print(f"  {d:14s} {len(rs):4d} keys  {sum(r['occ'] for r in rs):5d} occ")

    print("\n-- L1 (pure data, do first) --")
    for r in by_decision["L1"]:
        kd = "/".join(f"{k}×{n}" for k, n in sorted(r["kinds"].items())) or "?"
        print(f"  {r['key']:28s}{r['occ']:5d} [{r['bucket']:7s}] {kd:22s} -> {r['target']}")

    print("\n-- L2 (add field first) --")
    for r in by_decision["L2"]:
        kd = "/".join(f"{k}×{n}" for k, n in sorted(r["kinds"].items())) or "?"
        print(f"  {r['key']:28s}{r['occ']:5d} [{r['bucket']:7s}] {kd:22s} -> {r['target']}")

    print("\n-- L3-framework (schema first, DO NOT convert yet) --")
    for r in by_decision["L3-framework"]:
        print(f"  {r['key']:28s}{r['occ']:5d}  {r['reason'][:60]}")

    print("\n-- manual (human must decide) --")
    for r in by_decision["manual"]:
        print(f"  {r['key']:28s}{r['occ']:5d}  {r['reason'][:60]}")

    print("\nNOTE: this is a DRAFT. Plan §3 P1 requires a human pass over every"
          " decision before any backfill runs.")


if __name__ == "__main__":
    main()
