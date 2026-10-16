#!/usr/bin/env python
"""B3: backfill LPC `set("female_only", 1)` into item `meta`.

LPC semantics
-------------
`set("female_only", 1)` restricts the item so only female characters may
wear/wield it. The sole consumer in the source corpus is `cmds/std/wear.c`
L75. All 74 occurrences in the corpus use the literal value `1`, so this
backfill writes `female_only = 1` (matching the `no_sell = 1` convention
already present in data/world; `to_bool/1` in loader.ex accepts `true`,
`"true"`, `1` and `"1"`).

Why a new field and not `Item.Meta.flag`
----------------------------------------
`flag` is a **weapon-type bitmask** (LPC weapon.h: ONE_HANDED=0x1 ...
wield_command.ex L101 defaults to 1), consumed by combat as
`flag & TWO_HANDED`. Storing `female_only` there would corrupt weapon
classification.

Which blocks get written
------------------------
Only `items` blocks. A large share of the source files that declare
`female_only` (`npc/obj/*.c` -- dresses, skirts, flowers) were emitted by the
converter as `characters` blocks instead, so the loader never even looks at
them; writing there would be dead data. See R7 / D10.

Safety (same protocol as backfill_l1_fields.py / backfill_item_messages.py)
--------------------------------------------------------------------------
* dry-run by default, `--apply` to write
* backup of every touched file written to tmp/ **before** the first write
* insertion-only assertion on the produced text
* `validate_ucl._run_checks` self-gate: full (check, message) set with line
  numbers normalised, so pre-existing issues don't mask a genuinely new one
* idempotent: blocks already carrying `female_only` are skipped
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

KEY = "female_only"
VALUE = "1"

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')
META_OPEN = re.compile(r"^\s*meta\s*=\s*\{\s*$")
DECL = re.compile(r'set\s*\(\s*"%s"\s*,' % KEY)

try:
    import validate_ucl as _vucl
except Exception:  # pragma: no cover - validator is optional
    _vucl = None


def norm(path):
    return path.replace("\\", "/").lower()


def skeleton_delta(line):
    """Net brace count for one line, ignoring comments and string bodies.

    Getting this wrong would mis-detect block boundaries and could insert a
    key outside the intended `meta = { ... }` block.
    """
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


def collect():
    """Return the set of corpus source paths that declare female_only."""
    found = set()
    for root, _, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as fh:
                if DECL.search(fh.read()):
                    found.add(norm(path))
    return found


def iter_blocks(lines):
    """Yield (kind, key, source, open_idx, close_idx, meta_open, meta_close).

    Source attribution: the nearest preceding `# Generated from` header, but a
    `# LPC: <path>` comment *inside* the block wins for the block's own key
    set. The comment sits inside the block (depth >= 1), so it has to be
    resolved retrospectively while scanning the block body -- resolving it
    from the depth-0 preamble silently mis-attributes blocks that follow a
    different file's header.
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
            meta_open = meta_close = None
            for j in range(start + 1, i):
                if META_OPEN.match(lines[j]):
                    meta_open = j
                    d = 0
                    for k in range(j, i + 1):
                        d += skeleton_delta(lines[k])
                        if k > j and d == 0:
                            meta_close = k
                            break
                    break
                lm = LPC.match(lines[j].strip())
                if lm and resolved in (None, header):
                    resolved = norm(lm.group(1))
            yield kind, key, resolved, start, i, meta_open, meta_close
            pending = None
        depth = nxt


def process_text(text, want):
    """Return (new_text, n_inserted, skipped) without touching the filesystem."""
    lines = text.split("\n")
    insertions = []  # (meta_close_index, line_text)
    skipped = []
    for kind, key, src, _start, close, meta_open, meta_close in iter_blocks(lines):
        if kind != "items" or src not in want:
            continue
        if any(re.match(r"^\s*%s\s*=" % KEY, x) for x in lines[_start + 1:close]):
            skipped.append("%s (already)" % key)
            continue
        if meta_close is None:
            skipped.append("%s (no meta block)" % key)
            continue
        indent = " " * (len(lines[meta_open]) - len(lines[meta_open].lstrip()) + 2)
        insertions.append((meta_close, "%s%s = %s" % (indent, KEY, VALUE)))

    # insert from the bottom up so earlier indices stay valid
    for idx, txt in sorted(insertions, key=lambda x: -x[0]):
        lines.insert(idx, txt)

    return "\n".join(lines), len(insertions), skipped


def normalise_issues(issues):
    """Drop line numbers so brace insertions don't look like new problems."""
    out = set()
    for name, msg in issues:
        out.add((name, re.sub(r"line \d+", "line N", msg or "")))
    return out


def validation_regressions(orig_text, new_text):
    if _vucl is None:
        return []
    return sorted(
        normalise_issues(_vucl._run_checks(new_text.encode("utf-8")))
        - normalise_issues(_vucl._run_checks(orig_text.encode("utf-8")))
    )


def is_insertion_only(orig_text, new_text):
    a = orig_text.split("\n")
    b = new_text.split("\n")
    if len(b) <= len(a):
        return False, "line count did not grow"
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, _j1, _j2 in sm.get_opcodes():
        if tag in ("delete", "replace"):
            return False, "%s at orig line %d" % (tag, i1 + 1)
    return True, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    want = collect()
    print("source files declaring %s: %d" % (KEY, len(want)))

    # Phase 1: compute every change in memory and gate it. Nothing is written
    # until all files pass, so a failure late in the list cannot leave the
    # tree half-modified.
    planned = []
    stats = {
        "zones": 0,
        "blocks_written": 0,
        "blocks_skipped": 0,
        "characters_blocks": 0,
        "inserted_lines": 0,
    }
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            orig = fh.read()

        n_char = 0
        for kind, _key, src, *_ in iter_blocks(orig.split("\n")):
            if kind == "characters" and src in want:
                n_char += 1
        stats["characters_blocks"] += n_char

        new, n_ins, skipped = process_text(orig, want)
        if skipped:
            stats["blocks_skipped"] += len(skipped)
        if not n_ins:
            continue

        regressions = validation_regressions(orig, new)
        if regressions:
            print("  !! %s self-gate blocked: %s" % (fn, regressions[:3]))
            return 2
        ok, why = is_insertion_only(orig, new)
        if not ok:
            print("  !! %s is not insertion-only (%s) -- aborting" % (fn, why))
            return 2

        delta = len(new.split("\n")) - len(orig.split("\n"))
        stats["zones"] += 1
        stats["blocks_written"] += n_ins
        stats["inserted_lines"] += delta
        planned.append((path, new, delta, n_ins, skipped, n_char))
        print("  %-18s +%-4d lines  (%d blocks)  skipped=%s"
              % (fn, delta, n_ins, ",".join(skipped) if skipped else "-"))

    print(json.dumps(stats, ensure_ascii=False))

    if not args.apply:
        print("dry-run only; re-run with --apply to write")
        return 0
    if not planned:
        print("nothing to write")
        return 0

    # Phase 2: back up BEFORE the first write.
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = os.path.join(TMP, "backup-%s" % stamp)
    os.makedirs(backup, exist_ok=True)
    for path, *_ in planned:
        rel = os.path.relpath(path, WORLD)
        dst = os.path.join(backup, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)
    print("backed up %d files to %s" % (len(planned), backup))

    for path, new, *_ in planned:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("wrote %d files (+%d lines)" % (len(planned), stats["inserted_lines"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
