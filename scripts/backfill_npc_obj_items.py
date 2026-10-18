#!/usr/bin/env python
"""R7/D10 (P4-compliant variant): add real `items` blocks for `d/*/npc/obj/*.c`
files that the (frozen) converter mis-typed as `characters` blocks.

背景
----
转换器 `determine_object_type` 先判 `npc_subdir?` 再判 `is_item_inherit?`
（lpc_converter.ex 附近），于是 `d/beijing/npc/obj/blade.c`（`inherit BLADE`）
被写成 `characters "blade" { name/aliases/description }` —— name 对、武器 meta
（damage/skill_type/value/weight/unit/material）与 armor_prop 全丢。

D10 的「改名 characters→items」方案**改已有行，与 P4「只增不改」冲突**，
属待决策（进度文档 §14 R7）。本脚本采用**计划 §D20 的合规路径**：
**只新增 `items` 块**（新行），**不动**既有 `characters` 块 —— loader 的
`parse_zone` 把 characters/items 放在两个独立命名空间（loader.ex L304-318），
同名跨段无冲突。

范围
----
只覆盖 yao（NPC private action `do_yao`）实际发放、且当前缺失为 items 的对象：
- beijing: blade/sword/dagger/hammer/staff/throwing/whip/body/helmet/feet/waist
  （`d/beijing/npc/qianzhenglun.c` do_yao 的 arg 域）
- wudu: baozi2 （`d/wudu/npc/tian.c` do_yao 发放 2 个）

安全（同 backfill_item_props.py / B8/B9/B10 协议）
--------------------------------------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：内存算完 + 过门禁（insertion-only + validate_ucl 完整 issue 集合比对、
  行号归一化），**全过**才备份、才写盘
* 备份在写盘**之前**（tmp/backup-<stamp>/）
* 幂等：已存在同名 `items "<key>"` 块则跳过（二次 dry-run 应为 0）
* 只增不改：新块**追加**到 zone 文件末尾，不触碰任何既有行
"""
import argparse
import datetime
import difflib
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

CORPUS = r"C:\files\git\mud"
WORLD = os.path.join(ROOT, "data", "world")
TMP = os.path.join(ROOT, "tmp")

# (zone, key, lpc path relative to CORPUS, kind)
TARGETS = [
    ("beijing", "blade", "d/beijing/npc/obj/blade.c", "weapon"),
    ("beijing", "sword", "d/beijing/npc/obj/sword.c", "weapon"),
    ("beijing", "dagger", "d/beijing/npc/obj/dagger.c", "weapon"),
    ("beijing", "hammer", "d/beijing/npc/obj/hammer.c", "weapon"),
    ("beijing", "staff", "d/beijing/npc/obj/staff.c", "weapon"),
    ("beijing", "throwing", "d/beijing/npc/obj/throwing.c", "weapon"),
    ("beijing", "whip", "d/beijing/npc/obj/whip.c", "weapon"),
    ("beijing", "body", "d/beijing/npc/obj/body.c", "armor"),
    ("beijing", "helmet", "d/beijing/npc/obj/helmet.c", "armor"),
    ("beijing", "feet", "d/beijing/npc/obj/feet.c", "armor"),
    ("beijing", "waist", "d/beijing/npc/obj/waist.c", "armor"),
    ("wudu", "baozi2", "d/wudu/npc/obj/baozi2.c", "food"),
]

VERBS = {
    "weapon": ["get", "drop", "wield", "unwield"],
    "armor": ["get", "drop", "wear", "remove"],
    "food": ["get", "drop", "eat"],
}

SKILL_TYPE = {
    "SWORD": "sword", "BLADE": "blade", "DAO": "blade", "STAFF": "staff",
    "GUN": "staff", "WHIP": "whip", "BIAN": "whip", "DAGGER": "dagger",
    "THROWING": "throwing", "HAMMER": "hammer",
}
ARMOR_INHERITS = ("ARMOR", "HEAD", "BOOTS", "CLOTH", "WAIST", "HANDS", "NECK", "CLOAK", "FINGER")

OPEN_ITEMS = None  # set in main


def norm_zone_file(zone):
    return os.path.join(WORLD, zone + ".ucl")


def get(txt, pat, grp=1, default=None):
    m = re.search(pat, txt)
    return m.group(grp) if m else default


def ucl_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_lpc(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        txt = fh.read()

    name = get(txt, r'set_name\(\s*"([^"]+)"')
    alias_block = get(txt, r'set_name\(\s*"[^"]+"\s*,\s*\(\{([^}]*)\}')
    aliases = re.findall(r'"([^"]*)"', alias_block) if alias_block else []
    inherit = get(txt, r'inherit\s+([A-Za-z_0-9]+)')
    unit = get(txt, r'set\(\s*"unit"\s*,\s*"([^"]*)"')
    value = get(txt, r'set\(\s*"value"\s*,\s*(-?\d+)')
    material = get(txt, r'set\(\s*"material"\s*,\s*"([^"]*)"')
    weight = get(txt, r'set_weight\(\s*(\d+)\s*\)')
    longd = get(txt, r'set\(\s*"long"\s*,\s*"((?:[^"\\]|\\.)*)"')
    if longd is not None:
        longd = longd.replace("\\n", "").rstrip()

    init = re.findall(r'init_([a-z_]+)\(\s*(\d+)', txt)
    damage = int(init[0][1]) if init else None

    armor = {}
    for k, v in re.findall(r'set\(\s*"armor_prop/([a-z_]+)"\s*,\s*(-?\d+)\s*\)', txt):
        armor[k] = int(v)

    food_supply = get(txt, r'set\(\s*"food_supply"\s*,\s*(\d+)')

    return dict(name=name, aliases=aliases, inherit=inherit, unit=unit,
                value=int(value) if value is not None else None,
                material=material,
                weight=int(weight) if weight is not None else None,
                long=longd, damage=damage, armor=armor,
                food=int(food_supply) if food_supply is not None else None)


def skill_type(inherit):
    for macro, st in SKILL_TYPE.items():
        if macro in (inherit or ""):
            return st
    return None


def build_block(zone, key, rel_lpc, kind, d):
    meta = []  # (key, rendered_value_line)
    if kind == "weapon":
        if d["damage"] is not None:
            meta.append(("damage", "damage = %d" % d["damage"]))
        st = skill_type(d["inherit"])
        if st:
            meta.append(("skill_type", "skill_type = %s" % ucl_str(st)))
    if kind == "armor":
        if d["armor"].get("armor") is not None:
            meta.append(("armor", "armor = %d" % d["armor"]["armor"]))
    if d["value"] is not None:
        meta.append(("value", "value = %d" % d["value"]))
    if d["weight"] is not None:
        meta.append(("weight", "weight = %d" % d["weight"]))
    if d["unit"]:
        meta.append(("unit", "unit = %s" % ucl_str(d["unit"])))
    if d["material"]:
        meta.append(("material", "material = %s" % ucl_str(d["material"])))
    if kind == "food" and d["food"] is not None:
        meta.append(("food", "food = %d" % d["food"]))

    arm_prop = d["armor"] if kind == "armor" else {}
    # body.c 归一化别名（Item.Meta.normalize_armor_type: body→cloth）—— 这里
    # 保持与源一致，不臆造 armor_type（源无 set("armor_type")）。

    out = []
    out.append("# Source: %s" % (CORPUS.replace("\\", "/") + "/" + rel_lpc))
    out.append("# Zone: %s" % zone)
    out.append("")
    out.append('    items "%s" {' % key)
    if d["name"]:
        out.append("      name = %s" % ucl_str(d["name"]))
    if d["aliases"]:
        out.append("      aliases = [%s]" % ", ".join(ucl_str(a) for a in d["aliases"]))
    if d["long"] is not None:
        out.append("      description = %s" % ucl_str(d["long"]))
    out.append("      verbs = [")
    vlist = VERBS[kind]
    for i, v in enumerate(vlist):
        comma = "," if i < len(vlist) - 1 else ""
        out.append('        %s%s' % (ucl_str(v), comma))
    out.append("      ]")
    if meta or arm_prop:
        out.append("      meta = {")
        for _k, line in meta:
            out.append("        " + line)
        if arm_prop:
            out.append("        armor_prop = {")
            for k in ("armor", "dodge", "defense", "attack", "unarmed_damage"):
                if k in arm_prop:
                    out.append("          %s = %d" % (k, arm_prop[k]))
            out.append("        }")
        out.append("      }")
    out.append("    }")
    return out


def _norm_issues(issues):
    return {(n, re.sub(r"line \d+", "line N", m or "")) for n, m in issues}


def _is_insertion_only(orig_text, new_text):
    a = orig_text.split("\n")
    b = new_text.split("\n")
    if len(b) <= len(a):
        return False, "line count did not grow"
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, _i2, _j1, _j2 in sm.get_opcodes():
        if tag in ("delete", "replace"):
            return False, "%s at orig line %d" % (tag, i1 + 1)
    return True, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    by_zone = {}
    for zone, key, rel, kind in TARGETS:
        by_zone.setdefault(zone, []).append((key, rel, kind))

    planned = []
    stats = {"zones": 0, "blocks_added": 0, "blocks_skipped_exists": 0,
             "inserted_lines": 0}
    for zone in sorted(by_zone):
        path = norm_zone_file(zone)
        with open(path, encoding="utf-8", newline="") as fh:
            orig = fh.read()
        lines = orig.split("\n")

        additions = []
        for key, rel, kind in by_zone[zone]:
            if re.search(r'^\s*items\s+"%s"\s*\{' % re.escape(key), orig, re.M):
                stats["blocks_skipped_exists"] += 1
                continue
            d = parse_lpc(os.path.join(CORPUS, rel.replace("/", os.sep)))
            additions += build_block(zone, key, rel, kind, d)
            stats["blocks_added"] += 1

        if not additions:
            continue

        new_lines = list(lines)
        if new_lines and new_lines[-1] != "":
            new_lines.append("")
        new_lines += additions
        new = "\n".join(new_lines)

        if _vucl is not None:
            regressions = sorted(
                _norm_issues(_vucl._run_checks(new.encode("utf-8")))
                - _norm_issues(_vucl._run_checks(orig.encode("utf-8")))
            )
            if regressions:
                print("  !! %s self-gate blocked: %s" % (zone, regressions[:3]))
                return 2

        ok, why = _is_insertion_only(orig, new)
        if not ok:
            print("  !! %s is not insertion-only (%s) -- aborting" % (zone, why))
            return 2

        delta = len(new.split("\n")) - len(orig.split("\n"))
        stats["zones"] += 1
        stats["inserted_lines"] += delta
        planned.append((path, new))
        print("  %-14s +%-4d lines" % (zone, delta))

    print(json.dumps(stats, ensure_ascii=False))

    if not args.apply:
        print("dry-run only; re-run with --apply to write")
        return 0
    if not planned:
        print("nothing to write")
        return 0

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = os.path.join(TMP, "backup-%s" % stamp)
    os.makedirs(backup, exist_ok=True)
    for path, _ in planned:
        shutil.copy2(path, os.path.join(backup, os.path.basename(path)))
    print("backed up %d files to %s" % (len(planned), backup))

    for path, new in planned:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("wrote %d files (+%d lines)" % (len(planned), stats["inserted_lines"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
