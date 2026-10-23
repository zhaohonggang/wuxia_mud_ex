#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Survey: which UCL rooms have an array-form `add_action` in their LPC source,
and which of those still lack a UCL `actions` block (i.e. pending backfill)."""
import io, os, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
WORLD = os.path.join(ROOT, 'data', 'world')
MUD_ROOT = 'C:/files/git/mud'

ROOM_OPEN = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{\s*$')
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPCC = re.compile(r"^#\s*LPC:\s*(\S+)")
ADD_ACTION_ARRAY = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*(\(\s*\{[^}]*\}\s*\))""",
)

def skeleton_delta(line):
    out = 0; in_str = False; i = 0
    while i < len(line):
        ch = line[i]
        if not in_str and ch == "#": break
        if in_str:
            if ch == "\\": i += 2; continue
            if ch == '"': in_str = False
        else:
            if ch == '"': in_str = True
            elif ch == '{': out += 1
            elif ch == '}': out -= 1
        i += 1
    return out

def norm(p): return p.replace("\\", "/").lower()

def find_block_close(lines, start):
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if i >= start and depth == 0: return i
    return -1

def room_lpc_path(lines, room_key):
    depth = 0; last_gen = None
    for i, line in enumerate(lines):
        s = line.strip(); m = GEN.match(s)
        if m and depth == 0: last_gen = norm(m.group(1))
        om = ROOM_OPEN.match(line)
        if om and om.group(1) == room_key and depth == 0:
            end = find_block_close(lines, i)
            for j in range(i+1, max(end, i+1)):
                lm = LPCC.match(lines[j].strip())
                if lm: return norm(lm.group(1))
            return last_gen
        depth += skeleton_delta(line)
    return None

def extract_array_actions(lpc_path):
    full = os.path.join(MUD_ROOT, lpc_path)
    if not os.path.exists(full): return None
    text = open(full, encoding='utf-8', errors='replace').read()
    actions = {}
    for handler, arr in ADD_ACTION_ARRAY.findall(text):
        for verb in re.findall(r"""["']([^"']+)["']""", arr):
            actions.setdefault(verb, handler)
    return actions

def room_has_actions(lines, start, end):
    for i in range(start+1, end):
        if re.match(r'^\s*actions\s*=', lines[i]): return True
    return False

pending = []
already = []
for zone in sorted(os.listdir(WORLD)):
    if not zone.endswith('.ucl'): continue
    path = os.path.join(WORLD, zone)
    lines = open(path, encoding='utf-8').read().split('\n')
    depth = 0
    for i, line in enumerate(lines):
        om = ROOM_OPEN.match(line)
        if om and depth == 0:
            key = om.group(1)
            end = find_block_close(lines, i)
            lpc = room_lpc_path(lines, key)
            if not lpc: 
                depth += skeleton_delta(line); continue
            acts = extract_array_actions(lpc)
            if acts:
                has = room_has_actions(lines, i, end)
                if has:
                    already.append((zone[:-4], key, sorted(acts)))
                else:
                    pending.append((zone[:-4], key, sorted(acts)))
        depth += skeleton_delta(line)

print("=== PENDING (no UCL actions block yet) — %d ===" % len(pending))
for z, k, v in pending:
    print("  %s:%s   %s" % (z, k, ",".join(v)))
print("\n=== ALREADY BACKFILLED (has actions block) — %d ===" % len(already))
for z, k, v in already:
    print("  %s:%s   %s" % (z, k, ",".join(v)))
print("\nTOTAL array-form sites: %d (pending %d, already %d)" % (len(pending)+len(already), len(pending), len(already)))
