#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4c：静态 item_desc 回填（dry-run 默认，--write 才落盘）

背景
----
Elixir 转换器只把 `set("item_desc", ([ kw : "字面量" ]))` 写进 UCL；
闭包值 `(: look_x :)` 与 `@TEXT ... TEXT` 被丢弃，导致 `look <kw>` 回
「这里没有这个东西。」。本脚本把**纯静态**的闭包/`@TEXT` 文本补回 UCL。

范围（与 docs/p5-4-look-inquiry-survey.zh-CN.md 对齐）
- 纯静态闭包：函数体无 if/query/temp/外部调用，单 return（可含局部字符串变量）。
- `@TEXT ... TEXT`：按字面文本抽取。
- 跳过：颜色宏拼接（转换器已写）、条件闭包、变量/调用表达式（归 P5-4d）。

约束
----
- P1：只读 import `scripts/lpc_converter.py`，不修改它。
- P4：只增；不删/不改既有行；幂等（已存在的 key 跳过）。
- 备份 → 写 → 由调用方跑 `scripts/validate_ucl.py` + `mix test`。

用法
----
  python scripts/backfill_room_item_desc_static.py            # dry-run
  python scripts/backfill_room_item_desc_static.py --write    # 落盘（先备份）
  python scripts/backfill_room_item_desc_static.py --zone hengyang --write
"""

import argparse
import json
import os
import re
import sys
import time
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import survey_p54_look as S  # noqa: E402
import lpc_converter as C  # noqa: E402

MUD_ROOT = "C:/files/git/mud"
WORLD_DIR = os.path.join(ROOT, "data", "world")
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "p54c_backfill_plan.json")

GEN_RE = re.compile(r"^#\s*Generated from (\S+) by LPCConverter")
ROOMS_RE = re.compile(r'^\s*rooms "([^"]+)" \{\s*$')
ROOM_CLOSE_RE = re.compile(r"^    \}\s*$")
ITEM_DESC_OPEN_RE = re.compile(r"^item_desc = \{\s*$")
ITEM_DESC_CLOSE_RE = re.compile(r"^\}\s*$")
ITEM_DESC_ENTRY_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*=")
# LPC heredoc：`@DELIM ... DELIM`（@TEXT / @WALL / @SHADOWS ...），可被颜色宏
# 包裹（`HIY @TEXT ... TEXT NOR`），故不锚定首尾。
HEREDOC_RE = re.compile(r"@([A-Z_]+)\b(.*?)^[ \t]*\1\b", re.DOTALL | re.MULTILINE)
# elias 无法 lex 反斜杠+空白（仅允许 `\word` / `\quotes`）；ASCII 图里的
# `\ `（如 huashan sgyhole 石壁图）会致解析失败，折叠为空格。
BS_WS_RE = re.compile(r"\\\s")


def safe_text(t):
    return BS_WS_RE.sub(" ", t)
# 按「带引号的 key :」位置切分 pair：可安全容纳值内部的逗号/换行（heredoc）。
KEY_PAIR_RE = re.compile(r'"([^"]*)"\s*:\s*')


def iter_pairs(body):
    ms = list(KEY_PAIR_RE.finditer(body))
    for i, m in enumerate(ms):
        start = m.end()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(body)
        raw = body[start:end].strip().rstrip(",").rstrip()
        yield m.group(1), raw


def capture_return_expr(body):
    """从函数体取静态 return 表达式（尊重字符串/转义）。"""
    i = 0
    n = len(body)
    in_str = False
    esc = False
    while i < n:
        ch = body[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            i += 1
            continue
        if body.startswith("return", i):
            j = i + len("return")
            # 边界：前一个字符非标识符
            if i > 0 and (body[i - 1].isalnum() or body[i - 1] == "_"):
                i += 1
                continue
            # 跳到分号（顶层）
            k = j
            in_s = False
            e = False
            while k < n:
                c = body[k]
                if in_s:
                    if e:
                        e = False
                    elif c == "\\":
                        e = True
                    elif c == '"':
                        in_s = False
                elif c == '"':
                    in_s = True
                elif c == ";":
                    return body[j:k].strip()
                k += 1
            return None
        i += 1
    return None


def local_var_expr(body, var):
    """`type var; ... var = <expr>;` → 取赋值表达式。"""
    m = re.search(r"\b%s\s*=\s*" % re.escape(var), body)
    if not m:
        return None
    k = m.end()
    n = len(body)
    in_s = False
    e = False
    while k < n:
        c = body[k]
        if in_s:
            if e:
                e = False
            elif c == "\\":
                e = True
            elif c == '"':
                in_s = False
        elif c == '"':
            in_s = True
        elif c == ";":
            return body[m.end():k].strip()
        k += 1
    return None


def render_expr(expr):
    """LPC 字符串表达式 → 纯文本（剥离颜色宏），失败返回 ""。"""
    if not expr:
        return ""
    expr = expr.strip()
    tm = HEREDOC_RE.search(expr)
    if tm:
        return C._process_literal_string(tm.group(2))
    val = C._parse_lpc_value(expr)
    return C._item_desc_text(val)


def closure_text(fn_name, funcs):
    body = funcs.get(fn_name)
    if not body:
        return "", "missing"
    if S.classify_closure(body) != "static":
        return "", "conditional"
    expr = capture_return_expr(body)
    if expr is None:
        return "", "no_return"
    # 返回局部字符串变量
    if re.fullmatch(r"[A-Za-z_]\w*", expr):
        var_expr = local_var_expr(body, expr)
        if var_expr is not None:
            expr = var_expr
    text = render_expr(expr)
    return (text, "ok" if text else "empty")


def collect_proposals(zone_filter):
    """source_path -> {keyword: text}。"""
    proposals = defaultdict(dict)
    stats = defaultdict(int)

    for dirpath, _d, filenames in os.walk(os.path.join(MUD_ROOT, "d")):
        for fn in filenames:
            if not fn.endswith(".c"):
                continue
            full = os.path.join(dirpath, fn).replace("\\", "/")
            if zone_filter and ("/d/%s/" % zone_filter) not in full:
                continue
            try:
                with open(full, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except OSError:
                continue

            funcs = None
            for m in S.ITEM_DESC_RE.finditer(text):
                for kw, raw in iter_pairs(m.group(1)):
                    key = C._normalize_item_keyword(kw)
                    if key == "":
                        stats["skip_bad_key"] += 1
                        continue

                    cm = S.CLOSURE_RE.match(raw)
                    if cm:
                        if funcs is None:
                            funcs = S.extract_functions(text)
                        rendered, reason = closure_text(cm.group(1), funcs)
                        stats["closure_" + reason] += 1
                        if rendered:
                            proposals[full][key] = safe_text(rendered)
                        continue

                    tm = HEREDOC_RE.search(raw)
                    if tm:
                        rendered = C._process_literal_string(tm.group(2))
                        stats["text_macro_" + ("ok" if rendered else "empty")] += 1
                        if rendered:
                            proposals[full][key] = safe_text(rendered)
                        continue

                    sub = S.dynamic_subtype(raw)
                    stats["dynamic_" + sub] += 1

    return proposals, stats


def scan_ucl_files():
    """返回 {source_path: [(ucl_path, room_key, open_idx, close_idx, desc_open, desc_close, existing_keys)]}"""
    found = defaultdict(list)
    for fn in sorted(os.listdir(WORLD_DIR)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD_DIR, fn)
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            lines = fh.read().splitlines()

        src = None
        i = 0
        while i < len(lines):
            gm = GEN_RE.match(lines[i])
            if gm:
                src = gm.group(1).replace("\\", "/")
            rm = ROOMS_RE.match(lines[i])
            if rm:
                key = rm.group(1)
                open_idx = i
                # 房间闭合：下一个 4 空格 }
                close_idx = None
                desc_open = desc_close = None
                existing = set()
                j = i + 1
                while j < len(lines):
                    if ROOM_CLOSE_RE.match(lines[j]):
                        close_idx = j
                        break
                    if ITEM_DESC_OPEN_RE.match(lines[j]):
                        desc_open = j
                        k = j + 1
                        while k < len(lines):
                            if ITEM_DESC_CLOSE_RE.match(lines[k]):
                                desc_close = k
                                break
                            em = ITEM_DESC_ENTRY_RE.match(lines[k])
                            if em:
                                existing.add(em.group(1))
                            k += 1
                    j += 1
                if src and close_idx is not None:
                    found[src].append(
                        (path, key, open_idx, close_idx, desc_open, desc_close, existing)
                    )
                i = close_idx if close_idx is not None else i + 1
                continue
            i += 1
    return found


def build_plan(proposals, found):
    plan = []  # (ucl_path, room_key, missing{key:text}, has_block, desc_close, close_idx)
    for src, rooms in found.items():
        props = proposals.get(src)
        if not props:
            continue
        for (path, key, _o, close_idx, desc_open, desc_close, existing) in rooms:
            missing = {k: v for k, v in props.items() if k not in existing}
            if not missing:
                continue
            plan.append(
                {
                    "ucl": path,
                    "room": key,
                    "src": src,
                    "has_block": desc_open is not None,
                    "desc_close": desc_close,
                    "close": close_idx,
                    "missing": missing,
                }
            )
    return plan


def write_plan(plan):
    by_file = defaultdict(list)
    for item in plan:
        by_file[item["ucl"]].append(item)

    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup_dir = os.path.join(SCRIPT_DIR, "tmp", "backup-item-desc-" + stamp)
    os.makedirs(backup_dir, exist_ok=True)

    written_rooms = 0
    written_keys = 0
    for path, items in by_file.items():
        with open(path, "r", encoding="utf-8", newline="") as fh:
            raw = fh.read()
        # 保留原换行风格：按 splitlines 处理
        lines = raw.splitlines()
        backup_name = os.path.basename(path)
        with open(os.path.join(backup_dir, backup_name), "w", encoding="utf-8", newline="") as bf:
            bf.write(raw)

        # 自下而上插入，保持行号有效
        for item in sorted(items, key=lambda x: x["close"], reverse=True):
            if item["has_block"]:
                pos = item["desc_close"]
                new_lines = [
                    ' %s = "%s"' % (k, C._escape_set_string(v))
                    for k, v in item["missing"].items()
                ]
            else:
                pos = item["close"]
                new_lines = ["item_desc = {"] + [
                    ' %s = "%s"' % (k, C._escape_set_string(v))
                    for k, v in item["missing"].items()
                ] + ["}"]
            lines[pos:pos] = new_lines
            written_rooms += 1
            written_keys += len(item["missing"])

        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write("\n".join(lines) + ("\n" if raw.endswith("\n") else ""))

    return backup_dir, written_rooms, written_keys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="落盘（默认 dry-run）")
    ap.add_argument("--zone", default="", help="只处理某个 zone，如 hengyang")
    args = ap.parse_args()

    proposals, stats = collect_proposals(args.zone)
    found = scan_ucl_files()
    plan = build_plan(proposals, found)

    total_keys = sum(len(p["missing"]) for p in plan)
    rooms = len(plan)
    files = len({p["ucl"] for p in plan})

    result = {
        "dry_run": not args.write,
        "stats": dict(stats),
        "rooms_with_missing": rooms,
        "missing_keys": total_keys,
        "ucl_files": files,
        "plan": [
            {
                "ucl": os.path.relpath(p["ucl"], ROOT).replace("\\", "/"),
                "room": p["room"],
                "src": p["src"],
                "missing": p["missing"],
            }
            for p in plan
        ],
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(result, fh, ensure_ascii=False, indent=2)

    print("=== P5-4c 静态 item_desc 回填（%s）===" % ("WRITE" if args.write else "dry-run"))
    print("候选来源统计: %s" % dict(stats))
    print("待补房间: %d / 待补键: %d / 涉及 UCL 文件: %d" % (rooms, total_keys, files))
    if plan:
        print("样例:")
        for p in plan[:8]:
            print("  %s  room=%s  +%d  %s"
                  % (os.path.basename(p["ucl"]), p["room"], len(p["missing"]),
                     ", ".join(sorted(p["missing"])[:6])))

    if args.write and plan:
        backup_dir, wr, wk = write_plan(plan)
        print("已备份 → %s" % backup_dir)
        print("已写入: %d 房间 / %d 键" % (wr, wk))
    else:
        print("未落盘（加 --write 执行）。计划 → %s" % OUT_JSON)


if __name__ == "__main__":
    main()
