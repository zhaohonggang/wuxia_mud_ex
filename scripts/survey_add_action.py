#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-1 勘查：扫描 LPC 源语料里的 add_action/2 调用，按对象类型（room/npc/item）
分诊，并标注每个 handler 是否已有 Elixir 命令实现（Tier 0 免做）。

背景
----
续做计划 §3 P5 第 1 项「逐对象 add_action 通道」是覆盖面积最大的子系统
（646 行 / 215 名，Q1 已实测可表达）。但勘查发现：
- NPC 的 add_actions 已被（冻结的）转换器写进 UCL（52 个 .ucl 文件含
  `add_actions = [...]`），loader.ex `parse_enter_init` 也已读入
  `NonPlayerMeta.init.add_actions` —— NPC 侧数据+载入**已存在**。
- 缺的是：房间级 / 物品级 add_action 的 UCL 入口，以及真正按对象级优先
  分发 verb 的路由（room.ex 只有房间级 add_action/2 雏形）。

本脚本只做**只读勘查**，回答三个问题：
1. add_action 调用按对象类型（room / npc / item / other）分布如何？
2. 每个 verb / handler 出现频次、涉及多少文件？
3. 哪些 handler 已有对应 Elixir 命令模块（Tier 0，免做）？
   哪些必须新建 Elixir 实现？

输出
----
- tmp/survey_add_action.json：结构化结果（供后续回填脚本消费）
- stdout：人类可读摘要

约定：复用项目既有脚本风格（纯只读、可重跑、结果落 tmp/）。
"""

import json
import os
import re
import sys
from collections import Counter, defaultdict

# ---- 路径 ----
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)                       # wuxia_mud_ex
MUD_ROOT = os.path.join("C:/files/git/mud")              # LPC 源语料
COMMANDS_DIR = os.path.join(ROOT, "lib", "kantele", "character", "commands")
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "survey_add_action.json")

# ---- 正则 ----
# add_action("verb", "handler"[, flag]) —— 取前两个字符串参数
ADD_ACTION_RE = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']""",
    re.VERBOSE,
)

# 对象类型判定：d/<zone>/{room,npc,obj}/... 是主世界数据约定
KIND_BY_SEGMENT = {
    "room": "room",
    "npc": "npc",
    "obj": "item",
    "cmds": "other",
}


def classify_kind(path):
    """按 d/ 下的 zone/<kind>/ 子目录判定对象类型。"""
    norm = path.replace("\\", "/")
    segs = norm.split("/")
    # 找到 d/ 之后的 kind 段
    for i, seg in enumerate(segs):
        if seg in KIND_BY_SEGMENT and i > 0 and segs[i - 1] in ("d", "clone", "b"):
            return KIND_BY_SEGMENT[seg]
    # 退化判定：路径含这些段名
    for seg in ("room", "npc", "obj"):
        if ("/%s/" % seg) in norm or norm.endswith("/%s.c" % seg):
            return KIND_BY_SEGMENT[seg]
    return "other"


def load_existing_commands():
    """列出 lib 里已有的 *command.ex 模块名（去 _command 后缀 = stem）。"""
    stems = set()
    if not os.path.isdir(COMMANDS_DIR):
        return stems
    for fn in os.listdir(COMMANDS_DIR):
        if fn.endswith("_command.ex"):
            stems.add(fn[: -len("_command.ex")])
    return stems


def verb_to_stems(verb, handler):
    """候选命令 stem：去 do_ 前缀、handler 本身。"""
    stems = set()
    v = verb
    if v.startswith("do_"):
        v = v[len("do_"):]
    stems.add(v)
    stems.add(handler)
    # 也试 verb 原样（有的 verb 本就不是 do_ 前缀）
    stems.add(verb)
    return {s for s in stems if s}


def main():
    if not os.path.isdir(MUD_ROOT):
        print("MUD_ROOT 不存在: %s" % MUD_ROOT, file=sys.stderr)
        sys.exit(1)

    existing = load_existing_commands()

    # 统计容器
    total = 0
    by_kind = Counter()
    files_by_kind = defaultdict(set)
    verb_counter = Counter()          # verb -> 出现次数
    verb_files = defaultdict(set)     # verb -> 涉及文件
    handler_counter = Counter()       # handler -> 出现次数
    handler_files = defaultdict(set)  # handler -> 涉及文件
    handler_verbs = defaultdict(set)  # handler -> 关联 verb
    handler_kind = defaultdict(Counter)  # handler -> {kind: count}
    needs_impl = Counter()            # 需新建实现的 handler -> count
    tier0 = Counter()                 # 已有命令的 handler -> count
    kind_needs_impl = Counter()       # {kind} -> 需新建 count

    matched_files = 0
    for dirpath, _dirnames, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if not fn.endswith(".c"):
                continue
            full = os.path.join(dirpath, fn)
            try:
                with open(full, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue
            matches = ADD_ACTION_RE.findall(text)
            if not matches:
                continue
            matched_files += 1
            kind = classify_kind(full)
            by_kind[kind] += len(matches)
            files_by_kind[kind].add(full)
            for verb, handler in matches:
                total += 1
                verb_counter[verb] += 1
                verb_files[verb].add(full)
                handler_counter[handler] += 1
                handler_files[handler].add(full)
                handler_verbs[handler].add(verb)
                handler_kind[handler][kind] += 1

                stems = verb_to_stems(verb, handler)
                hit = stems & existing
                if hit:
                    tier0[handler] += 1
                else:
                    needs_impl[handler] += 1
                    kind_needs_impl[kind] += 1

    # ---- 汇总 ----
    result = {
        "total_calls": total,
        "matched_files": matched_files,
        "by_kind": dict(by_kind),
        "files_by_kind": {k: len(v) for k, v in files_by_kind.items()},
        "distinct_verbs": len(verb_counter),
        "distinct_handlers": len(handler_counter),
        "tier0_handler_calls": sum(tier0.values()),
        "needs_impl_handler_calls": sum(needs_impl.values()),
        "kind_needs_impl": dict(kind_needs_impl),
        "top_verbs": verb_counter.most_common(40),
        "top_handlers": handler_counter.most_common(60),
        "tier0_handlers": sorted(tier0.items(), key=lambda x: -x[1]),
        "needs_impl_handlers": sorted(needs_impl.items(), key=lambda x: -x[1]),
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)

    # ---- 打印摘要 ----
    print("=== P5-1 add_action 勘查摘要 ===")
    print("add_action 调用总数: %d（涉及 %d 个 .c 文件）" % (total, matched_files))
    print("按对象类型（调用数 / 文件数）:")
    for kind in ("room", "npc", "item", "other"):
        print("  %-6s %6d 调用 / %4d 文件" % (kind, by_kind.get(kind, 0), len(files_by_kind.get(kind, set()))))
    print("去重 verb 数: %d | 去重 handler 数: %d" % (len(verb_counter), len(handler_counter)))
    print("已有 Elixir 命令(Tier0) 的调用: %d | 需新建实现 的调用: %d"
          % (sum(tier0.values()), sum(needs_impl.values())))
    print("需新建实现 按对象类型: %s" % dict(kind_needs_impl))
    print("")
    print("Top 20 verb:")
    for verb, c in verb_counter.most_common(20):
        print("  %-16s %5d  (%d 文件)" % (verb, c, len(verb_files[verb])))
    print("")
    print("Top 25 handler（含 Tier0 标记）:")
    tier0_set = set(h for h, _ in result["tier0_handlers"])
    for handler, c in handler_counter.most_common(25):
        tag = "Tier0" if handler in tier0_set else "NEW"
        print("  [%-5s] %-16s %5d  (%d 文件) verbs=%s"
              % (tag, handler, c, len(handler_files[handler]),
                 ",".join(sorted(handler_verbs[handler])[:4])))
    print("")
    print("需新建实现的 handler 总数: %d" % len(needs_impl))
    print("完整结果 → %s" % OUT_JSON)


if __name__ == "__main__":
    main()
