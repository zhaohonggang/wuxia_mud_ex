#!/usr/bin/env python3
"""
P1 backfill: for the SIMPLE static-pool NPCs (from classify_greeting_complexity),
extract greeting() say-lines / init() add_action verbs from the LPC .c source and
insert `greetings = [...]` / merge `init.add_actions` into the UCL block.

Dry-run by default (prints what WOULD be written). Pass --apply to edit UCL.
Idempotent: skips a block that already has greetings / init.
RANK_D->query_respect(...) -> {respect}; trailing \\n stripped; string concatenation joined.
"""
import os
import re
import sys

import classify_greeting_complexity as C
import reconcile_init_greeting_backlog as R

DATA_WORLD = os.path.join(os.path.dirname(__file__), "..", "data", "world")

# (zone, id, type) for the SIMPLE / POOL rows (from classify output)
SIMPLE = [
    ("beijing", "huiyingup", "init"),
    ("changan", "shuchi", "greeting"),
    ("kunlun", "lyj-book", "init"),
    ("lingxiao", "book-iron", "init"),
    ("mingjiao", "bag", "init"),
    ("shenlong", "caoping", "init"),
    ("tulong", "jiulou", "init"),
    ("wuguan", "guanjia1", "greeting"),
    ("wuguan", "guanjia2", "greeting"),
    ("wuguan", "guanjia3", "greeting"),
    ("wuguan", "guanjia5", "greeting"),
    ("wuguan", "guanjia6", "greeting"),
    ("wuguan", "wusantong", "greeting"),
    ("wuguan", "wuxiuwen", "greeting"),
    ("wuguan", "zhuziliu", "greeting"),
]

STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def lpc_strings(text):
    """Return list of raw string-literal contents in a chunk (handles \" escapes)."""
    return [m.group(1).replace('\\"', '"') for m in STR_RE.finditer(text)]


def extract_say_lines(body):
    """Extract spoken lines from a greeting() body: say("...") / command("say ...").
    Handles multi-line "a" + "b" concatenation and RANK_D->query_respect -> {respect}."""
    lines = []
    # Normalize RANK_D respect calls to {respect}
    body = re.sub(r'RANK_D\s*->\s*query_respect\s*\([^)]*\)', "{respect}", body)
    # command("say ...") — the say-text may be concatenated across lines
    for m in re.finditer(r'command\s*\(\s*"say\s+(.*?)"\s*\)', body, re.DOTALL):
        chunk = m.group(1)
        # chunk may contain " + " concatenations of string literals already merged
        txt = "".join(lpc_strings(chunk)) if '"' in chunk else chunk
        txt = txt.replace("\\n", "").strip()
        if txt:
            lines.append(txt)
    # say("...") or say( "a" + "b" )
    for m in re.finditer(r'(?<!command\()\bsay\s*\((.*?)\)\s*;', body, re.DOTALL):
        chunk = m.group(1)
        txt = "".join(lpc_strings(chunk))
        txt = txt.replace("\\n", "").strip()
        if txt:
            lines.append(txt)
    # de-dup preserving order
    seen = set()
    out = []
    for l in lines:
        if l not in seen:
            seen.add(l)
            out.append(l)
    return out


def extract_actions(body):
    """Extract add_action("do_x", "verb") / add_action("do_x", ({...})) verbs."""
    verbs = []
    for m in re.finditer(r'add_action\s*\(\s*"[^"]*"\s*,\s*(.*?)\)\s*;', body, re.DOTALL):
        arg = m.group(1)
        # string form
        if arg.strip().startswith('"'):
            for s in lpc_strings(arg):
                verbs.append(s)
        else:
            for s in lpc_strings(arg):
                verbs.append(s)
    seen = set()
    out = []
    for v in verbs:
        if v not in seen:
            seen.add(v)
            out.append(v)
    return out


def ucl_greetings_block(lines, indent="  "):
    inner = ",\n".join(f'{indent}  {{ line = "{l}" }}' for l in lines)
    return f"{indent}greetings = [\n{inner}\n{indent}]"


def main():
    apply = "--apply" in sys.argv
    for zone, npc_id, typ in SIMPLE:
        cpath = C.find_c_path(zone, npc_id)
        if not cpath or not os.path.exists(cpath):
            print(f"!! {zone}/{npc_id} [{typ}] source not found"); continue
        src = open(cpath, encoding="utf-8", errors="replace").read()
        body = C.extract_func(src, typ)
        if body is None:
            print(f"!! {zone}/{npc_id} [{typ}] func not found"); continue
        if typ == "greeting":
            data = extract_say_lines(body)
            print(f"{zone}/{npc_id} [greeting] -> {len(data)} lines")
            for l in data:
                print(f"    {l}")
        else:
            data = extract_actions(body)
            print(f"{zone}/{npc_id} [init] -> add_actions {data}")
        if apply and data:
            _apply(zone, npc_id, typ, data)


def _apply(zone, npc_id, typ, data):
    ucl_path = os.path.join(DATA_WORLD, zone + ".ucl")
    text = open(ucl_path, encoding="utf-8").read()
    block = R.find_ucl_block(text, npc_id)
    if block is None:
        print(f"   [apply] block {npc_id} not found in {zone}.ucl — skip"); return
    if typ == "greeting":
        if R.has_greetings(block):
            print(f"   [apply] {zone}/{npc_id} already has greetings — skip"); return
        new_block = block.rstrip() + "\n\n" + ucl_greetings_block(data) + "\n  "
        text2 = text.replace(block, new_block, 1)
        open(ucl_path, "w", encoding="utf-8").write(text2)
        print(f"   [apply] inserted {len(data)} greetings into {zone}/{npc_id}")
    else:
        # init: merge add_actions if init exists, else add init block
        if R.has_init(block):
            print(f"   [apply] {zone}/{npc_id} already has init — manual merge needed, skip")
            return
        new_block = block.rstrip() + "\n\n  init = {\n    add_actions = [" + \
            ", ".join(f'"{v}"' for v in data) + "]\n  }\n  "
        text2 = text.replace(block, new_block, 1)
        open(ucl_path, "w", encoding="utf-8").write(text2)
        print(f"   [apply] inserted init.add_actions {data} into {zone}/{npc_id}")


if __name__ == "__main__":
    main()
