#!/usr/bin/env python
"""B8: backfill LPC `set("max_liquid", N)` into `items` blocks' `meta` block.

LPC semantics
-------------
`set("max_liquid", N)` — container/wine vessel max capacity (integer).

The converter never emitted `max_liquid` → 全库 82 处 LPC 源的容器容量被
静默丢弃（UCL 里 0 条）。本批把它们回填到 `items` 块内部的 `meta`
块，与 `value`/`weight`/`unit` 等并列。

Item.Meta 得到 `:max_liquid` (integer, default nil)，由 `loader.ex
parse_item_meta/1` 从 `meta` 块读取（同 `female_only`/`no_sell` 等）。

哪些块被写
----------
只有 `items` 块（max_liquid 是物品属性）。`characters` 块 0 个。

值处理
------
- `max_liquid`：整数，写入 `        max_liquid = N`（8 空缩进，与 meta 块
  内其它字段对齐）。

安全（同 B3/B5b/B6 协议）
----------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：先把所有区的改动在内存里算完并过门禁（insertion-only +
  validate_ucl 完整 issue 集合比对、行号归一化），**全过**才备份、才写盘
* 备份写盘 **之前** 完成
* 幂等：已携带 `max_liquid` 的块跳过
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

KEY = "max_liquid"

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')

# `meta = {` 行（6 空缩进，与 name/description 同级）
META_OPEN = re.compile(r'^\s{6}meta\s*=\s*\{\s*$')

SET_LIQUID = re.compile(r'set\s*\(\s*"max_liquid"\s*,\s*([^;)]+)')


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
            # brace-count to find matching close
            depth = 1
            j = i + 1
            while j < close:
                d = skeleton_delta(lines[j])
                depth += d
                if depth == 0:
                    return i, j
                j += 1
            return i, j - 1  # unmatched; treat rest of items block as meta
        i += 1
    return None, None


def collect_sources():
    """Return dict: source_path -> max_liquid (int|None)."""
    found = {}
    for root, _dirs, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                src = fh.read()
            if not SET_LIQUID.search(src):
                continue
            m = SET_LIQUID.search(src)
            try:
                val = int(m.group(1).strip())
            except ValueError:
                continue
            found[norm(path)] = val
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    sources = collect_sources()
    print("source files declaring max_liquid: %d" % len(sources))

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
            if re.search(r"^\s{8}max_liquid\s*=", body, re.M):
                stats["blocks_skipped"] += 1
                continue

            meta_open, meta_close = find_meta_block(lines, _start, close)
            if meta_open is None:
                stats["blocks_no_meta"] += 1
                continue

            val = sources[src]
            block_lines = ["        max_liquid = %d" % val]
            insertions.append((meta_close, block_lines))

        if not insertions:
            continue

        # build new text (insert bottom-up so indices stay valid)
        new_lines = list(lines)
        for close_idx, block_lines in sorted(insertions, key=lambda x: -x[0]):
            for line_text in reversed(block_lines):
                new_lines.insert(close_idx, line_text)
        new = "\n".join(new_lines)

        # gate: no new validation issues
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

    # Phase 2: backup BEFORE the first write.
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
