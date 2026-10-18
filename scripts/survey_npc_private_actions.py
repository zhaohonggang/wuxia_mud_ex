#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P5-1 勘查（NPC 通道）：找出「NPC 私有动作」—— NPC 注册、但全局命令表里没有的 verb。

背景（R9 结论）
---------------
UCL 里 NPC 的 `init.add_actions` **不是逐 NPC 数据，而是基类继承动词**：
2024 个 NPC / 3617 条，但只有 77 个不同 verb；`list`(1096)+`buy`(1094) 占 62%，
而这两个已由 shop 通道（`NpcShopEvent`）覆盖。逐 NPC 回源只能匹配 13%，
所以**不能**按 UCL 的 add_actions 逐 NPC 回填。

本脚本改从 LPC 语料直接入手，回答四个问题：

1. NPC 对象（`*/npc/*.c`）一共注册了哪些 verb？
2. 其中哪些 **不在** 全局命令表里（`lib/kantele/character/commands.ex` 的
   `parse("...")`）—— 这些才是「NPC 私有动作」，是真正需要新实现的部分。
3. 私有 handler 各自做什么？按「纯输出 / 改状态 / 进战斗」粗分类。
4. **handler 定义在哪个文件**？很多 NPC 只 `add_action` 不定义函数，真正的
   实现来自继承的基类（银行 / 钱庄 / 门派管事共用一套）。这类「基类动作」
   只要实现一次，不必逐 NPC 移植 —— 这是本脚本最有价值的输出。

只读。输出 `scripts/tmp/npc_private_actions.json` + 终端摘要。

用法
----
    python scripts/survey_npc_private_actions.py
    python scripts/survey_npc_private_actions.py --ignore-global cun,qu,deposit,withdraw

`--ignore-global` 把指定 verb 当成「还没接线」，用来复现**接线前**的基线。
必要性：本脚本读的是**当前**的 `commands.ex`，所以每补一个动词别名，
同一个 verb 就从「私有」挪到「已覆盖」，总数会变 —— 想横向比较
「还剩多少活」必须能冻住基线。钱庄那 9 个（`cun`/`qu`/`deposit`/`withdraw`/
`convert`/`duihuan`/`transfer`/`zhuan`/`chazhang`）已在 `6944ffaf` 接好，
用 `--ignore-global` 排除它们即可得到接线前的数字。
"""

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
MUD_ROOT = "C:/files/git/mud"
COMMANDS_EX = os.path.join(ROOT, "lib", "kantele", "character", "commands.ex")
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "npc_private_actions.json")

# add_action(handler, verb) —— 第一个参数是函数名，第二个是玩家输入的动词
ADD_ACTION_RE = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']""",
    re.VERBOSE,
)

# 全局命令：Kalevala.Character.Command.Router 宏的 parse("<verb>", ...)
GLOBAL_VERB_RE = re.compile(r'parse\(\s*"([^"]+)"')

# 方向/移动类 verb：由出口系统处理，不算「私有动作缺口」
MOVEMENT_VERBS = {
    "n", "s", "e", "w", "u", "d", "ne", "nw", "se", "sw",
    "north", "south", "east", "west", "up", "down",
    "northeast", "northwest", "southeast", "southwest",
    "enter", "out", "climb", "jump", "swim", "cross",
}

# handler 体分类用的特征
WRITE_FEATURES = ("write(", "tell_object(", "message(", "message_vision(",
                  "printf(", "notify_fail(", "say(", "shout(")
STATE_FEATURES = ("->set(", "->set_temp(", "->add(", "->move(", "->delete(",
                  "clone_object(", "new(", "->receive_", "->add_temp(")
# 战斗专属：`->start_busy(` 不算 —— 钱庄/兑换/比武招亲都会用它来占用玩家，
# 归进战斗会把银行存取款误判成战斗（本项目 B2 要处理的正是 busy 语义）。
COMBAT_FEATURES = ("kill_ob(", "fight_ob(", "COMBAT_D",
                   "->die(", "->receive_damage(", "->receive_wound(")
BUSY_FEATURES = ("->start_busy(", "->interrupt_me(", "busy")

# LPC 函数定义：**必须带返回类型**，否则 `if (...) {` 会被当成函数
DEF_RE = re.compile(
    r'^[ \t]*(?:varargs[ \t]+|static[ \t]+|public[ \t]+|private[ \t]+|nomask[ \t]+)*'
    r'(?:int|void|mixed|string|object|mapping|float|status)'
    r'[ \t\r\n]+\**[ \t]*([A-Za-z_]\w*)[ \t]*\(',
    re.MULTILINE,
)


def load_global_verbs():
    txt = open(COMMANDS_EX, encoding="utf-8", errors="replace").read()
    return set(GLOBAL_VERB_RE.findall(txt))


def parse_args(argv):
    p = argparse.ArgumentParser(description="NPC 私有动作勘查（只读）")
    p.add_argument(
        "--ignore-global",
        default="",
        help="逗号分隔的 verb，视作「尚未接线」，用于复现接线前基线",
    )
    p.add_argument("--out", default=OUT_JSON, help="JSON 输出路径（默认 scripts/tmp/npc_private_actions.json）")
    return p.parse_args(argv)


def kind_of(path):
    """按目录判定对象类型。

    **关键**：`d/<zone>/npc/obj/*.c` 是**物品**（乐器、面具、箱子…），不是 NPC。
    早先只判「路径里有 /npc/」会把 12 个物品文件算成 NPC —— `play`（琴箫）
    就是这样被误当成 NPC 动作的，实际是乐器对象注册的。
    """
    norm = path.replace("\\", "/")
    if "/npc/obj/" in norm:
        return "item"
    if "/npc/" in norm:
        return "npc"
    if "/obj/" in norm:
        return "item"
    if "/room/" in norm:
        return "room"
    return "other"


def is_npc_file(path):
    return kind_of(path) == "npc"


def iter_all_c():
    for dirpath, _dirnames, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if fn.endswith(".c"):
                yield os.path.join(dirpath, fn)


def iter_all_src():
    """`.c` + `.h`。

    **必须带 `.h`**：LPC 语料里有把 handler 定义在头文件里再 `#include` 进来的写法
    （`d/beijing/npc/matong.c` 的 10 个 `do_rideXX` 全在 `matongXX.h` 里）。
    只扫 `.c` 会把这些误判成 `undefined` —— 那 10 个动词是**有实现**的，
    只是实现藏在头文件里。
    """
    for dirpath, _dirnames, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if fn.endswith(".c") or fn.endswith(".h"):
                yield os.path.join(dirpath, fn)


def rel(path):
    return os.path.relpath(path, MUD_ROOT).replace("\\", "/")


def zone_of(relpath):
    parts = relpath.split("/")
    if len(parts) >= 2 and parts[0] in ("d", "clone", "b"):
        return parts[1]
    return parts[0]


def area_of(relpath):
    """顶层分区：d=游戏内容 / adm=巫师工具 / u=个人目录 / clone=共享库 / b=倚天屠龙区。

    **`b/` 不是备份**：`d/beijing/huiying.c` 的 `up` 出口指向 `/b/yitian/jiulou`，
    `d/beijing/road10.c` 的 `east` 指向 `/b/tulong/haigang` —— 是**可达区域**
    （倚天屠龙记副本内容），其私有动作要算进工作量。
    """
    return relpath.split("/")[0]


def extract_handler_body(txt, handler):
    """粗取函数体：找到 `handler(...)` 的定义行，从其后第一个 `{` 起做花括号配对。

    定义可能写成 `int do_x(string arg) {` 或 `int do_x(string arg)\\n{`，两种都认。
    不追求 LPC 语法完整（注释里的花括号会让计数漂移），够做特征分类即可。
    """
    pat = re.compile(
        r'^[^\n]*\b' + re.escape(handler) + r'\s*\([^)]*\)\s*\{',
        re.MULTILINE,
    )
    m = pat.search(txt)
    if not m:
        return None
    start = txt.find("{", m.start())
    if start < 0:
        return None
    depth = 0
    for idx in range(start, min(len(txt), start + 20000)):
        ch = txt[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return txt[start:idx + 1]
    return txt[start:start + 2000]


def classify(body):
    if not body:
        return "unknown"
    if any(f in body for f in COMBAT_FEATURES):
        return "combat"
    has_state = any(f in body for f in STATE_FEATURES)
    has_write = any(f in body for f in WRITE_FEATURES)
    if has_state and has_write:
        return "state+msg"
    if has_state:
        return "state"
    if has_write:
        return "message"
    return "unknown"


CONTROL_FEATURES = ("if(", "if (", "for(", "for (", "while(", "while (",
                    "switch(", "switch (", "case ", "do {")


def is_dead(body):
    """函数体在**任何分支之前**就无条件 `return` 了，且后面还跟着大段代码。

    典型：`kungfu/class/yunlong/tiandihui.h` 的 `do_join`：

        me = this_object(); ob = this_player();
        return notify_fail("天地会正在清理叛徒，不对外招人。\\n");
        //return 1;          <-- 以下整段 join 逻辑永远不执行

    这类 verb 玩家敲了只会得到一句「不对外招人」，**不需要移植**。

    两个必要条件，缺一不可：
    ① 第一个 `return` 之前没有任何分支（`if`/`for`/`while`/`switch`/`case`）；
    ② 该 `return` **之后还有实质代码**。
    只判 ① 会把「直线型函数末尾的 `return 1;`」全判成死功能
    （`b/tulong/npc/chang.c` 的 `do_compare`、`adm/npc/luban.c` 的 `do_show`
    都是这种），必须靠 ② 排掉。
    """
    if not body or len(body) < 3:
        return False
    inner = body[1:-1]                      # 去掉最外层花括号
    m = re.search(r"\breturn\b", inner)
    if not m:
        return False
    if any(f in inner[:m.start()] for f in CONTROL_FEATURES):
        return False
    semi = inner.find(";", m.end())
    if semi < 0:
        return False
    after = re.sub(r"\s+", "", inner[semi + 1:])
    return len(after) >= 80


def load_impl_hints(verbs, handlers):
    """检查某个 verb 是否**已在别处实现**，只是没挂在顶层动词上。

    典型例子：`BankCommand` 已实现存/取/查/兑换，但只注册了 `bank`/`银行`
    两个动词，LPC 的 NPC 却是把 `cun`/`qu`/`deposit`/`withdraw` 当独立顶层
    动词注册的 —— 这类「私有 verb」不是缺实现，而是缺接线，成本差一个量级。
    判据：命令模块 / NPC 纯层模块里出现过 "verb" 或 "handler 去 do_ 前缀"。
    """
    roots = [
        os.path.join(ROOT, "lib", "kantele", "character", "commands"),
        os.path.join(ROOT, "lib", "kantele", "npc"),
    ]
    blob = {}      # token -> [files]
    for root in roots:
        if not os.path.isdir(root):
            continue
        for fn in sorted(os.listdir(root)):
            if not fn.endswith(".ex"):
                continue
            path = os.path.join(root, fn)
            try:
                txt = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for token in set(verbs) | set(handlers):
                if ('"%s"' % token) in txt:
                    blob.setdefault(token, []).append("lib/.../%s" % fn)

    hints = {}
    for verb in verbs:
        hits = list(blob.get(verb, []))
        for handler in handlers.get(verb, []):
            stem = handler[3:] if handler.startswith("do_") else handler
            hits.extend(blob.get(stem, []))
        if hits:
            hints[verb] = sorted(set(hits))[:4]
    return hints


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    if not os.path.isdir(MUD_ROOT):
        print("MUD_ROOT 不存在: %s" % MUD_ROOT, file=sys.stderr)
        sys.exit(1)

    ignored = {v.strip() for v in args.ignore_global.split(",") if v.strip()}
    global_verbs = load_global_verbs()
    if ignored:
        # 视作未接线：从全局表里摘掉，让它们落回「私有」
        global_verbs -= ignored
        print("全局命令 verb 数（commands.ex 的 parse）: %d（已按 --ignore-global 排除 %d 个）"
              % (len(global_verbs), len(ignored)))
    else:
        print("全局命令 verb 数（commands.ex 的 parse）:", len(global_verbs))

    # ---------- pass 1：NPC 文件里的注册 ----------
    npc_files = 0
    files_with_action = 0
    calls = 0

    verb_count = Counter()
    verb_zones = defaultdict(set)
    verb_handlers = defaultdict(Counter)
    verb_samples = defaultdict(list)
    verb_areas = defaultdict(Counter)
    handler_npcs = defaultdict(set)          # handler -> {npc_file}
    local_kind = {}                          # (npc_file, handler) -> kind | None
    local_busy = {}                          # (npc_file, handler) -> bool | None
    local_dead = {}                          # (npc_file, handler) -> bool | None

    item_files = 0
    item_calls = 0
    item_verbs = Counter()

    for path in iter_all_c():
        kind = kind_of(path)

        # 物品侧（/obj/）：只做计数，供未来的 item 通道参考。
        # `play`（琴箫）、`climb`（铁箱）等都在这里 —— 它们是物品动作，不是 NPC。
        if kind == "item":
            item_files += 1
            try:
                itxt = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for _handler, verb in ADD_ACTION_RE.findall(itxt):
                item_calls += 1
                item_verbs[verb] += 1
            continue

        if kind != "npc":
            continue
        npc_files += 1
        try:
            txt = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        found = ADD_ACTION_RE.findall(txt)
        if not found:
            continue
        files_with_action += 1
        r = rel(path)
        z = zone_of(r)
        a = area_of(r)
        for handler, verb in found:
            calls += 1
            verb_count[verb] += 1
            verb_zones[verb].add(z)
            verb_areas[verb][a] += 1
            verb_handlers[verb][handler] += 1
            handler_npcs[handler].add(r)
            if len(verb_samples[verb]) < 3:
                verb_samples[verb].append("%s:%s" % (r, handler))
            if (r, handler) not in local_kind:
                # 注意：body 为 None = 本文件**没有定义**这个函数（继承来的），
                # 与「定义了但看不出特征」("unknown") 必须区分开 —— 前者要
                # 去别处找定义，后者是本文件里的真实实现。
                body = extract_handler_body(txt, handler)
                local_kind[(r, handler)] = classify(body) if body else None
                local_busy[(r, handler)] = (
                    any(f in body for f in BUSY_FEATURES) if body else None
                )
                local_dead[(r, handler)] = is_dead(body) if body else None

    print("NPC .c 文件总数            :", npc_files)
    print("含 add_action 的 NPC 文件   :", files_with_action)
    print("add_action 调用总数        :", calls)
    print("不同 verb                  :", len(verb_count))

    covered = {v: c for v, c in verb_count.items() if v in global_verbs}
    private = {v: c for v, c in verb_count.items() if v not in global_verbs}
    movement_like = {v: c for v, c in private.items() if v in MOVEMENT_VERBS}
    real_private = {v: c for v, c in private.items() if v not in MOVEMENT_VERBS}

    print("已由全局命令覆盖的 verb    : %d 个 / %d 次调用" % (len(covered), sum(covered.values())))
    print("**私有 verb（需新实现）**  : %d 个 / %d 次调用" % (len(private), sum(private.values())))
    print("  其中移动/方向类（出口系统管）: %d 个 / %d 次" % (len(movement_like), sum(movement_like.values())))
    print("  真正的私有动作 verb          : %d 个 / %d 次" % (len(real_private), sum(real_private.values())))

    hints = load_impl_hints(
        list(real_private.keys()),
        {v: list(verb_handlers[v]) for v in real_private},
    )
    hint_calls = sum(real_private[v] for v in hints)
    print("疑似已有实现、只缺动词接线    : %d 个 verb / %d 次调用" % (len(hints), hint_calls))

    # ---------- pass 2：为「本地未定义」的 handler 找定义处 ----------
    wanted = {h for h in handler_npcs
              if not any(local_kind.get((f, h)) is not None for f in handler_npcs[h])}
    print("本地未定义的 handler（疑似继承）:", len(wanted))

    defs = defaultdict(list)     # handler -> [(file, kind)]
    for path in iter_all_src():
        try:
            txt = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if not any((" " + h) in txt or ("\t" + h) in txt or ("*" + h) in txt for h in wanted):
            # 便宜的前置过滤：函数名总得在文本里出现
            continue
        for name in set(DEF_RE.findall(txt)):
            if name not in wanted:
                continue
            body = extract_handler_body(txt, name)
            defs[name].append((
                rel(path),
                classify(body),
                any(f in body for f in BUSY_FEATURES) if body else False,
                is_dead(body),
            ))

    # ---------- 汇总 ----------
    rows = []
    busy_verbs = Counter()
    for verb, count in sorted(real_private.items(), key=lambda kv: (-kv[1], kv[0])):
        kinds = Counter()
        resolved = {}
        busy = 0
        dead = 0
        for handler, hc in verb_handlers[verb].items():
            local = [local_kind[(f, handler)] for f in handler_npcs[handler]
                     if local_kind.get((f, handler)) is not None]
            if local:
                kinds[local[0]] += hc
                local_busy_flags = [local_busy.get((f, handler)) for f in handler_npcs[handler]]
                is_busy = any(flag for flag in local_busy_flags)
                is_dead_flag = any(
                    local_dead.get((f, handler)) for f in handler_npcs[handler]
                )
                resolved[handler] = {"via": "local", "kind": local[0],
                                     "busy": is_busy, "dead": is_dead_flag, "defs": []}
            else:
                d = defs.get(handler, [])
                kind = d[0][1] if d else "undefined"
                is_busy = any(b for _f, _k, b, _x in d)
                is_dead_flag = any(x for _f, _k, _b, x in d)
                kinds[kind] += hc
                resolved[handler] = {
                    "via": "inherited" if d else "undefined",
                    "kind": kind,
                    "busy": is_busy,
                    "dead": is_dead_flag,
                    "defs": sorted({f for f, _k, _b, _x in d})[:5],
                }
            if is_busy:
                busy += hc
            if is_dead_flag:
                dead += hc
        if busy:
            busy_verbs[verb] = busy
        rows.append({
            "verb": verb,
            "calls": count,
            "zones": len(verb_zones[verb]),
            "areas": dict(verb_areas[verb]),
            "handlers": resolved,
            "kinds": dict(kinds),
            "busy": busy,
            "dead": dead,
            "impl_hint": hints.get(verb, []),
            "samples": verb_samples[verb],
        })

    print("\n=== 私有 verb（按调用次数，前 30）===")
    print("%-12s %5s %5s  %-22s %s" % ("verb", "calls", "zones", "handler 分类", "定义来源"))
    for row in rows[:30]:
        kinds = " ".join("%s=%d" % (k, v) for k, v in sorted(row["kinds"].items()))
        vias = " ".join("%s:%s" % (h, i["via"]) for h, i in row["handlers"].items())
        print("%-12s %5d %5d  %-22s %s" % (row["verb"], row["calls"], row["zones"], kinds, vias))

    # 基类动作：一个 handler 被多个 NPC 注册、却定义在少数共享文件里。
    # 只看**私有** verb 的 handler —— 已被全局命令覆盖的（如 sell/value 走
    # feature/dealer.c）不算缺口，混进来会让清单失真。
    private_handlers = set()
    for verb in real_private:
        private_handlers.update(verb_handlers[verb])

    shared = []
    for handler, files in handler_npcs.items():
        if handler not in private_handlers:
            continue
        if len(files) < 2:
            continue
        d = sorted({f for f, _k, _b, _x in defs.get(handler, [])})
        if d and len(d) <= 2:
            shared.append({
                "handler": handler,
                "npc_files": len(files),
                "defs": d,
                "kind": defs[handler][0][1],
                "busy": defs[handler][0][2],
                "dead": defs[handler][0][3],
                "verbs": sorted(v for v, hs in verb_handlers.items() if handler in hs),
            })
    shared.sort(key=lambda x: (-x["npc_files"], x["handler"]))

    print("\n=== 基类动作（多个 NPC 共用一份实现，只需移植一次）前 20 ===")
    print("%-16s %6s %-14s %s" % ("handler", "npcs", "分类", "定义文件"))
    for s in shared[:20]:
        print("%-16s %6d %-14s %s" % (s["handler"], s["npc_files"], s["kind"],
                                      ", ".join(s["defs"])))
    print("基类动作合计: %d 个 handler" % len(shared))

    msg_only = [r for r in rows if set(r["kinds"]) == {"message"}]
    print("\n=== 纯输出型私有 verb（最易移植）===")
    for row in msg_only[:20]:
        print("%-12s %5d  %s" % (row["verb"], row["calls"], ", ".join(row["samples"][:2])))
    print("合计纯输出型: %d 个 / %d 次调用"
          % (len(msg_only), sum(r["calls"] for r in msg_only)))

    dead_rows = [r for r in rows if r["dead"]]
    print("\n=== 死功能（函数体开头就无条件 return，后续全是死代码）===")
    for row in dead_rows:
        print("%-12s %5d  %s" % (row["verb"], row["calls"], ", ".join(row["samples"][:2])))
    print("合计死功能: %d 个 / %d 次调用 —— 这些**不需要移植**"
          % (len(dead_rows), sum(r["calls"] for r in dead_rows)))

    item_private = {v: c for v, c in item_verbs.items() if v not in global_verbs}
    print("\n=== 附：物品侧（/obj/，不属于 NPC 通道）===")
    print("物品 .c 文件: %d / add_action 调用: %d / 不同 verb: %d"
          % (item_files, item_calls, len(item_verbs)))
    print("其中私有 verb: %d 个 / %d 次"
          % (len(item_private), sum(item_private.values())))
    top_items = sorted(item_private.items(), key=lambda kv: -kv[1])[:10]
    print("  前 10: " + ", ".join("%s=%d" % (v, c) for v, c in top_items))

    by_area = Counter()
    for verb, count in real_private.items():
        for a, c in verb_areas[verb].items():
            by_area[a] += c
    print("\n=== 疑似已有实现、只缺顶层动词接线 ===")
    print("%-12s %5s  %s" % ("verb", "calls", "疑似已有实现的模块"))
    for row in rows:
        if row["impl_hint"]:
            print("%-12s %5d  %s" % (row["verb"], row["calls"], ", ".join(row["impl_hint"])))

    print("\n=== 私有动作按顶层分区 ===")
    for a, c in by_area.most_common():
        print("  %-8s %d 次" % (a, c))

    out = {
        "meta": {
            "global_verbs": len(global_verbs),
            "npc_files": npc_files,
            "files_with_add_action": files_with_action,
            "add_action_calls": calls,
            "distinct_verbs": len(verb_count),
            "covered_verbs": len(covered),
            "covered_calls": sum(covered.values()),
            "private_verbs": len(private),
            "private_calls": sum(private.values()),
            "movement_like_verbs": len(movement_like),
            "real_private_verbs": len(real_private),
            "real_private_calls": sum(real_private.values()),
            "dead_verbs": len(dead_rows),
            "dead_calls": sum(r["calls"] for r in dead_rows),
            "impl_hint_verbs": len(hints),
            "impl_hint_calls": hint_calls,
            "inherited_handlers": len(wanted),
            "shared_base_handlers": len(shared),
            "item_files": item_files,
            "item_calls": item_calls,
            "item_private_verbs": len(item_private),
            "item_private_calls": sum(item_private.values()),
            "ignored_global": sorted(ignored),
        },
        "covered_verbs": dict(sorted(covered.items(), key=lambda kv: -kv[1])),
        "movement_like": dict(sorted(movement_like.items(), key=lambda kv: -kv[1])),
        "private_rows": rows,
        "shared_base_actions": shared,
        "private_calls_by_area": dict(by_area),
        "impl_hints": {v: hints[v] for v in sorted(hints)},
    }
    out_path = args.out
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("\nwritten:", out_path)


if __name__ == "__main__":
    main()
