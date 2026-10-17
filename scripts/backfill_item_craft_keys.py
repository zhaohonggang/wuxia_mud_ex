#!/usr/bin/env python
"""B9: backfill LPC `set("can_make"/"not_make"/"power_point"/"item_origin")` into items' `meta` block.

LPC semantics
-------------
`set("can_make", ...)` / `set("not_make", ...)` — 物品可/不可打造的装备类型列表
  （字符串如 "all"/"甲"，或列表 `({ "战衣", "腰带" })`）。
`set("power_point", N)` — 打造所需活力/经验点数（整数，有的行被 `//` 注释掉，需跳过）。
`set("item_origin", N)` — 物品来源标记（整数，恒为 1）。

转换器未输出这 4 个字段 → 全库 16/8/16/16 处打造系统相关数据被静默丢弃。
本批回填到 `items` 块内部的 `meta` 块，与 `value`/`weight`/`unit` 等并列。

Item.Meta 得到 4 个新字段（均默认 nil），由 `loader.ex parse_item_meta/1` 从 `meta` 块读取。
暂无消费端（Q3 ❌，打造系统是 P3 子系统），字段先加、loader 只读取，不产生行为变化（P7）。

哪些块被写
----------
只有 `items` 块（这是物品属性）。`characters` 块 0 个。

值处理
------
- `can_make` / `not_make`：字符串列表。单字符串 `"all"` 写成 `["all"]`；
  列表 `({ "战衣", "腰带" })` 写成 `["战衣", "腰带"]`（双引号，逗号分隔）。
- `power_point` / `item_origin`：整数，原样写入 `power_point = 200`。
  注释行 `//set("power_point", 120)` 跳过。

安全（同 B3/B5b/B6/B8 协议）
----------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：先把所有区的改动在内存里算完并过门禁（insertion-only +
  validate_ucl 完整 issue 集合比对、行号归一化），**全过**才备份、才写盘
* 备份写盘 **之前** 完成
* 幂等：已携带对应 key 的块跳过
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

KEYS = ("can_make", "not_make", "power_point", "item_origin")

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')

# meta = { ... } 行（6 空缩进，与 name/description 同级）
META_OPEN = re.compile(r'^\s{6}meta\s*=\s*\{\s*$')

# set("key", ...) 调用（先按行去注释再匹配）
SET_RE = re.compile(r'set\s*\(\s*"(%s)"\s*,' % "|".join(KEYS))


def norm(path):
    return path.replace("\\", "/").lower()


def strip_line_comment(line):
    """去掉 LPC 行内 `//` 注释（保留字符串内的 //，此处简单处理足够）。"""
    # 简单策略：找到不在字符串内的第一个 //，截断
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
    """Yield (kind, key, source, open_idx, close_idx) per block.

    Source attribution: block-internal `# LPC: <path>` wins over the
    nearest `# Generated from` header.
    """
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
    """Within items block [start+1, close-1], find `meta = { ... }` sub-block.

    Returns (meta_open_idx, meta_close_idx) or (None, None) if absent.
    """
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


def extract_str_list(src, key):
    """Extract can_make/not_make value as list of strings.

    Handles:
      set("can_make", "all")              -> ["all"]
      set("can_make", ({ "战衣", "腰带" })) -> ["战衣", "腰带"]
    Skips commented-out lines.
    """
    pat = re.compile(r'set\s*\(\s*"%s"\s*,\s*' % re.escape(key))
    results = []
    for line in src.split("\n"):
        clean = strip_line_comment(line)
        m = pat.search(clean)
        if not m:
            continue
        after = clean[m.end():]
        after = after.lstrip()
        if not after:
            continue
        if after[0] == '"':
            # single string value: "all"
            end = after.find('"', 1)
            if end == -1:
                continue
            results.append(after[1:end])
        elif after[0] == "(":
            # list: ({ "a", "b" }) — find matching close paren
            depth = 0
            in_str = False
            end = -1
            for i, c in enumerate(after):
                if in_str:
                    if c == "\\":
                        i += 1
                        continue
                    if c == '"':
                        in_str = False
                else:
                    if c == '"':
                        in_str = True
                    elif c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                        if depth == 0:
                            end = i
                            break
            if end == -1:
                continue
            inner = after[1:end]
            # extract quoted strings
            strs = []
            in_str = False
            buf = []
            i = 0
            while i < len(inner):
                c = inner[i]
                if in_str:
                    if c == "\\":
                        buf.append(c)
                        i += 1
                        if i < len(inner):
                            buf.append(inner[i])
                        i += 1
                        continue
                    if c == '"':
                        strs.append("".join(buf))
                        buf = []
                        in_str = False
                    else:
                        buf.append(c)
                else:
                    if c == '"':
                        in_str = True
                        buf = []
                i += 1
            results.extend(strs)
    return results


def extract_int(src, key):
    """Extract power_point/item_origin integer value, skipping commented lines."""
    pat = re.compile(r'set\s*\(\s*"%s"\s*,\s*' % re.escape(key))
    for line in src.split("\n"):
        clean = strip_line_comment(line)
        m = pat.search(clean)
        if not m:
            continue
        after = clean[m.end():].lstrip()
        m2 = re.match(r"(-?\d+)", after)
        if m2:
            return int(m2.group(1))
    return None


def collect_sources():
    """Return dict: source_path -> {key: value} for keys present in file."""
    found = {}
    for root, _dirs, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                src = fh.read()
            vals = {}
            for key in KEYS:
                if key in ("can_make", "not_make"):
                    strs = extract_str_list(src, key)
                    if strs:
                        vals[key] = strs
                else:
                    v = extract_int(src, key)
                    if v is not None:
                        vals[key] = v
            if vals:
                found[norm(path)] = vals
    return found


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
    total_src = sum(1 for v in sources.values() if v)
    key_counts = {k: 0 for k in KEYS}
    for v in sources.values():
        for k in KEYS:
            if k in v:
                key_counts[k] += 1
    print("source files with any B9 key: %d" % len(sources))
    print("  key counts: %s" % key_counts)

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
            vals = sources[src]
            body = "\n".join(lines[_start + 1:close])
            # skip if all present keys already exist in block
            if all(re.search(r"^\s{8}%s\s*=" % re.escape(k), body, re.M) for k in vals):
                stats["blocks_skipped"] += 1
                continue

            meta_open, meta_close = find_meta_block(lines, _start, close)
            if meta_open is None:
                stats["blocks_no_meta"] += 1
                continue

            block_lines = []
            for k in KEYS:
                if k not in vals:
                    continue
                v = vals[k]
                if k in ("can_make", "not_make"):
                    quoted = ", ".join('"%s"' % _sanitize_ucl_str(s) for s in v)
                    block_lines.append("        %s = [%s]" % (k, quoted))
                else:
                    block_lines.append("        %s = %d" % (k, v))

            if block_lines:
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
        print("  %-18s +%-4d lines  (%d blocks)"
              % (fn, delta, len(insertions)))

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
