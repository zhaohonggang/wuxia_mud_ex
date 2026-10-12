#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""perform 译文验收：比对 .ex 代码部分（不含注释）与 .c 代码部分的“中文文案”。

判据（语义等价）：
  - 对 .c：去块注释 / 去 // 注释 / 丢预处理行 / 展开字符串常量宏
           / 删颜色宏(NOR/HIR/...) / 拼接相邻字面量 / 取含中文的字符串
  - 对 .ex：去 @moduledoc / @doc 字符串 / 去 # 行注释
           / 拼接相邻字面量 / 取含中文的字符串
  - 归一化：两边的字符串都做 (a) 去首尾空白 (b) 去掉结尾的 \n / \t
           (c) 把「」括号视为普通字符（保留）
  - 判定：source 中文文案的多重集合 (Counter) 必须被 target 覆盖
          （target 可包含 source 没有的额外文案——例如 Elixir 侧补的
           模块名插值行；但 source 的每一条都必须在 target 中出现）

用法：
  python scripts/perf_acceptance.py <rel_path> [<rel_path> ...]
  python scripts/perf_acceptance.py --json <list.json>
  rel_path 形如 "bagua_quan/gua.ex"（相对 performs 根）
退出码：0 全部通过；1 有未通过；2 用法/解析错误。
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PERF_ROOT = REPO / "lib" / "kantele" / "combat" / "skills" / "performs"
LPC_ROOT = Path(r"C:/files/git/mud/kungfu/skill")
PROTECTED = REPO / "scripts" / "protected_performs.txt"

COLORS = {
    "NOR", "HIR", "HIG", "HIY", "HIB", "HIM", "HIC", "HIW", "HIK",
    "RED", "GRN", "YEL", "BLU", "MAG", "CYN", "WHT", "BLK",
    "BOLD", "BLINK", "REV", "HBRED", "HBGRN", "HBYEL", "HBBLU",
    "HBMAG", "HBCYN", "HBWHT", "HBBLK",
}


# ---------- .c 侧 ----------

def c_string_macros(src: str):
    defs = {}
    for m in re.finditer(r"^\s*#\s*define\s+(\w+)\s+(.+?)\s*$", src, re.M):
        strs = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
        if strs:
            defs[m.group(1)] = "".join(strs)
    return defs


def c_chinese_messages(src: str):
    defs = c_string_macros(src)
    s = re.sub(r"/\*.*?\*/", "", src, flags=re.S)          # 块注释
    s = re.sub(r"^\s*#[^\n]*$", "", s, flags=re.M)         # 预处理行
    for name, val in sorted(defs.items(), key=lambda kv: -len(kv[0])):
        lit = '"%s"' % val.replace("\\", "\\\\").replace('"', '\\"')
        s = re.sub(r"\b%s\b" % re.escape(name), lit, s)
    s = re.sub(r"//[^\n]*", "", s)                         # 行注释
    # 删颜色宏
    toks = re.split(r'("(?:[^"\\]|\\.)*")', s)
    parts = []
    for t in toks:
        if t.startswith('"') and t.endswith('"'):
            parts.append(t)
        else:
            parts.append(re.sub(r"\b(%s)\b" % "|".join(COLORS), "", t))
    s = "".join(parts)
    s = join_adjacent(s)
    return [x for x in re.findall(r'"((?:[^"\\]|\\.)*)"', s)
            if re.search(r"[\u4e00-\u9fff]", x)]


# ---------- .ex 侧 ----------

def ex_module_attrs(ex_src: str):
    """收集 @name "字面量" 模块属性（字符串常量），用于插值还原。

    排除 @moduledoc/@doc（它们是多行文档，不是文案常量）。
    """
    defs = {}
    for m in re.finditer(r'@(\w+)\s+"((?:\\.|[^"\\])*)"', ex_src):
        if m.group(1) in ("moduledoc", "doc"):
            continue
        defs[m.group(1)] = m.group(2)
    return defs


def ex_code_chinese(ex_src: str):
    attrs = ex_module_attrs(ex_src)
    # 去掉文档与注释（注释需按字符串感知方式剥离，避免吃掉 "#{...}"）
    s = re.sub(r'@moduledoc\s+""".*?"""', "", ex_src, flags=re.S)
    s = re.sub(r'@doc\s+""".*?"""', "", s, flags=re.S)
    s = re.sub(r'@doc\s+"(?:\\.|[^"\\])*"', "", s)
    s = strip_ex_line_comments(s)
    # 去掉模块属性声明 `@name "字面量"`（它们是常量声明，不作为独立文案）
    s = re.sub(r'@\w+\s+"(?:\\.|[^"\\])*"', "", s)
    # 字符串插值 "text #{@attr} text" -> 单字面量
    s = re.sub(r'"((?:\\.|[^"\\])*)"', lambda m: '"' + interp(m.group(1), attrs) + '"', s)
    # "a" <> "b"（可跨空白）拼接
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r'"((?:\\.|[^"\\])*)"\s*<>\s*"((?:\\.|[^"\\])*)"',
                   lambda m: '"' + m.group(1) + m.group(2) + '"', s)
    # 相邻字面量（.ex 少见，但保留）
    s = join_adjacent(s)
    return [x for x in re.findall(r'"((?:\\.|[^"\\])*)"', s)
            if re.search(r"[\u4e00-\u9fff]", x)]


def strip_ex_line_comments(s: str) -> str:
    """按字符串感知方式去掉 Elixir 行注释（# 只在字符串外且非 #{ 时才起注释）。"""
    out = []
    i, n = 0, len(s)
    in_str = False
    while i < n:
        ch = s[i]
        if in_str:
            if ch == "\\" and i + 1 < n:
                out.append(s[i:i + 2]); i += 2; continue
            if ch == '"':
                in_str = False
            out.append(ch); i += 1; continue
        if ch == '"':
            in_str = True; out.append(ch); i += 1; continue
        if ch == "#":
            # 跳过该行剩余
            while i < n and s[i] != "\n":
                i += 1
            continue
        out.append(ch); i += 1
    return "".join(out)


def interp(lit: str, attrs) -> str:
    # 把 #{@attr} / #{} 表达式里的 @attr 还原为字面量；其余表达式置空
    def repl(m):
        expr = m.group(1)
        names = re.findall(r"@(\w+)", expr)
        return "".join(attrs.get(n, "") for n in names)
    return re.sub(r"#\{([^{}]*)\}", repl, lit)


def join_adjacent(s: str) -> str:
    # 仅拼接「只被空白分隔」的相邻字面量（C 的 "a" "b" 惯例）。
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r'"\s*((?:[^"\\]|\\.)*)"[ \t\r\n]*"((?:[^"\\]|\\.)*)"',
                   lambda m: '"' + m.group(1) + m.group(2) + '"', s)
    return s


def norm(msg: str) -> str:
    """归一化：抹掉「名字/变量插入」与空白差异，只保留固定中文骨架。

    - C 侧：删除 `xxx->name()` 、`->query("...")` 等非字面量表达式残留
      （这些在抽取时本已不在字符串内，但 `"a" + x->name() + "b"` 的拼接
       会留下空洞；统一在 norm 里再兜一层）。
    - E 侧：删除 `$n`/`$N`/`$p`/`$P` 等占位符、`#{...}` 插值残留。
    - 两侧：去 `\\n`/`\\t`/空白。
    """
    m = msg
    # E 侧着色占位符（名字/对象）
    m = re.sub(r"\$[nNpPkKdD]", "", m)
    # 残留插值 #{...}
    m = re.sub(r"#\{[^{}]*\}", "", m)
    # C 侧可能残留的 ->name() / ->query(...) 片段
    m = re.sub(r"->\s*\w+\s*\([^()]*\)", "", m)
    # 转义与空白
    m = m.replace("\\n", "").replace("\\t", "")
    m = m.replace("\n", "").replace("\t", "")
    m = re.sub(r"\s+", "", m)
    return m.strip()


# ---------- 路径解析（镜像 extractor） ----------

def build_c_map():
    out = {}
    if not LPC_ROOT.exists():
        return out
    for d in sorted(LPC_ROOT.iterdir()):
        if not d.is_dir():
            continue
        for c in sorted(d.rglob("*.c")):
            parent = c.parent.name
            skill = c.parent.parent.name if parent in ("exert", "perform") else parent
            rel = f"{skill.replace('-', '_')}/{c.stem}.ex"
            rank = 1 if parent in ("exert", "perform") else 0
            old = out.get(rel)
            if old is None or rank > old[0]:
                out[rel] = (rank, c)
    return out


def load_protected():
    if not PROTECTED.exists():
        return set()
    return {l.strip() for l in PROTECTED.read_text(encoding="utf-8").splitlines()
            if l.strip()}


def check_one(rel: str, cmap):
    ex_path = PERF_ROOT / rel
    if rel not in cmap:
        return {"rel": rel, "status": "NO_LPC", "missing": [], "extra": []}
    _, c_path = cmap[rel]
    if not ex_path.exists():
        return {"rel": rel, "status": "NO_EX", "missing": [], "extra": []}

    src_msgs = c_chinese_messages(c_path.read_text(encoding="utf-8"))
    tgt_msgs = ex_code_chinese(ex_path.read_text(encoding="utf-8"))
    src_c = Counter(norm(m) for m in src_msgs)
    tgt_c = Counter(norm(m) for m in tgt_msgs)
    missing = list((src_c - tgt_c).elements())
    extra = list((tgt_c - src_c).elements())
    status = "PASS" if not missing else "FAIL"
    return {"rel": rel, "status": status, "missing": missing, "extra": extra,
            "src_n": len(src_msgs), "tgt_n": len(tgt_msgs)}


def main(argv):
    if argv[:1] == ["--json"]:
        rels = json.load(open(argv[1], encoding="utf-8"))
    elif argv and argv[0] == "--all-pending":
        prot = load_protected()
        cmap = build_c_map()
        rels = sorted(r for r in cmap if r not in prot)
    else:
        rels = argv
    if not rels:
        print(__doc__)
        return 2

    cmap = build_c_map()
    nfail = 0
    for rel in rels:
        r = check_one(rel, cmap)
        if r["status"] == "PASS":
            print(f"PASS  {r['rel']}  (c={r.get('src_n')} ex={r.get('tgt_n')})")
        else:
            nfail += 1
            print(f"{r['status']}  {r['rel']}")
            for m in r["missing"]:
                print(f"    - MISSING: {m!r}")
            for m in r["extra"]:
                print(f"    + EXTRA  : {m!r}")
    print(f"\n{nfail} FAIL / {len(rels) - nfail} PASS / {len(rels)} total")
    return 1 if nfail else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
