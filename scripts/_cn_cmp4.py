#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
_cn_cmp4.py — 更精确的『注释(LPC) vs 代码(Elixir)』中文覆盖分析。

_cn_cmp3 的问题：extract_concat 把一条 LPC 语句里**所有**字符串字面量
都当消息（例如 `me->query_temp("weapon") || me->query_temp("secondary_weapon")`
里的 "weapon"/"secondary_weapon" 被粘到 notify_fail 文案前，产生
`weaponsecondary_weapon只能空手施展。` 之类假阳性）。

本版只从**真正的消息载体**取 LPC 文案：
  - notify_fail(<expr>) 的参数
  - message_vision / message_combatd / tell_object(...) 内的字面量
  - 形如 msg / msg2 / ... = <expr>; 或 msg += <expr>; 的赋值
其中 <expr> 里相邻的字符串字面量按 LPC 规则拼接，忽略标识符、宏名。
宏 #define X "..." 会被展开。
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
    """去掉每行 '# ' 前缀，还原 LPC 文本（保留行结构以支持跨行拼接）。"""
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
    """把 #define X "lit" 展开到使用处（简单文本替换，忽略词边界误伤）。"""
    defs = {}
    for m in DEFINE.finditer(text):
        name, val = m.group(1), m.group(2).strip()
        # 只关心字面量/拼接宏，避免把函数宏也算进来
        if '"' in val:
            defs[name] = val
    if not defs:
        return text
    for name, val in defs.items():
        text = re.sub(r'\b' + re.escape(name) + r'\b', val, text)
    return text


def join_literals(expr):
    """把一段表达式里的字符串字面量按出现顺序拼接为一条消息。"""
    lits = STR.findall(expr)
    return "".join(lits)


def _scan_paren(text, start):
    """text[start] == '('，返回配对的 ')' 下标（不含），失败返回 -1。"""
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


def lpc_call_messages(text):
    """从 notify_fail(...) 与 message_* 调用中取消息。"""
    out = []
    for call in MSG_CALLS:
        for m in re.finditer(r'\b' + call + r'\s*\(', text):
            p = m.end() - 1  # index of '('
            end = _scan_paren(text, p)
            if end == -1:
                continue
            args = text[p + 1:end]
            # notify_fail/tell_object 常用第一参数；message_* 的第一/第二参数
            joined = join_literals(args)
            if has_cjk(joined):
                out.extend(_fragments(joined))
    return out


ASSIGN_RE = re.compile(r'\b(msg\w*|str|buf|message)\s*\+?=\s*([^;]*);', re.S)


def lpc_assign_messages(text):
    out = []
    for m in ASSIGN_RE.finditer(text):
        joined = join_literals(m.group(2))
        if has_cjk(joined):
            out.extend(_fragments(joined))
    return out


def _fragments(joined):
    """返回整条 + 各含 CJK 的分段（分段便于子串匹配）。"""
    res = [joined]
    for l in STR.findall(joined):
        if has_cjk(l):
            res.append(l)
    return res


def code_messages(dtext):
    return [m.group(1) for m in STR.finditer(dtext) if has_cjk(m.group(1))]


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


def main():
    files = sorted(PERF_DIR.rglob("*.ex"))
    rows = []
    agg = {"total": len(files), "no_code_msg": 0, "missing_files": 0,
           "clean": 0, "sum_c": 0, "sum_d": 0, "sum_missing": 0}
    miss_by_file = collections.Counter()
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        ctext, dtext = split_comment_code(text)
        raw = expand_defines(lpc_text(ctext))
        cmsgs = lpc_call_messages(raw) + lpc_assign_messages(raw)
        cmsgs = [canon(m) for m in cmsgs if m.strip()]
        dmsgs = [canon(m) for m in code_messages(dtext) if m.strip()]
        cset, dset = set(cmsgs), set(dmsgs)
        if not dset:
            agg["no_code_msg"] += 1
        agg["sum_c"] += len(cset)
        agg["sum_d"] += len(dset)

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
        rel = str(f.relative_to(PERF_DIR)).replace("\\", "/")
        if missing:
            agg["missing_files"] += 1
        else:
            agg["clean"] += 1
        agg["sum_missing"] += len(missing)
        rows.append({"file": rel, "n_c": len(cset), "n_d": len(dset),
                     "missing_n": len(missing), "missing": missing[:8]})

    print("=" * 72)
    print("精确对比 v4：只从真正消息载体(notify_fail/message_*/msg=)提取 LPC 文案")
    print("=" * 72)
    print(f"文件总数                         : {agg['total']}")
    print(f"代码区无中文消息                 : {agg['no_code_msg']}")
    print(f"仍存在『注释有、代码缺』的文件   : {agg['missing_files']}")
    print(f"消息已完全覆盖的文件             : {agg['clean']}")
    print(f"注释消息总条目 {agg['sum_c']} / 代码消息总条目 {agg['sum_d']}")
    print(f"真实缺失消息条目                 : {agg['sum_missing']}")
    print("=" * 72)

    rows.sort(key=lambda r: r["missing_n"], reverse=True)
    print("\n### 仍缺文案最多的 25 个文件")
    for r in rows[:25]:
        print(f"\n{r['file']}  注释{r['n_c']} / 代码{r['n_d']}  缺 {r['missing_n']}")
        for m in r["missing"][:3]:
            print(f"    - {m[:70]}")

    out = ROOT / "tmp" / "cn_cmp4_report.json"
    out.write_text(json.dumps({"summary": agg, "rows": rows},
                              ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n完整报告 -> {out}")


if __name__ == "__main__":
    main()
