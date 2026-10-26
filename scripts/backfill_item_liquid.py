#!/usr/bin/env python
"""P3: backfill LPC `set("liquid", ([ ... ]))` into `items` blocks' `meta` block.

LPC semantics
-------------
`set("liquid", ([ "type": "alcohol", "name": "米酒",
                  "remaining": 15, "drunk_apply": 3 ]))`

容器内液体的**初始**状态。`remaining` 是当前存量（`create()` 时恒等于
`max_liquid`），`type` 决定饮用副作用（`"alcohol"` → 醉度），`name` 是液体
显示名（「米酒」「茶水」）。

转换器从未输出该 mapping → 全库 82 处 LPC 源 / UCL 里 0 条。本批把它们
回填到 `items` 块内部的 `meta` 块，形如：

        liquid = {
            type = "alcohol"
            name = "米酒"
            remaining = 15
            drunk_apply = 3
        }

`Item.Meta` 得到 `:liquid`（map，默认 nil），由 `loader.ex parse_item_meta/1`
读取；运行时余量记在**实例** meta（`Kantele.World.Item.Liquid`），不动定义。

值处理
------
- 整数 → 原样（UCL 整型）
- 字符串字面量 → UCL 双引号字符串
- 颜色宏（`HIW`/`NOR`/`MAG`…）剥掉；相邻字符串**拼接**
  （`MAG"醉熏风"NOR"佳酿"` → `醉熏风佳酿`）
- 含未知标记（非宏、非字面量）的块 → 整块跳过并计数（宁漏不脏）

哪些块被写
----------
只有 `items` 块（liquid 是物品属性）。`characters` 块 0 个。

安全（同 B3/B5b/B8 协议）
------------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：先把所有区的改动在内存里算完并过门禁（insertion-only +
  validate_ucl 完整 issue 集合比对、行号归一化），**全过**才备份、才写盘
* 备份写盘 **之前** 完成
* 幂等：已携带 `liquid =` 的块跳过
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

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')

# `meta = {` 行（6 空缩进，与 name/description 同级）
META_OPEN = re.compile(r'^\s{6}meta\s*=\s*\{\s*$')

# set("liquid", ([ ... ]));
SET_LIQUID = re.compile(r'set\s*\(\s*"liquid"\s*,\s*\(\[(.*?)\]\)\s*\)\s*;', re.S)

# ANSI 颜色宏（include/ansi.h）。剥掉它们只为取字面量正文。
COLOR_MACROS = {
    "BLK", "RED", "GRN", "YEL", "BLU", "MAG", "CYN", "WHT",
    "HIK", "HIR", "HIG", "HIY", "HIB", "HIM", "HIC", "HIW",
    "BBLK", "BRED", "BGRN", "BYEL", "BBLU", "BMAG", "BCYN", "BWHT",
    "HBRED", "HBGRN", "HBYEL", "HBBLU", "HBMAG", "HBCYN", "HBWHT",
    "NOR", "BLINK", "HIRE", "HIBLK",
}

STR_LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
TOKEN = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')


def norm(path):
    return path.replace("\\", "/").lower()


def skeleton_delta(line):
    """Net brace count for one line, ignoring comments and string bodies."""
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


def iter_blocks(lines):
    """Yield (kind, key, source, open_idx, close_idx) per block."""
    depth = 0
    pending = None
    header = None
    for i, line in enumerate(lines):
        m = GEN.match(line.strip())
        if m and depth == 0:
            header = norm(m.group(1))
        if depth == 0:
            om = OPEN.match(line)
            if om:
                pending = (om.group(1), om.group(2), header, i)
        nxt = depth + skeleton_delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            kind, key, src, start = pending
            resolved = src
            for j in range(start + 1, i):
                lm = LPC.match(lines[j].strip())
                if lm and resolved in (None, header):
                    resolved = norm(lm.group(1))
            yield kind, key, resolved, start, i
            pending = None
        depth = nxt


def find_meta_block(lines, start, close):
    """Within items block [start+1, close-1], find `meta = { ... }` sub-block."""
    i = start + 1
    while i < close:
        if META_OPEN.match(lines[i]):
            depth = 1
            j = i + 1
            while j < close:
                depth += skeleton_delta(lines[j])
                if depth == 0:
                    return i, j
                j += 1
            return i, j - 1
        i += 1
    return None, None


def split_top_level(body):
    """Split LPC map body on commas that are outside string literals."""
    parts = []
    buf = []
    in_str = False
    i = 0
    while i < len(body):
        ch = body[i]
        if in_str:
            buf.append(ch)
            if ch == "\\" and i + 1 < len(body):
                buf.append(body[i + 1])
                i += 2
                continue
            if ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
                buf.append(ch)
            elif ch == ",":
                parts.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        i += 1
    if "".join(buf).strip():
        parts.append("".join(buf))
    return parts


def parse_value(raw):
    """Return int or str, or None when the value is not statically expressible."""
    raw = raw.strip()
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)

    # string (possibly with colour macros and adjacent-literal concatenation)
    lits = STR_LIT.findall(raw)
    if not lits:
        return None

    rest = STR_LIT.sub(" ", raw)
    for tok in TOKEN.findall(rest):
        if tok not in COLOR_MACROS:
            return None

    pieces = []
    for lit in lits:
        if "\\" in lit:
            # 只接受 \" 与 \' 这类简单转义；其余（含 \n、\\）一律放弃该块
            if re.search(r"\\[^\"']", lit):
                return None
            lit = lit.replace('\\"', '"').replace("\\'", "'")
        pieces.append(lit)

    text = "".join(pieces).strip()
    if text == "":
        return None
    return text


def parse_liquid(body):
    """Return ordered dict of the liquid mapping, or None if not expressible."""
    out = {}
    for part in split_top_level(body):
        part = part.strip()
        if not part:
            continue
        m = re.match(r'"([A-Za-z_][A-Za-z_0-9]*)"\s*:\s*(.+)$', part, re.S)
        if not m:
            return None
        key, raw = m.group(1), m.group(2)
        val = parse_value(raw)
        if val is None:
            return None
        out[key] = val

    if not out or not isinstance(out.get("remaining"), int):
        return None
    return out


def collect_sources():
    """Return dict: source_path -> liquid mapping (ordered dict)."""
    found = {}
    skipped = 0
    for root, _dirs, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    src = fh.read()
            except OSError:
                continue
            m = SET_LIQUID.search(src)
            if not m:
                continue
            parsed = parse_liquid(m.group(1))
            if parsed is None:
                skipped += 1
                continue
            found[norm(path)] = parsed
    return found, skipped


def ucl_escape(text):
    return text.replace('"', '\\"')


def render_liquid(mapping, indent=8):
    pad = " " * indent
    inner = " " * (indent + 4)
    lines = [pad + "liquid = {"]
    for key, val in mapping.items():
        if isinstance(val, int):
            lines.append("%s%s = %d" % (inner, key, val))
        else:
            lines.append('%s%s = "%s"' % (inner, key, ucl_escape(val)))
    lines.append(pad + "}")
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    sources, skipped = collect_sources()
    print("source files declaring liquid: %d (unexpressible skipped: %d)"
          % (len(sources), skipped))

    planned = []
    stats = {
        "zones": 0,
        "blocks_written": 0,
        "blocks_skipped": 0,
        "blocks_no_meta": 0,
        "inserted_lines": 0,
    }
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            orig = fh.read()
        lines = orig.split("\n")

        insertions = []  # (meta_close_idx, [lines to insert])
        for kind, key, src, _start, close in iter_blocks(lines):
            if kind != "items" or src not in sources:
                continue
            body = "\n".join(lines[_start + 1:close])
            if re.search(r"^\s{8}liquid\s*=", body, re.M):
                stats["blocks_skipped"] += 1
                continue

            meta_open, meta_close = find_meta_block(lines, _start, close)
            if meta_open is None:
                stats["blocks_no_meta"] += 1
                continue

            insertions.append((meta_close, render_liquid(sources[src])))

        if not insertions:
            continue

        new_lines = list(lines)
        for close_idx, block_lines in sorted(insertions, key=lambda x: -x[0]):
            for line_text in reversed(block_lines):
                new_lines.insert(close_idx, line_text)
        new = "\n".join(new_lines)

        if _vucl is not None:
            regressions = sorted(
                _norm_issues(_vucl._run_checks(new.encode("utf-8")))
                - _norm_issues(_vucl._run_checks(orig.encode("utf-8")))
            )
            if regressions:
                print("  !! %s self-gate blocked: %s" % (fn, regressions[:3]))
                return 2

        ok, why = _is_insertion_only(orig, new)
        if not ok:
            print("  !! %s is not insertion-only (%s) -- aborting" % (fn, why))
            return 2

        delta = len(new.split("\n")) - len(orig.split("\n"))
        stats["zones"] += 1
        stats["blocks_written"] += len(insertions)
        stats["inserted_lines"] += delta
        planned.append((path, new))
        print("  %-18s +%-4d lines  (%d blocks)" % (fn, delta, len(insertions)))

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
        rel = os.path.relpath(path, WORLD)
        dst = os.path.join(backup, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)
    print("backed up %d files to %s" % (len(planned), backup))

    for path, new in planned:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("wrote %d files (+%d lines)" % (len(planned), stats["inserted_lines"]))
    return 0


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


if __name__ == "__main__":
    sys.exit(main())
