#!/usr/bin/env python
"""S0: backfill LPC `set("material_attrib")` / `set("material_name")` into forge
materials' `meta` block.

LPC semantics
-------------
`material_attrib` — 原料品类字符串（"stone"/"steel"/"silk"/"iron"/"magic stone"）。
  莫邪 `do_show` / `accept_object` 用它判定「这是不是锻造原料」；`create_file` 把它
  写进生成物的 `material` 字段。转换器从未输出 → 全库锻造原料都缺。
`material_name` — 原料展示名（"神铁"/"上古寒铁"…，已去色码）。`create_file` 把
  "这是由{material_name}炼制而成" 写进生成物描述。

哪些块被写
----------
只有「已经带 `can_make`（即锻造原料）但缺 `material_attrib`」的 `items` 块。
`item_make` 不回填（仅 S3 生成物品时在内存置 true，用于 discard 退款判定）。

值来源（忠实）
------------
块上方的 `# Generated from C:/files/git/mud/.../<name>.c by LPCConverter` 注释给出
精确源 .c 路径（同 B9）；读其 `set("material_attrib", ...)` / `set("material_name", ...)`。
`material_name` 含色码宏（HIM/NOR/WHT…），取首个双引号内文本即可去色。
若源 .c 缺失或无 material_attrib，则按名称启发式兜底：含 丝/绸/纱 → "silk"，
否则 "stone"；material_name 兜底为物品名。

安全（同 B9 协议）
----------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：内存算完所有改动并过门禁（validate_ucl 完整 issue 集合比对、行号归一化 +
  insertion-only 校验），**全过**才备份、才写盘
* 备份写盘之前完成
* 幂等：已带 material_attrib 的块跳过
"""
import argparse
import datetime
import difflib
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
META_OPEN = re.compile(r"^\s{6}meta\s*=\s*\{\s*$")

NOR_MACRO = re.compile(r"\b(?:HIM|HIR|HIW|HIG|HIB|HIC|HIG|WHT|WHI|RED|GRN|BLU|"
                       r"BLK|CYA|CYN|YEL|MAG|NOR|HI[RYGBCMW])\b")


def norm(path):
    return path.replace("\\", "/").lower()


def strip_line_comment(line):
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "/" and i + 1 < len(line) and line[i + 1] == "/":
                return line[:i]
        i += 1
    return line


def skeleton_delta(line):
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
    i = start + 1
    while i < close:
        if META_OPEN.match(lines[i]):
            depth = 1
            j = i + 1
            while j < close:
                d = skeleton_delta(lines[j])
                depth += d
                if depth == 0:
                    return i, j
                j += 1
            return i, j - 1
        i += 1
    return None, None


def extract_quoted_after(src, key, strip=True):
    """Return value of set("key", "...") — first double-quoted string on the line.

    兼容 LPC 色码宏形式：`set("material_name", HIM "神铁" NOR)` → "神铁"。
    先按 `set("key",` 定位，再在该行其后取首个 `"..."` 内容（天然避开了前置宏）。
    """
    pat = re.compile(r'set\s*\(\s*"%s"\s*,' % re.escape(key))
    for line in src.split("\n"):
        clean = strip_line_comment(line)
        m = pat.search(clean)
        if not m:
            continue
        q = re.search(r'"([^"]*)"', clean[m.end():])
        if not q:
            continue
        val = q.group(1)
        if strip:
            val = NOR_MACRO.sub("", val)
        return val.strip()
    return None


def collect_sources():
    """Return dict: source_path -> {material_attrib, material_name} if present."""
    found = {}
    for root, _dirs, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                src = fh.read()
            vals = {}
            ma = extract_quoted_after(src, "material_attrib", strip=False)
            if ma:
                vals["material_attrib"] = ma
            mn = extract_quoted_after(src, "material_name", strip=True)
            if mn:
                vals["material_name"] = mn
            if vals:
                found[norm(path)] = vals
    return found


def heuristic_attrib(item_name):
    if any(ch in item_name for ch in ("丝", "绸", "纱")):
        return "silk"
    return "stone"


def _sanitize_ucl_str(s):
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", " ").replace("\r", " ")
    return s.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    sources = collect_sources()
    print("source files with material_attrib/material_name: %d" % len(sources))

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

        insertions = []  # (meta_close_idx, [lines])
        for kind, key, src, _start, close in iter_blocks(lines):
            if kind != "items":
                continue
            body = "\n".join(lines[_start + 1:close])
            # 只处理：已带 can_make（锻造原料）且缺 material_attrib 的块
            if not re.search(r"^\s{8}can_make\s*=", body, re.M):
                continue
            if re.search(r"^\s{8}material_attrib\s*=", body, re.M):
                stats["blocks_skipped"] += 1
                continue

            meta_open, meta_close = find_meta_block(lines, _start, close)
            if meta_open is None:
                stats["blocks_no_meta"] += 1
                continue

            vals = sources.get(src, {})
            ma = vals.get("material_attrib") or heuristic_attrib(key)
            mn = vals.get("material_name")

            # 物品展示名兜底：从 UCL 块的 name = "..." 取
            if not mn:
                nm = re.search(r'^\s{6}name\s*=\s*"([^"]*)"', body, re.M)
                mn = nm.group(1) if nm else key

            block_lines = [
                '        material_attrib = "%s"' % _sanitize_ucl_str(ma),
                '        material_name = "%s"' % _sanitize_ucl_str(mn),
            ]
            insertions.append((meta_close, block_lines))

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

    print(__import__("json").dumps(stats, ensure_ascii=False))

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
