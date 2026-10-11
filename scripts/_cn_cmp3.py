#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
_cn_cmp3.py — 精确对比（改进版）
修正 _cn_cmp2 的主要假阳性：LPC 源码里消息常被切成多行相邻字面量拼接：
    msg = HIR "$N" HIR "一声清啸，十指纷弹..." 
          "彼伏、连绵不绝..." HIR "！\n";
                ^^^^^^^^^^^^^^^ 与上一行同一消息
本版先把注释区里"相邻/跨行"的字符串字面量按 LPC 规则拼接成完整消息，
再与代码区消息做比对。

同时把宏定义 #define X "..." 展开，避免 DING/ZONG 之类宏名污染判定。
"""
import re
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERF_DIR = ROOT / "lib" / "kantele" / "combat" / "skills" / "performs"

CJK = re.compile(r"[\u4e00-\u9fff]")
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')


def has_cjk(s):
    return bool(CJK.search(s))


def cjk_runs(s):
    out, cur = [], []
    for ch in s:
        if CJK.match(ch):
            cur.append(ch)
        else:
            if len(cur) >= 2:
                out.append("".join(cur))
            cur = []
    if len(cur) >= 2:
        out.append("".join(cur))
    return out


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


def lpc_messages(ctext):
    """从 # 注释中恢复 LPC 消息：把相邻字符串字面量拼接。
    规则：同一 LPC 语句内、被 + 或空白分隔的多个 "..." 视作一条消息。
    简化实现：逐条注释行去掉 '# ' 前缀，累积连续含引号的行，
    直到遇到分号 ';' 或非引号行结束一条语句。
    """
    # 还原成 LPC 文本（去 # 前缀、去行号缩进）
    lines = []
    for line in ctext.splitlines():
        s = line.strip()
        if not s.startswith("#"):
            continue
        body = s[1:]
        if body.startswith(" "):
            body = body[1:]
        lines.append(body)

    # 逐语句聚合
    messages = []
    buf = ""
    for ln in lines:
        if '"' in ln:
            buf += "\n" + ln
        # 语句结束（分号）或遇到明显非续行
        stripped = ln.strip()
        if stripped.endswith(";") or (buf and not stripped.endswith(('"', ',', '{', '}')) and '"' not in ln and buf):
            # flush
            messages.extend(extract_concat(buf))
            buf = ""
    if buf:
        messages.extend(extract_concat(buf))
    return messages


def extract_concat(block):
    """把一块 LPC 文本中相邻字符串字面量拼成完整消息。"""
    out = []
    # 按 ';' 再切（保险）
    for stmt in block.split(";"):
        lits = STR.findall(stmt)
        if not lits:
            continue
        # 只保留含 CJK 的连续片段：一旦遇到不含 CJK 的短变量字面量（如 ""），
        # 仍拼接（LPC 中空串也算续接）
        joined = "".join(lits)
        if has_cjk(joined):
            out.append(joined)
            # 也单独保留每段，作为次级匹配目标
            for l in lits:
                if has_cjk(l):
                    out.append(l)
    return out


def code_messages(dtext):
    return [m.group(1) for m in STR.finditer(dtext) if has_cjk(m.group(1))]


def canon(s):
    s = s.replace("\\n", "").replace("\\t", "").replace('\\"', '"')
    return re.sub(r"\s+", "", s)


def main():
    files = sorted(PERF_DIR.rglob("*.ex"))
    rows = []
    agg = {"total": len(files), "no_code_msg": 0, "missing_files": 0,
           "clean": 0, "sum_c": 0, "sum_d": 0}
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        ctext, dtext = split_comment_code(text)
        cmsgs = [canon(m) for m in lpc_messages(ctext)]
        dmsgs = [canon(m) for m in code_messages(dtext)]
        cset = {m for m in cmsgs if m}
        dset = {m for m in dmsgs if m}
        if not dset:
            agg["no_code_msg"] += 1
        agg["sum_c"] += len(cset)
        agg["sum_d"] += len(dset)

        # missing：注释消息未被代码任何消息"包含"（子串）
        missing = []
        for m in sorted(cset, key=len, reverse=True):
            if any(m in d or d in m for d in dset):
                continue
            # 软化：CJK 片段是否都被覆盖
            mr = cjk_runs(m)
            if mr and all(any(r in d for d in dset) for r in mr):
                continue
            missing.append(m)
        rel = str(f.relative_to(PERF_DIR)).replace("\\", "/")
        if missing:
            agg["missing_files"] += 1
        else:
            agg["clean"] += 1
        rows.append({"file": rel, "n_c": len(cset), "n_d": len(dset),
                     "missing_n": len(missing), "missing": missing[:6]})

    print("=" * 72)
    print("改进对比（跨行拼接还原后）：注释区 LPC 消息 vs 代码区 Elixir 消息")
    print("=" * 72)
    print(f"文件总数                         : {agg['total']}")
    print(f"代码区无中文消息                 : {agg['no_code_msg']}")
    print(f"仍存在『注释有、代码缺』的文件   : {agg['missing_files']}")
    print(f"消息已完全覆盖的文件             : {agg['clean']}")
    print(f"注释消息总条目 {agg['sum_c']} / 代码消息总条目 {agg['sum_d']} "
          f"-> {agg['sum_d']/max(agg['sum_c'],1)*100:.1f}%")
    print("=" * 72)

    rows.sort(key=lambda r: r["missing_n"], reverse=True)
    print("\n### 仍缺文案最多的 25 个文件")
    for r in rows[:25]:
        print(f"\n{r['file']}  注释{r['n_c']} / 代码{r['n_d']}  缺 {r['missing_n']}")
        for m in r["missing"][:3]:
            print(f"    - {m[:60]}")

    out = ROOT / "tmp" / "cn_cmp3_report.json"
    out.write_text(json.dumps({"summary": agg, "rows": rows},
                              ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n完整报告 -> {out}")


if __name__ == "__main__":
    main()
