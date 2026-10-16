#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B5b: backfill equipment messages (wear/remove/unequip) into item `messages` blocks.

Why this is L1 (pure data), not L2:
  B5a already added `Item.Meta.messages` and made `loader.ex parse_item/4` read the
  item-level `messages = { ... }` map.  So the *channel exists*; we only need to put
  the missing keys into it.  No struct / loader change is required here.

Source of truth: the LPC corpus (`C:\\files\\git\\mud`), NOT the sidecar.
  LPC                       -> UCL key inside `messages = { ... }`
  set("wear_msg",    "...") -> wear
  set("remove_msg",  "...") -> remove
  set("unequip_msg", "...") -> unequip
  (wield/unwield are already emitted by the converter itself; see B5a.)

Value normalisation mirrors the converter exactly (lpc_converter.ex):
  * extract every "..." segment (respecting \\" escapes)  -- extract_strings_from_macro_wrapped/1
  * process_lpc_escapes/1  (\\n \\t \\r \\" \\' \\\\)
  * "$N" -> "{npc}", "$n" -> "{name}"                     -- process_literal_string/1
  * sanitize_ucl_sval/1    (" -> ', ; -> space, newline -> space, trim)
  * plus one B5b-only repair: [ ] -> ( ) (elias rejects square brackets inside a
    quoted value; verified with scripts/probe_ucl_brackets.exs)
Only *literal* expressions (plain / macro-wrapped / concatenated literals) are
converted; closures `(: do_wear :)` and any expression containing a non-macro
identifier are skipped and reported (they are dynamic, not data).

SCOPE / D10:
  Only `items` blocks are written -- that is where the loader reads `messages`.
  Items that the converter wrongly emitted as `characters` blocks (npc/obj/*.c that
  inherit a weapon/armor macro) are counted and reported, but NOT written: the
  loader never reads `messages` from a `characters` block, so the write would be
  inert.  See the plan's D10.

Hard rules (plan §0):
  P4  only ADD missing keys; never touch an existing line.  Idempotent.
  P5  dry-run by default; `--apply` writes; every written file is copied to
      tmp/backup-<timestamp>/ BEFORE it is modified.
  P2  never calls the converter; never rewrites a whole file.
  P6  never touches *.comments.txt.

Usage:
    python scripts/backfill_item_messages.py                 # dry-run
    python scripts/backfill_item_messages.py --apply         # write + backup
"""
import os
import re
import sys
import time
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
TMP = os.path.join(ROOT, "tmp")
CORPUS = r"C:\files\git\mud"

EXCLUDED = {"test", "global", "liuxi", "kissa-jarvi", "lepakko-luola",
            "sammatti", "signature"}

# LPC set() key -> key written inside the UCL `messages = { ... }` map.
MSG_KEYS = {"wear_msg": "wear", "remove_msg": "remove", "unequip_msg": "unequip"}

GEN_RE = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
OPEN_RE = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')
MESSAGES_OPEN_RE = re.compile(r'^\s*messages\s*=\s*\{\s*$')
KEY_LINE_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=')

MACRO_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")

# Self-check gate: reuse the project validator so a bad insertion cannot reach disk.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import validate_ucl as _vucl
except Exception:  # pragma: no cover
    _vucl = None


def validation_regressions(orig_text, new_text):
    """Issues present in new_text but not in orig_text.

    Compare (check, message) pairs, not just check names: a zone that already
    fails with e.g. "Chars" would otherwise silently accept an ADDITIONAL Chars
    problem.  Line numbers shift when we insert, so they are normalised away.
    """
    if _vucl is None:
        return []

    def norm(data):
        out = set()
        for name, msg in _vucl._run_checks(data.encode("utf-8")):
            out.add((name, re.sub(r"line \d+", "line N", msg)))
        return out

    return sorted(norm(new_text) - norm(orig_text))


# --------------------------------------------------------------------------- #
# source side: read the corpus and normalise the 3 message keys
# --------------------------------------------------------------------------- #
def read_src(path):
    """Corpus is UTF-8 (verified: 0/11097 non-UTF-8); keep a gbk fallback."""
    raw = open(path, "rb").read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("gbk", errors="replace")


def find_set_value(src, key):
    """Return the raw expression of `set("<key>", <expr>)`, paren-balanced."""
    i = 0
    needle = re.compile(r'set\s*\(\s*"%s"\s*,' % re.escape(key))
    while True:
        m = needle.search(src, i)
        if not m:
            return None
        j = m.end()
        depth = 1  # we are inside set(
        ins = False
        while j < len(src):
            c = src[j]
            if ins:
                if c == "\\":
                    j += 2
                    continue
                if c == '"':
                    ins = False
            else:
                if c == '"':
                    ins = True
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        return src[m.end():j].strip()
            j += 1
        return None


def process_lpc_escapes(s):
    return (s.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
             .replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\"))


def sanitize_ucl_sval(s):
    s = s.replace("\\" * 4, "\\" * 2).replace("\\" * 2, "\\")
    s = s.replace('\\"', "'").replace('"', "'")
    s = s.replace(";", " ")
    s = s.replace("\n", " ").replace("\r", " ")
    # elias rejects `[` / `]` inside a quoted value ("syntax error before: '['");
    # `(` / `)` lex fine (the whole existing world uses them, e.g. "(pen)").
    # Verified with scripts/probe_ucl_brackets.exs.
    s = s.replace("[", "(").replace("]", ")")
    return s.strip()


def normalize(expr):
    """(value, reason).  value is None when the expression is not static data."""
    if expr is None:
        return None, "absent"
    e = expr.strip()
    if e.startswith("(:"):
        return None, "closure"
    segs = re.findall(r'"((?:\\.|[^"\\])*)"', e)
    if not segs:
        return None, "no-literal"
    rest = re.sub(r'"((?:\\.|[^"\\])*)"', " ", e).replace("+", " ")
    for tok in rest.split():
        if not MACRO_RE.match(tok):
            return None, "dynamic:" + tok[:24]
    s = "".join(process_lpc_escapes(seg) for seg in segs)
    s = s.replace("$N", "{npc}").replace("$n", "{name}").strip()
    s = sanitize_ucl_sval(s)
    if not s:
        return None, "empty"
    # elias rejects two ASCII-comma forms inside a quoted value
    # (probe_ucl_brackets.exs): a comma followed by whitespace, and a digit
    # immediately before a comma.  Neither occurs in the current corpus; guard
    # anyway so a future value can never reach disk malformed.
    if re.search(r",\s", s) or re.search(r"[0-9],", s):
        return None, "comma-unsafe"
    return s, None


def collect():
    """{src_path_lower: {ucl_key: value}} plus a skipped counter."""
    want, skipped = {}, {}
    for root, _, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            p = os.path.join(root, fn)
            src = read_src(p)
            got = {}
            for lpc_key, ucl_key in MSG_KEYS.items():
                expr = find_set_value(src, lpc_key)
                if expr is None:
                    continue
                val, reason = normalize(expr)
                if val is None:
                    skipped[reason] = skipped.get(reason, 0) + 1
                    continue
                got[ucl_key] = val
            if got:
                want[p.replace("\\", "/").lower()] = got
    return want, skipped


# --------------------------------------------------------------------------- #
# UCL side
# --------------------------------------------------------------------------- #
def skeleton(line):
    out, in_str, i = [], False, 0
    while i < len(line):
        c = line[i]
        if not in_str and c == "#":
            break
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
            out.append(" ")
        else:
            if c == '"':
                in_str = True
                out.append(" ")
            else:
                out.append(c)
        i += 1
    return "".join(out)


def delta(line):
    s = skeleton(line)
    return s.count("{") - s.count("}")


def find_blocks(lines):
    """[(open_i, close_i, kind, key, src)] for every items/characters block."""
    blocks, depth, pending, last_src = [], 0, None, None
    for i, line in enumerate(lines):
        m = GEN_RE.match(line.strip())
        if m and depth == 0:
            last_src = m.group(1).replace("\\", "/").lower()
        if depth == 0:
            om = OPEN_RE.match(line)
            if om:
                pending = (i, om.group(1), om.group(2), last_src)
        nxt = depth + delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            s, kind, key, src = pending
            blocks.append((s, i, kind, key, src))
            pending = None
        depth = nxt
    return blocks


def messages_block_range(lines, start, close):
    """(open_i, close_i) of the `messages = {` sub-block, or None."""
    for i in range(start + 1, close):
        if MESSAGES_OPEN_RE.match(lines[i]):
            depth = 0
            for j in range(i, close):
                depth += delta(lines[j])
                if depth == 0 and j > i:
                    return i, j
            return i, close
    return None


def process_file(path, want, stats):
    raw = open(path, encoding="utf-8").read()
    lines = raw.split("\n")
    fills = {}

    for start, close, kind, key, src in find_blocks(lines):
        if kind != "items" or src is None or src not in want:
            if kind == "characters" and src in want:
                stats["characters_block"] += 1
            continue
        stats["target"] += 1
        rng = messages_block_range(lines, start, close)
        existing = set()
        if rng:
            for j in range(rng[0] + 1, rng[1]):
                km = KEY_LINE_RE.match(lines[j])
                if km:
                    existing.add(km.group(1))

        add = [(k, v) for k, v in sorted(want[src].items()) if k not in existing]
        if not add:
            stats["already"] += 1
            continue

        if rng:
            # insert before the closing `}` of the existing messages block
            ins = ['    %s = "%s"' % (k, v) for k, v in add]
            fills.setdefault(rng[1], []).extend(ins)
        else:
            # create a new messages block just before the item block's `}`
            ins = ["  messages = {"]
            ins += ['    %s = "%s"' % (k, v) for k, v in add]
            ins.append("  }")
            fills.setdefault(close, []).extend(ins)
        stats["filled"] += 1

    if not fills:
        return None

    out = []
    for i, line in enumerate(lines):
        if i in fills:
            out.extend(fills[i])
        out.append(line)

    if not is_insertion_only(lines, out):
        raise RuntimeError("refusing to write %s: not insertion-only" % path)

    new_text = "\n".join(out)
    reg = validation_regressions(raw, new_text)
    if reg:
        raise RuntimeError("refusing to write %s: new validation failures %s" % (path, reg))
    return new_text


def is_insertion_only(old_lines, new_lines):
    it = iter(new_lines)
    return all(any(n == o for n in it) for o in old_lines)


def main():
    apply_ = "--apply" in sys.argv

    want, skipped = collect()
    print("corpus files with wear/remove/unequip messages : %d" % len(want))
    print("skipped (not static data)                      : %s"
          % (", ".join("%s=%d" % kv for kv in sorted(skipped.items())) or "-"))
    print()

    stats = {"target": 0, "filled": 0, "already": 0, "characters_block": 0}
    pending = {}
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        if fn[:-4] in EXCLUDED:
            continue
        path = os.path.join(WORLD, fn)
        new = process_file(path, want, stats)
        if new is not None:
            pending[path] = new
            print("[%s] %s" % ("apply" if apply_ else "dry", fn))

    print()
    print("=== 汇总 ===")
    print("命中 items 块            : %d" % stats["target"])
    print("已写入/待写入块          : %d" % stats["filled"])
    print("已有该键（幂等跳过）      : %d" % stats["already"])
    print("落在 characters 块（D10，不写）: %d" % stats["characters_block"])
    print("改动区数                 : %d" % len(pending))

    if not apply_:
        print("(dry-run，未写入；加 --apply 生效)")
        return
    if not pending:
        print("无改动，跳过备份与写入。")
        return

    ts = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(TMP, "backup-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    for path in pending:
        shutil.copy2(path, os.path.join(bdir, os.path.basename(path)))
    print("已备份 %d 个文件到 %s（**写盘之前**）"
          % (len(pending), os.path.relpath(bdir, ROOT)))

    for path, new in pending.items():
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("已写入 %d 个文件。" % len(pending))


if __name__ == "__main__":
    main()
