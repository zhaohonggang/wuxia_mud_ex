#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P1b: backfill L1 fields (loader-whitelisted) into data/world/*.ucl.

Reads `tmp/key_field_map.json` (produced by plan_key_field_map.py) and, for the
selected L1 keys, writes the *real* value taken from the LPC source back into
the matching UCL block.

Hard rules from the plan (docs/data-world-comments-continuation-plan.zh-CN.md §0):
  P4  only ADD missing keys; never touch an existing line.  Idempotent: a second
      run must report 0 changes.
  P5  dry-run by default; `--apply` writes; **every written file is copied to
      tmp/backup-<timestamp>/ BEFORE it is modified**.
  P2  never calls the converter; never rewrites a whole file.
  P6  never touches *.comments.txt.

Implemented targets (this version):
  room.flags   -> a `flags = [ ... ]` block inside `rooms "<key>" { ... }`.
                  Room whitelist includes `flags`; loader.ex L428 parse_flags/1.
                  Output format matches the hand-written precedent
                  (data/world/city.ucl `yangzhou_shop`):
                      flags = [
                        "no_fight"
                      ]
                  The converter itself never emits flags
                  (`_build_room_flags` returns [] unconditionally), so there is
                  no generated-format to match.

Any other target is reported as "unsupported" and left alone (not guessed).

Usage:
    python scripts/backfill_l1_fields.py                     # dry-run, all L1 keys
    python scripts/backfill_l1_fields.py --keys=sleep_room,no_sleep_room
    python scripts/backfill_l1_fields.py --keys=sleep_room --apply
"""
import os
import re
import sys
import json
import time
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
TMP = os.path.join(ROOT, "tmp")
CORPUS = r"C:\files\git\mud\d"

# Same exclusions as item_meta_backfill.py: test fixtures / converter corpus /
# hand-maintained zones are out of scope.
EXCLUDED = {"test", "global", "liuxi", "kissa-jarvi", "lepakko-luola",
            "sammatti", "signature"}

# LPC key -> the flag NAME written into room.flags, when they differ.
#   valid_startroom  marks the room players start/recall to; the engine looks for
#   the flag "startroom" (home_command.ex L54, recall_command.ex L50).
FLAG_NAME = {
    "valid_startroom": "startroom",
}

ROOM_INHERIT = re.compile(r"^\s*inherit\s+[^\n]*ROOM", re.M | re.I)
GEN_RE = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
ROOMS_OPEN_RE = re.compile(r'^(\s*)rooms\s+"([^"]+)"\s*\{\s*$')

# Self-check gate: reuse the project's own validator so a bad insertion can never
# reach disk.  (The first version of this script emitted two newline-separated
# flags with no comma; elias rejects that, and the whole batch had to be
# reverted.  See scripts/probe_elias_expressibility.exs.)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import validate_ucl as _vucl
except Exception:  # pragma: no cover - validator is optional
    _vucl = None


def validation_regressions(orig_text, new_text):
    """Check names that FAIL on new_text but did not fail on orig_text."""
    if _vucl is None:
        return []
    orig = {n for n, _ in _vucl._run_checks(orig_text.encode("utf-8"))}
    new = {n for n, _ in _vucl._run_checks(new_text.encode("utf-8"))}
    return sorted(new - orig)


def set_value_re(key):
    """Match `set("<key>", <value>)`; group 1 = the raw value token."""
    return re.compile(r'\bset\s*\(\s*"%s"\s*,\s*("?[^,)]*"?)\s*\)' % re.escape(key))


def is_truthy(v):
    v = (v or "").strip().strip('"').strip()
    return v not in ("", "0")


def skeleton(line):
    """Blank out string contents and trailing comments -> structural chars only."""
    out = []
    in_str = False
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if not in_str and c == '#':
            break
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            out.append(' ')
        else:
            if c == '"':
                in_str = True
                out.append(' ')
            else:
                out.append(c)
        i += 1
    return ''.join(out)


def delta(line):
    s = skeleton(line)
    return s.count('{') - s.count('}')


def collect_flags(keys):
    """{source_path_lower: set(flag_name)} for room-kind files setting `key` truthy."""
    want = {}
    for key in keys:
        rx = set_value_re(key)
        flag = FLAG_NAME.get(key, key)
        for zone in sorted(os.listdir(CORPUS)):
            zdir = os.path.join(CORPUS, zone)
            if not os.path.isdir(zdir):
                continue
            for root, _, files in os.walk(zdir):
                for fn in files:
                    if not fn.endswith(".c"):
                        continue
                    p = os.path.join(root, fn)
                    try:
                        with open(p, encoding="gbk", errors="replace") as fh:
                            src = fh.read()
                    except Exception:
                        continue
                    if not ROOM_INHERIT.search(src):
                        continue
                    if any(is_truthy(m.group(1)) for m in rx.finditer(src)):
                        want.setdefault(p.replace("\\", "/").lower(), set()).add(flag)
    return want


def process_file(path, want):
    """Return (stats, new_content_or_None).  Never writes."""
    raw = open(path, encoding="utf-8").read()
    lines = raw.split("\n")

    blocks = []          # (open_i, close_i, indent, key, src_path)
    depth = 0
    pending = None
    last_src = None
    for i, line in enumerate(lines):
        m = GEN_RE.match(line.strip())
        if m and depth == 0:
            last_src = m.group(1).replace("\\", "/").lower()
        opens = depth == 0 and ROOMS_OPEN_RE.match(line)
        if opens:
            om = ROOMS_OPEN_RE.match(line)
            pending = (i, om.group(1), om.group(2), last_src)
        nxt = depth + delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            s, ind, key, src = pending
            blocks.append((s, i, ind, key, src))
            pending = None
        depth = nxt

    stats = {"blocks": len(blocks), "target": 0, "filled": 0, "already": 0}
    fills = {}

    for start, close, indent, key, src in blocks:
        if src is None or src not in want:
            continue
        stats["target"] += 1
        body = lines[start + 1:close]
        # Any indentation counts: hand-written blocks put `flags` at 2 spaces
        # while `name` sits at 6, so a fixed indent would miss it.
        if any(l.strip().startswith("flags") for l in body):
            stats["already"] += 1
            continue
        flags = sorted(want[src])
        # Match the hand-written precedent: `flags` at 2 spaces, entries at 4.
        # Separator MUST be a comma: elias rejects two newline-separated items
        # with no comma ("syntax error before: '\"'").  A single item needs no
        # separator, which is why the one hand-written precedent (city.ucl
        # `yangzhou_shop`) parses fine and this looked deceptively safe.
        # Verified with scripts/probe_elias_expressibility.exs.
        ins = ["  flags = ["]
        ins += [
            '    "%s"%s' % (f, "," if i < len(flags) - 1 else "")
            for i, f in enumerate(flags)
        ]
        ins.append("  ]")
        fills[close] = ins
        stats["filled"] += 1

    if not fills:
        return stats, None

    out = []
    for i, line in enumerate(lines):
        if i in fills:
            out.extend(fills[i])
        out.append(line)

    # P4 safety: the old content must be an exact subsequence of the new one
    # (nothing deleted or modified, only lines inserted).
    if not is_insertion_only(lines, out):
        raise RuntimeError("refusing to write %s: not an insertion-only change" % path)

    new_text = "\n".join(out)

    # Hard gate: never write a file whose validation got worse than it was.
    reg = validation_regressions(raw, new_text)
    if reg:
        raise RuntimeError(
            "refusing to write %s: new validation failures %s" % (path, reg))

    return stats, new_text


def is_insertion_only(old_lines, new_lines):
    """True if old_lines appears in new_lines in order (nothing removed/edited)."""
    it = iter(new_lines)
    return all(any(n == o for n in it) for o in old_lines)


def main():
    apply_ = "--apply" in sys.argv
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--keys="):
            only = set(a.split("=", 1)[1].split(","))

    with open(os.path.join(TMP, "key_field_map.json"), encoding="utf-8") as fh:
        mapping = json.load(fh)

    l1 = [r for r in mapping if r["decision"] == "L1"]
    if only:
        l1 = [r for r in l1 if r["key"] in only]
    if not l1:
        print("no L1 keys selected")
        return

    room_keys = [r["key"] for r in l1 if r["target"] == "room.flags"]
    unsupported = [r for r in l1 if r["target"] != "room.flags"]

    print("L1 keys selected : %s" % ", ".join(r["key"] for r in l1))
    print("  -> room.flags  : %s" % (", ".join(room_keys) or "-"))
    for r in unsupported:
        print("  -> SKIPPED (target %s not implemented yet): %s"
              % (r["target"], r["key"]))
    print()

    want = collect_flags(room_keys) if room_keys else {}
    print("source rooms setting these flags: %d" % len(want))

    # ---- phase 1: compute everything, write nothing ------------------------
    total = {"blocks": 0, "target": 0, "filled": 0, "already": 0}
    pending = {}          # path -> new content
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue
        path = os.path.join(WORLD, fn)
        stats, new = process_file(path, want)
        for k in total:
            total[k] += stats[k]
        if new is not None:
            pending[path] = new
            print("[%s] %s: +%d 个 flags 块（命中房间 %d，已有 flags %d）"
                  % ("apply" if apply_ else "dry", z, stats["filled"],
                     stats["target"], stats["already"]))

    print()
    print("=== 汇总 ===")
    print(json.dumps(total, ensure_ascii=False))
    print("改动区数: %d" % len(pending))

    if not apply_:
        print("(dry-run，未写入；加 --apply 生效)")
        return

    if not pending:
        print("无改动，跳过备份与写入。")
        return

    # ---- phase 2: BACKUP FIRST, then write (plan §5 / P5) ------------------
    ts = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(TMP, "backup-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    for path in pending:
        shutil.copy2(path, os.path.join(bdir, os.path.basename(path)))
    print("已备份 %d 个文件到 %s（**写盘之前**）" % (len(pending), os.path.relpath(bdir, ROOT)))

    for path, new in pending.items():
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("已写入 %d 个文件。" % len(pending))


if __name__ == "__main__":
    main()
