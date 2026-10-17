#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-1a2 勘查（只读，不写 data/world）：为「房间级 actions 回填」铺路。

背景
----
P5-1a（commit 9d185a57）已在 Room 结构体加 `actions` 字段 + loader 读入
UCL `actions = { verb = "handler" }`，但**全库尚无任何房间写过 `actions`**。
本脚本回答：哪些房间需要从 .c 回源补 `actions`，以及 verb→handler 是什么。

关键约束（续做 12 / D24）
------------------------
冻结的转换器（lpc_converter.ex L1286-1289）只存了 handler、丢了玩家输入的 verb
（`Enum.map(fn [_, _func, verb] -> verb end)` 里 verb 是第二捕获组 = handler 名）。
因此 verb→handler 映射**必须从 .c 回源重抽**，不能信 UCL。

难点：.c → UCL room id 映射**非统一**
（`d/dali/chahua1.c` vs `d/room/caihong/houyuan.c` 路径形态不同）。
故本脚本**不从路径推断 id**，而从 UCL 房间块本身反查：
每个 `rooms "key" { }` 块的真实 room id = "#{zone}:#{key}"（zone = .ucl 文件名去后缀），
块内 `# LPC: <path>` 注释给出其源 .c。这样无论路径怎么变，映射都权威正确。

复用 audit_block_attribution.py 的 skeleton_delta（括号配对，忽略注释/字符串）。

产出
----
- tmp/p5a2_room_actions_survey.json
- stdout 人类可读摘要

绝不修改任何 .ucl / .c。
"""

import json
import os
import re
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)                       # wuxia_mud_ex
WORLD = os.path.join(ROOT, "data", "world")
MUD_ROOT = "C:/files/git/mud"                            # LPC 源语料
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "p5a2_room_actions_survey.json")

ROOM_OPEN = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{\s*$')
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPCC = re.compile(r"^#\s*LPC:\s*(\S+)")
# add_action("verb", "handler"[, flag]) —— 取前两个字符串参数（兼容单/双引号）
ADD_ACTION_RE = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']""",
)
# 统计「动态 verb」：add_action( 但第一个参数不是字符串字面量
ADD_ACTION_DYN = re.compile(r"add_action\s*\(\s*(?![\"'])")


def skeleton_delta(line):
    """Count { } while ignoring comments and the contents of strings."""
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if not in_str and ch == "#":
            break
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
            out.append(" ")
        else:
            if ch == '"':
                in_str = True
                out.append(" ")
            else:
                out.append(ch)
        i += 1
    s = "".join(out)
    return s.count("{") - s.count("}")


def norm(p):
    return p.replace("\\", "/").lower()


def build_room_id_map():
    """
    遍历 data/world/*.ucl，对每个 `rooms "key" { }` 块：
    返回 { norm(lpc_path): [ (zone, key, room_id), ... ] }
    lpc_path 取自块内 `# LPC:`（权威），缺则退回最近的 `# Generated from`。
    """
    mapping = defaultdict(list)
    missing_source = []
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        zone = fn[:-4]
        lines = open(os.path.join(WORLD, fn), encoding="utf-8").read().split("\n")
        depth = 0
        pending = None          # (key, start_line)
        last_gen = None         # 最近的 # Generated from（兜底）
        for i, line in enumerate(lines):
            s = line.strip()
            m = GEN.match(s)
            if m and depth == 0:
                last_gen = norm(m.group(1))
            if depth == 0:
                om = ROOM_OPEN.match(line)
                if om:
                    pending = (om.group(1), i)
            nxt = depth + skeleton_delta(line)
            if pending is not None and depth != 0 and nxt == 0:
                key, start = pending
                src = None
                for j in range(start + 1, i):
                    lm = LPCC.match(lines[j].strip())
                    if lm:
                        src = norm(lm.group(1))
                        break
                if src is None:
                    src = last_gen
                room_id = "%s:%s" % (zone, key)
                if src:
                    mapping[src].append((zone, key, room_id))
                else:
                    missing_source.append(room_id)
                pending = None
            depth = nxt
    return mapping, missing_source


def extract_add_actions(c_path):
    """读取 .c，返回 (literal: {verb: handler}, dyn_count)。

    关键方向（已对齐冻结转换器 lpc_converter.ex L1286-1289 + NPC UCL add_actions）：
    LPC `add_action("do_move", "move")` 标准语义 = (handler函数名, 玩家输入verb)。
    - group1 = handler 函数名（如 "do_move" / "do_list"）
    - group2 = 玩家输入的 verb（如 "move" / "list" / "buy"）
    冻结转换器 `Enum.map(fn [_, _func, verb] -> verb end)` 取的是 group2（verb），
    故 NPC UCL `add_actions = ["list","buy"]` 存的是 verb、丢了 handler（D24 描述把
    两组的角色写反了，结论「丢了 handler」正确）。
    => UCL 应是 `actions = { "move" = "do_move" }`，即 {verb: handler} = {group2: group1}。
    """
    literal = {}
    dyn = 0
    try:
        text = open(c_path, encoding="utf-8", errors="replace").read()
    except OSError:
        return literal, dyn, "missing"
    for handler, verb in ADD_ACTION_RE.findall(text):
        # 同一 verb 多次出现时保留首次（最外层定义，更稳）
        literal.setdefault(verb, handler)
    dyn = len(ADD_ACTION_DYN.findall(text))
    return literal, dyn, "ok"


def main():
    mapping, missing_source = build_room_id_map()
    print("UCL 房间块 → 源 .c 映射条目数: %d" % len(mapping))
    if missing_source:
        print("  无源注释的房间块: %d（样例 %s）" % (len(missing_source), missing_source[:5]))

    candidates = {}          # room_id -> {verb: handler}
    coverage = defaultdict(int)
    unresolved_rooms_with_action = []   # 有 add_action 但源 .c 未在 UCL 出现的（理论上不应发生）
    source_missing_on_disk = []

    # 反向：从 .c 找 room_id
    # 先收集所有源 .c 路径
    for lpc_path, rooms in mapping.items():
        full = os.path.join(MUD_ROOT, lpc_path)
        if not os.path.exists(full):
            source_missing_on_disk.append(lpc_path)
            continue
        literal, dyn, status = extract_add_actions(full)
        if not literal and dyn == 0:
            coverage["room_no_add_action"] += len(rooms)
            continue
        if literal:
            coverage["room_with_literal_action"] += len(rooms)
            for (_zone, _key, room_id) in rooms:
                # 一个 .c 可能对应多个 room_id？通常 1:1；若多，逐个登记
                candidates.setdefault(room_id, {})
                candidates[room_id].update(literal)
        if dyn:
            coverage["room_with_dynamic_action"] += len(rooms)

    result = {
        "room_id_candidates": candidates,
        "coverage": dict(coverage),
        "unresolved_source_on_disk": source_missing_on_disk,
        "rooms_without_source_comment": missing_source,
        "total_candidate_rooms": len(candidates),
        "total_candidate_verbs": sum(len(v) for v in candidates.values()),
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)

    print("\n=== P5-1a2 房间 actions 回填候选勘查 ===")
    print("候选房间数（含 add_action 字面量）: %d" % len(candidates))
    print("候选 verb 总数: %d" % sum(len(v) for v in candidates.values()))
    print("覆盖统计: %s" % dict(coverage))
    print("源 .c 在磁盘缺失: %d（样例 %s）" % (len(source_missing_on_disk), source_missing_on_disk[:5]))
    # 样例
    sample = list(candidates.items())[:8]
    print("\n样例（room_id -> {verb: handler}）:")
    for rid, m in sample:
        print("   %s -> %s" % (rid, m))
    print("\n输出: %s" % OUT_JSON)


if __name__ == "__main__":
    main()
