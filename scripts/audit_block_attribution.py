#!/usr/bin/env python
"""Size the D10 block-misclassification: how many `characters` blocks are
actually LPC *items* (weapons/armour/object macros) that the converter emitted
under the wrong block type?

Attribution rule (this is the part that was wrong in an earlier ad-hoc pass):
each block's true source is the *nearest preceding* `# LPC: <path>` comment at
depth 0, falling back to the nearest preceding `# Generated from <path>` header.
Using the header alone mis-attributes blocks that the converter emits after a
different file's header (e.g. `characters "mangshe"` follows the zhulou.c
header but carries `# LPC: clone/beast/mangshe.c`).
"""
import os
import re
import sys
from collections import Counter

CORPUS = r"C:\files\git\mud"
WORLD = r"data\world"

INHERIT = re.compile(r"^\s*inherit\s+([^\n;]*)", re.M)
# item-flavoured base classes / macros
ITEMISH = re.compile(
    r"\b(ITEM|OBJECT|WEAPON|SWORD|BLADE|STAFF|FIST|UNARMED|FINGER|CLAW|PALM|"
    r"STRIKE|HAMMER|AXE|DAGGER|THROWING|WHIP|BIAN|GUN|ARMOR|CLOTH|COMBINED|"
    r"MONEY|BOOK|FOOD|LIQUID|LATEX|CLONE)\b",
    re.I,
)
NPCISH = re.compile(
    r"\b(NPC|CHAR|MONSTER|F_SKILL|HUMAN|BOSS|BEAST|SNAKE|WARRIOR)\b", re.I
)

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPCC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^\s*(items|characters)\s+"([^"]+)"\s*\{\s*$')

_KIND_CACHE = {}


def skeleton_delta(line):
    """Count { } while ignoring comments and the contents of strings."""
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


def norm(p):
    return p.replace("\\", "/").lower()


def kind_of(path):
    if path in _KIND_CACHE:
        return _KIND_CACHE[path]
    kind = "missing"
    if path and os.path.exists(path):
        src = open(path, encoding="utf-8", errors="replace").read()
        inh = " ".join(INHERIT.findall(src))
        if NPCISH.search(inh):
            kind = "npc"
        elif ITEMISH.search(inh):
            kind = "item"
        else:
            kind = "unknown"
    _KIND_CACHE[path] = kind
    return kind


def scan(target_keys=None):
    """Walk every zone; yield (zone, key, block_kind, source_path) per block.

    target_keys: if given, only blocks whose source declares one of these
    LPC set() keys are yielded.
    """
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        lines = open(os.path.join(WORLD, fn), encoding="utf-8").read().split("\n")
        depth = 0
        pending = None
        header = None
        pending_src = None
        for i, line in enumerate(lines):
            s = line.strip()
            m = GEN.match(s)
            if m and depth == 0:
                header = norm(m.group(1))
                pending_src = None
            if depth == 0:
                om = OPEN.match(line)
                if om:
                    pending = (om.group(1), om.group(2), pending_src or header, i)
                    pending_src = None  # consumed by the first block after it
            nxt = depth + skeleton_delta(line)
            if pending is not None and depth != 0 and nxt == 0:
                kind, key, src, start = pending
                resolved = src
                # `# LPC: <path>` normally sits *inside* the block, so the
                # depth-0 preamble never sees it -- resolve it retrospectively.
                for j in range(start + 1, i):
                    lm = LPCC.match(lines[j].strip())
                    if lm:
                        resolved = norm(lm.group(1))
                        break
                if target_keys is None or resolved in target_keys:
                    yield fn, key, kind, resolved
                pending = None
            depth = nxt


def main():
    c = Counter()
    examples = []
    for fn, key, kind, src in scan():
        if kind != "characters":
            continue
        k = kind_of(src)
        c[k] += 1
        if k == "item" and len(examples) < 12:
            examples.append((fn, key, src))
    print("characters blocks by CORRECTED source kind: %s" % dict(c))
    print("\nexamples of true item-in-characters:")
    for e in examples:
        print("   ", e)


if __name__ == "__main__":
    sys.exit(main())
