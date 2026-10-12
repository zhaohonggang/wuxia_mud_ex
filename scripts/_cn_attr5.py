#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_cn_attr5.py — 把『真实缺失文案』归因到 LPC 载体，找出可机械补齐的类。

对每个 perform：
  1) 用 _cn_cmp4 的口径算出 missing（注释有、代码缺）文案；
  2) 在还原后的 LPC 文本里定位每条 missing 的**承载调用**，并按构造分类：
       - notify_fail  : `notify_fail(<expr>)`（门槛文案；多可机械补）
       - message_vision / message_combatd : 广播
       - tell_object  : 定向提示
       - write        : 单向输出（多为止损/提示）
       - msg_assign   : `msg = ...` / `msg += ...`（后续常交给 message_combatd）
       - literal_only : 其他（如函数实参、数组初始化等）
用法：python scripts/_cn_attr5.py
"""
import re
import json
import collections
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERF_DIR = ROOT / "lib" / "kantele" / "combat" / "skills" / "performs"

CJK = re.compile(r"[\u4e00-\u9fff]")
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
DEFINE = re.compile(r'^\s*#define\s+([A-Za-z_]\w*)\s+(.+?)\s*$')


def has_cjk(s):
    return bool(CJK.search(s))


def split_comment_code(text):
    comment, code = [], []
    in_mod = False
    for raw in text.splitlines():
        s = raw.strip()
        if not in_mod and '@moduledoc """' in s:
            in_mod = True
            comment.append(raw)
            if s.count('"""') >= 2 and s.rstrip().endswith('"""'):
                in_mod = False
            continue
        if in_mod:
            comment.append(raw)
            if '"""' in s:
                in_mod = False
            continue
        (comment if s.startswith("#") else code).append(raw)
    return "\n".join(comment), "\n".join(code)


def lpc_text(ctext):
    out = []
    for line in ctext.splitlines():
        s = line.strip()
        if not s.startswith("#"):
            continue
        body = s[1:]
        if body.startswith(" "):
            body = body[1:]
        out.append(body)
    return "\n".join(out)


def expand_defines(text):
    defs = {}
    for m in DEFINE.finditer(text):
        name, val = m.group(1), m.group(2).strip()
        if '"' in val:
            defs[name] = val
    for name, val in defs.items():
        text = re.sub(r'\b' + re.escape(name) + r'\b', val, text)
    return text


def join_literals(expr):
    return "".join(STR.findall(expr))


def _scan_paren(text, start):
    depth = 0
    in_str = False
    i = start
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == '\\':
                i += 2
                continue
            if ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch in '([':
            depth += 1
        elif ch in ')]':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


MSG_CALLS = ("notify_fail", "message_vision", "message_combatd", "tell_object",
             "message", "write", "wizard")
ASSIGN_RE = re.compile(r'\b(msg\w*|str|buf|message)\s*\+?=\s*([^;]*);', re.S)


def _fragments(joined):
    res = [joined]
    for l in STR.findall(joined):
        if has_cjk(l):
            res.append(l)
    return res


def canon(s):
    s = s.replace("\\n", "").replace("\\t", "").replace('\\"', '"')
    return re.sub(r"\s+", "", s)


def cjk_runs(s):
    out, cur = [], []
    for ch in s:
        if CJK.match(ch):
            cur.append(ch)
        else:
            if len(cur) >= 3:
                out.append("".join(cur))
            cur = []
    if len(cur) >= 3:
        out.append("".join(cur))
    return out


def code_messages(dtext):
    return [m.group(1) for m in STR.finditer(dtext) if has_cjk(m.group(1))]


def build_carriers(raw):
    """返回 [(kind, canon_msg, spans...)]，按载体分类。"""
    carriers = []
    for call in MSG_CALLS:
        for m in re.finditer(r'\b' + call + r'\s*\(', raw):
            p = m.end() - 1
            end = _scan_paren(raw, p)
            if end == -1:
                continue
            joined = join_literals(raw[p + 1:end])
            if has_cjk(joined):
                for frag in _fragments(joined):
                    kind = call if call in ("notify_fail", "tell_object", "write",
                                            "message_vision", "message_combatd") else "literal_only"
                    carriers.append((kind, canon(frag)))
    for m in ASSIGN_RE.finditer(raw):
        joined = join_literals(m.group(2))
        if has_cjk(joined):
            for frag in _fragments(joined):
                carriers.append(("msg_assign", canon(frag)))
    return carriers


def main():
    files = sorted(PERF_DIR.rglob("*.ex"))
    kind_cnt = collections.Counter()
    samples = collections.defaultdict(list)
    total_missing = 0
    unmatched = 0
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        ctext, dtext = split_comment_code(text)
        raw = expand_defines(lpc_text(ctext))
        carriers = build_carriers(raw)
        dset = {canon(m) for m in code_messages(dtext) if m.strip()}

        # missing = 注释文案未在代码出现（与 _cn_cmp4 同口径）
        cset = {c for _, c in carriers if c}
        missing = []
        for m in sorted(cset, key=len, reverse=True):
            if not m:
                continue
            if any(m in d or d in m for d in dset):
                continue
            mr = cjk_runs(m)
            if mr and all(any(r in d for d in dset) for r in mr):
                continue
            missing.append(m)
        total_missing += len(missing)
        rel = str(f.relative_to(PERF_DIR)).replace("\\", "/")
        for msg in missing:
            # 找载体类型：优先精确，其次子串
            kinds = [k for k, c in carriers if c == msg]
            if not kinds:
                kinds = [k for k, c in carriers if msg and (msg in c or c in msg)]
            if kinds:
                kind = kinds[0]
                kind_cnt[kind] += 1
                if len(samples[kind]) < 6:
                    samples[kind].append((rel, msg[:50]))
            else:
                unmatched += 1
                kind_cnt["UNMATCHED"] += 1
                if len(samples["UNMATCHED"]) < 6:
                    samples["UNMATCHED"].append((rel, msg[:50]))

    print("=" * 70)
    print("缺失文案归因（v5）")
    print("=" * 70)
    print(f"总缺失: {total_missing}   （未匹配载体: {unmatched}）")
    for k, v in kind_cnt.most_common():
        print(f"  {k:18s} {v}")
    print("-" * 70)
    for k, lst in samples.items():
        print(f"\n[{k}]")
        for rel, m in lst:
            print(f"   {rel}  |  {m}")


if __name__ == "__main__":
    main()
