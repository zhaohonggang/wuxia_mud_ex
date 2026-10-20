#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4 勘查：扫描 LPC 源语料里的 set("item_desc", ([ ... ]))，区分「静态字符串值」
与「动态值（闭包 (: look_xxx :) / 表达式）」，回答 P5-4 look 的真实规模。

背景
----
- 转换器 lpc_converter.generate_room_item_desc 只保留**字符串字面量**值；
  闭包/表达式值的 pair 会被 item_desc_text(_) -> "" 丢弃，整条不写进 UCL。
- 运行时 loader.parse_item_desc 只认 map 值 -> to_string，room.item_desc/2
  只回非空字符串。因此动态 item_desc 目前**完全缺失**（look wall 回「这里没有这个东西」）。
- 本脚本只读，摸清要补多少、哪些是纯闭包转发（(: look_wall :)）、哪些是内联表达式。

输出
----
- tmp/p54_look_survey.json：结构化结果（逐房间明细 + 闭包函数体，供后续实现消费）
- stdout：人类可读摘要

约定：纯只读、可重跑、结果落 tmp/。
"""

import json
import os
import re
import sys
from collections import Counter, defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
MUD_ROOT = "C:/files/git/mud"
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "p54_look_survey.json")

# set("item_desc", ([ ... ])) —— 捕获 mapping 主体（非贪婪到 ])）
ITEM_DESC_RE = re.compile(
    r"""set\s*\(\s*["']item_desc["']\s*,\s*\(\[\s*(.*?)\s*\]\s*\)\s*\)""",
    re.DOTALL,
)
# set("item_desc", <非 mapping>）——动态整表
ITEM_DESC_DYN_RE = re.compile(
    r"""set\s*\(\s*["']item_desc["']\s*,\s*([^(\[]|\([^\[\s])""",
)
CLOSURE_RE = re.compile(r"^\(:\s*([A-Za-z_]\w*)\s*:\s*\)$")
STRING_RE = re.compile(r'^"')
MACRO_RE = re.compile(r"^[A-Z_]+")
TEXT_MACRO_RE = re.compile(r"^@")


def dynamic_subtype(raw):
    """非闭包表达式的细分：颜色宏拼接 / @TEXT 多行宏 / 其它表达式。"""
    if TEXT_MACRO_RE.match(raw):
        return "text_macro"
    if MACRO_RE.match(raw):
        return "macro_concat"
    if STRING_RE.match(raw):
        return "string_concat"
    return "expr"


def classify_kind(path):
    norm = path.replace("\\", "/").lower()
    for kind in ("room", "npc", "obj"):
        if ("/%s/" % kind) in norm:
            return kind
    return "other"


def split_top_level(text):
    """按顶层逗号切分 LPC 列表项，跟踪 () [] {} 深度。"""
    items = []
    depth = 0
    cur = []
    in_str = False
    esc = False
    for ch in text:
        if in_str:
            cur.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
            cur.append(ch)
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            items.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    last = "".join(cur).strip()
    if last:
        items.append(last)
    return items


PAIR_RE = re.compile(r'^"([^"]*)"\s*:\s*(.*)$', re.DOTALL)


def parse_mapping(body):
    """返回 [(keyword, raw_value)]。"""
    pairs = []
    for item in split_top_level(body):
        m = PAIR_RE.match(item)
        if not m:
            continue
        pairs.append((m.group(1), m.group(2).strip()))
    return pairs


FUNC_RE = re.compile(
    r"(?m)^[ \t]*(?:[\w\*]+[ \t]+)+(?P<name>[A-Za-z_]\w*)[ \t]*\((?P<args>[^)]*)\)[ \t]*\n?[ \t]*\{"
)

STRIP_STR_RE = re.compile(r'"(\\.|[^"\\])*"')
STRIP_COMMENT_RE = re.compile(r"/\*.*?\*/|//[^\n]*", re.DOTALL)
# 条件语义标记：出现任一即判为「有状态/条件分支」，无法静态抽取
COND_RE = re.compile(
    r"\b(if|else|for|while|switch|case|query|query_temp|set|set_temp|random|"
    r"objectp|this_player|find_object|load_object|call_other)\b|->"
)


def classify_closure(body):
    """static = 纯 return <字符串>；conditional = 含分支/查询/外部调用。

    注意 helper 调用（`return scoreboard_str();`）也判 conditional：函数体本身
    不含字面量，静态抽取拿不到文本。
    """
    if not body:
        return "unknown"
    code = STRIP_COMMENT_RE.sub(" ", body)
    code = STRIP_STR_RE.sub('""', code)
    brace = code.find("{")
    inner = code[brace + 1:] if brace >= 0 else code
    if COND_RE.search(inner):
        return "conditional"
    if re.search(r"\b[A-Za-z_]\w*\s*\(", inner):
        return "conditional"
    return "static"


def extract_functions(text):
    """提取文件里所有函数体（粗略花括号配对）。返回 {name: source}。"""
    funcs = {}
    for m in FUNC_RE.finditer(text):
        name = m.group("name")
        brace = text.find("{", m.end() - 1)
        if brace < 0:
            continue
        depth = 0
        i = brace
        while i < len(text):
            c = text[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        funcs.setdefault(name, text[m.start():i + 1])
    return funcs


def main():
    if not os.path.isdir(MUD_ROOT):
        print("MUD_ROOT 不存在: %s" % MUD_ROOT, file=sys.stderr)
        sys.exit(1)

    total_pairs = 0
    literal_pairs = 0
    closure_pairs = 0
    dynamic_pairs = 0
    dynamic_by_kind = Counter()
    dyn_mapping_files = []
    rooms = {}
    closure_counter = Counter()
    closure_files = defaultdict(set)
    keyword_counter = Counter()
    zone_rooms = defaultdict(list)
    closure_bodies = {}

    for dirpath, _d, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if not fn.endswith(".c"):
                continue
            full = os.path.join(dirpath, fn).replace("\\", "/")
            try:
                with open(full, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue

            found_any = False
            for m in ITEM_DESC_RE.finditer(text):
                found_any = True
                body = m.group(1)
                pairs = parse_mapping(body)
                entry = {"file": full, "kind": classify_kind(full), "pairs": []}
                for kw, raw in pairs:
                    total_pairs += 1
                    keyword_counter[kw] += 1
                    cm = CLOSURE_RE.match(raw)
                    if cm:
                        closure_pairs += 1
                        fname = cm.group(1)
                        closure_counter[fname] += 1
                        closure_files[fname].add(full)
                        entry["pairs"].append({"keyword": kw, "type": "closure", "fn": fname})
                    elif STRING_RE.match(raw):
                        literal_pairs += 1
                        entry["pairs"].append({"keyword": kw, "type": "literal"})
                    else:
                        dynamic_pairs += 1
                        sub = dynamic_subtype(raw)
                        dynamic_by_kind[sub] += 1
                        entry["pairs"].append(
                            {"keyword": kw, "type": "dynamic", "subtype": sub, "raw": raw[:120]}
                        )
                if entry["pairs"]:
                    rooms[full] = entry
                    zone = full.split("/d/")[-1].split("/")[0] if "/d/" in full else "?"
                    zone_rooms[zone].append(full)

            # 动态整表（非 mapping）
            if not found_any and ITEM_DESC_DYN_RE.search(text):
                dyn_mapping_files.append(full)

    # 第二轮：收集所有被引用闭包函数体（跨文件，含继承的 look_*）
    wanted = set(closure_counter)
    closed = set()
    for dirpath, _d, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if not fn.endswith(".c"):
                continue
            full = os.path.join(dirpath, fn).replace("\\", "/")
            try:
                with open(full, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue
            funcs = extract_functions(text)
            for name in list(wanted - closed):
                if name in funcs:
                    body = funcs[name]
                    closure_bodies[name] = {
                        "file": full,
                        "body": body[:4000],
                        "class": classify_closure(body),
                    }
                    closed.add(name)

    # 按闭包分类聚合（函数级 + 键值对级）
    fn_class = {n: b["class"] for n, b in closure_bodies.items()}
    static_fns = sorted(n for n, c in fn_class.items() if c == "static")
    cond_fns = sorted(n for n, c in fn_class.items() if c == "conditional")
    static_pair_count = 0
    cond_pair_count = 0
    for r in rooms.values():
        for p in r["pairs"]:
            if p["type"] == "closure":
                if fn_class.get(p["fn"]) == "static":
                    static_pair_count += 1
                else:
                    cond_pair_count += 1

    # 每房间构成：全动态（UCL 无 block）/ 混合（UCL 仅有静态对）
    all_dynamic_rooms = 0
    mixed_rooms = 0
    for r in rooms.values():
        types = {p["type"] for p in r["pairs"]}
        if "closure" in types:
            if types == {"closure"}:
                all_dynamic_rooms += 1
            else:
                mixed_rooms += 1

    result = {
        "rooms_with_item_desc": len(rooms),
        "total_pairs": total_pairs,
        "literal_pairs": literal_pairs,
        "closure_pairs": closure_pairs,
        "dynamic_pairs": dynamic_pairs,
        "dynamic_by_kind": dict(dynamic_by_kind),
        "distinct_closures": len(closure_counter),
        "static_closures": static_fns,
        "conditional_closures": cond_fns,
        "static_closure_pairs": static_pair_count,
        "conditional_closure_pairs": cond_pair_count,
        "rooms_all_dynamic": all_dynamic_rooms,
        "rooms_mixed": mixed_rooms,
        "dynamic_mapping_files": len(dyn_mapping_files),
        "top_closures": closure_counter.most_common(50),
        "top_keywords": keyword_counter.most_common(40),
        "zones": {z: len(v) for z, v in sorted(zone_rooms.items(), key=lambda x: -len(x[1]))},
        "rooms": rooms,
        "closure_bodies": closure_bodies,
        "unresolved_closures": sorted(wanted - closed),
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)

    print("=== P5-4 动态 item_desc 勘查 ===")
    print("含 item_desc 的房间文件: %d" % len(rooms))
    print("item_desc 键值对: %d（静态字符串 %d / 闭包 %d / 动态表达式 %d）"
          % (total_pairs, literal_pairs, closure_pairs, dynamic_pairs))
    print("非闭包动态值细分: %s" % dict(dynamic_by_kind))
    print("动态整表（非 mapping 字面量）文件: %d" % len(dyn_mapping_files))
    print("去重闭包函数: %d（未定位函数体: %d）"
          % (len(closure_counter), len(result["unresolved_closures"])))
    print("闭包分类（函数级）: 纯静态 return %d / 条件分支 %d"
          % (len(static_fns), len(cond_fns)))
    print("闭包分类（键值对级）: 纯静态 %d / 条件 %d"
          % (static_pair_count, cond_pair_count))
    print("闭包房间构成: 全动态(无 UCL block) %d / 混合 %d"
          % (all_dynamic_rooms, mixed_rooms))
    print("纯静态闭包函数: %s" % ", ".join(static_fns))
    print("")
    print("Top 20 闭包函数:")
    for name, c in closure_counter.most_common(20):
        print("  %-20s %4d  (%d 文件)" % (name, c, len(closure_files[name])))
    print("")
    print("Top 15 关键词:")
    for kw, c in keyword_counter.most_common(15):
        print("  %-16s %4d" % (kw, c))
    print("")
    print("按 zone（房间数）:")
    for z, n in list(result["zones"].items())[:20]:
        print("  %-16s %4d" % (z, n))
    print("")
    print("完整结果 → %s" % OUT_JSON)


if __name__ == "__main__":
    main()
