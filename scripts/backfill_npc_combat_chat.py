#!/usr/bin/env python
"""B6: backfill LPC `chat_chance_combat`/`chat_msg_combat` into NPC characters blocks.

LPC semantics
-------------
`set("chat_chance_combat", N)` — probability (0-100) of NPC speaking during combat.
`set("chat_msg_combat", ({...}))` — message pool spoken during combat.

The converter `build_chat/1` (lpc_converter.ex L3175) only handles `chat_chance`/
`chat_msg` (idle chat), NOT `*_combat` → 全库 456 处战斗聊天被静默丢弃
(UCL 里 0 条)。本批把它们回填到 `characters` 块的顶层字段，与已有的
`chat_chance`/`chats`（闲聊）并列。

NonPlayerMeta 得到 `:chat_msg_combat` (list, default []) 和
`:chat_chance_combat` (integer, default 0)，由 `loader.ex parse_character/4`
从顶层 `character_data` 读取（同 `goods`/`inquiries`/`teach` 等字段）。

哪些块被写
----------
只有 `characters` 块（全部来自 NPC，456 个源 → 122 块 / 29 区）。
`items` 块 0 个（战斗聊天是 NPC 属性）。

值处理
------
- `chat_chance_combat`：整数，原样写入。
- `chat_msg_combat`：列表，只保留字符串条目（closure `(: perform_action, ... :)`
  跳过，与转换器 build_chat/1 的 `_ -> []` 行为一致），每条经过
  `process_lpc_escapes` + `$N`→`{npc}`/`$n`→`{name}` + `sanitize_ucl_sval` 归一化。

安全（同 B3/B5b 协议）
----------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：先把所有区的改动在内存里算完并过门禁（insertion-only +
  validate_ucl 完整 issue 集合比对、行号归一化），**全过**才备份、才写盘
* 备份写盘 **之前** 完成
* 幂等：已携带 `chat_chance_combat` 的块跳过
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

CHANCE_KEY = "chat_chance_combat"
MSG_KEY = "chat_msg_combat"

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')

CHANCE_DECL = re.compile(r'set\s*\(\s*"%s"\s*,\s*([^;)]+)' % CHANCE_KEY)
MSG_DECL = re.compile(r'set\s*\(\s*"%s"\s*,' % MSG_KEY)


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


def collect_sources():
    """Return dict: source_path -> {chat_chance_combat: int|None,
    chat_msg_combat_raw: [raw_strings]}"""
    found = {}
    for root, _, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                src = fh.read()
            if not (CHANCE_DECL.search(src) or MSG_DECL.search(src)):
                continue
            chance = _extract_int(src, CHANCE_DECL)
            msgs_raw = _extract_msg_strings(src)
            found[norm(path)] = {
                "chat_chance_combat": chance,
                "chat_msg_combat_raw": msgs_raw,
            }
    return found


def _extract_int(src, pattern):
    m = pattern.search(src)
    if not m:
        return None
    try:
        return int(m.group(1).strip())
    except ValueError:
        return None


def _extract_msg_strings(src):
    """Extract string entries from set("chat_msg_combat", (...)).

    Closures `(: ... :)` are skipped (matching converter's `_ -> []`).
    """
    m = MSG_DECL.search(src)
    if not m:
        return []
    i = m.end()
    while i < len(src) and src[i] in " \t\n\r":
        i += 1
    if i >= len(src) or src[i] != "(":
        return []
    depth = 0
    in_str = False
    start = i
    end = None
    while i < len(src):
        c = src[i]
        if in_str:
            if c == "\\":
                i += 2
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
        i += 1
    if end is None:
        return []
    array_text = src[start:end]

    strings = []
    in_str = False
    buf = []
    i = 0
    while i < len(array_text):
        c = array_text[i]
        if in_str:
            if c == "\\":
                buf.append(c)
                i += 1
                if i < len(array_text):
                    buf.append(array_text[i])
                i += 1
                continue
            if c == '"':
                strings.append("".join(buf))
                buf = []
                in_str = False
            else:
                buf.append(c)
        else:
            if c == '"':
                in_str = True
                buf = []
        i += 1
    return strings


def _process_lpc_escapes(s):
    s = s.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    s = s.replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\")
    return s


def _sanitize_ucl_sval(s):
    s = s.replace("\\\\\\\\", "\\\\").replace("\\\\", "\\")
    s = s.replace('\\"', "'").replace('"', "'")
    s = s.replace(";", " ")
    s = s.replace("\n", " ").replace("\r", " ")
    return s.strip()


def _normalize_msg(raw):
    """Mirror converter: process_lpc_escapes -> $N/$n -> sanitize_ucl_sval."""
    s = _process_lpc_escapes(raw)
    s = s.replace("$N", "{npc}").replace("$n", "{name}")
    return _sanitize_ucl_sval(s)


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


def _norm_issues(issues):
    return {(n, re.sub(r"line \d+", "line N", m or "")) for n, m in issues}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    sources = collect_sources()
    print("source files declaring combat chat: %d" % len(sources))
    n_with_msg = sum(1 for v in sources.values() if v["chat_msg_combat_raw"])
    n_with_chance = sum(1 for v in sources.values() if v["chat_chance_combat"] is not None)
    print("  with chat_msg_combat strings: %d" % n_with_msg)
    print("  with chat_chance_combat: %d" % n_with_chance)

    planned = []
    stats = {
        "zones": 0,
        "blocks_written": 0,
        "blocks_skipped": 0,
        "inserted_lines": 0,
    }
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            orig = fh.read()
        lines = orig.split("\n")

        insertions = []  # (close_idx, [lines to insert])
        for kind, key, src, _start, close in iter_blocks(lines):
            if kind != "characters" or src not in sources:
                continue
            body = "\n".join(lines[_start + 1:close])
            if re.search(r"^\s*(?:%s|%s)\s*=" % (CHANCE_KEY, MSG_KEY), body, re.M):
                stats["blocks_skipped"] += 1
                continue

            data = sources[src]
            chance = data["chat_chance_combat"]
            msgs_raw = data["chat_msg_combat_raw"]
            msgs = [_normalize_msg(m) for m in msgs_raw]
            msgs = [m for m in msgs if m]  # drop empty after sanitize

            block_lines = []
            if chance is not None:
                block_lines.append("  chat_chance_combat = %d" % chance)
            if msgs:
                # double-quoted list (matches existing `chats = [...]` convention;
                # single-quoted `[ '...'` trips the validator's Python-repr check)
                quoted = ", ".join('"%s"' % m for m in msgs)
                block_lines.append("  chat_msg_combat = [%s]" % quoted)

            if block_lines:
                insertions.append((close, block_lines))

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

    print(json.dumps(stats, ensure_ascii=False))

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


if __name__ == "__main__":
    sys.exit(main())
