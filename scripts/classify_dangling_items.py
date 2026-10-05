"""Classify every dangling room_items reference by its LPC source path.

Static equivalent of the loader's resolution order: a ref `items.X.id` in zone Z
resolves if Z defines `items "X"` OR clone_lib defines `items "X"`. Everything
else is what the loader reports as dangling.
"""
import io
import os
import re
from collections import defaultdict

from lpc_paths import classify, expand, lpc_objects, entries_of

WORLD = 'data/world'
LPC_ROOT = r'C:\files\git\mud'

GEN = re.compile(r'^#\s*Generated from\s+(.+?)\s+by LPCConverter')
ROOM = re.compile(r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', re.M)
ROOM_ITEMS = re.compile(r'^[ \t]*room_items\s+"([\w-]+)"\s*\{', re.M)
ITEM_BLOCK = re.compile(r'^[ \t]*items\s+"([\w-]+)"\s*\{', re.M)
REF = re.compile(r'^[ \t]*\{\s*id\s*=\s*items\.([\w-]+)\.id\s*\}', re.M)


def norm(n):
    """LPC basenames normalize the same way the converter did."""
    return n.lower().replace('-', '_')


def block(text, brace_idx):
    depth = 0
    for j in range(brace_idx, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return text[brace_idx:j + 1]
    return ''


def zone_defs(path):
    s = io.open(path, encoding='utf-8', errors='replace').read()
    return set(ITEM_BLOCK.findall(s))


def main():
    clone_items = zone_defs(os.path.join(WORLD, 'clone_lib.ucl'))

    rows = []
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl') or fn == 'clone_lib.ucl':
            continue
        zone = fn[:-4]
        p = os.path.join(WORLD, fn)
        s = io.open(p, encoding='utf-8', errors='replace').read()
        local = zone_defs(p)

        room_src = {}
        cur = None
        for m in re.finditer(
                r'^(?:#\s*Generated from\s+(.+?)\s+by LPCConverter)?\s*$|'
                r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', s, re.M):
            if m.group(1):
                cur = m.group(1)
            elif m.group(2) and cur:
                room_src.setdefault(m.group(2), cur)

        for m in ROOM_ITEMS.finditer(s):
            rk = m.group(1)
            body = block(s, s.index('{', m.end() - 1))
            refs = REF.findall(body)
            src = room_src.get(rk)
            lrefs = lpc_objects(src, zone)
            for name in refs:
                if name in local or name in clone_items:
                    continue
                named = [r for r in lrefs if norm(r[2]) == name]
                if len(named) == 1:
                    root = named[0]
                elif len(named) > 1:
                    root = ('AMBIG', '|'.join(sorted({r[1] for r in named})), name)
                else:
                    root = ('?', None, name)
                rows.append((zone, rk, name, root[0], root[1], src))

    n = len(rows)
    print('dangling room_items refs: %d' % n)
    print()

    byroot = defaultdict(int)
    for _z, _r, _n, root, _zs, _s in rows:
        byroot[root] += 1
    print('== by LPC object kind ==')
    for k, v in sorted(byroot.items(), key=lambda x: -x[1]):
        print('  %-8s %d' % (k, v))
    print()

    print('== by LPC directory ==')
    bydir = defaultdict(list)
    for z, rk, name, root, zs, src in rows:
        bydir['%s/%s' % (root, zs)].append((z, rk, name))
    for k in sorted(bydir, key=lambda x: -len(bydir[x])):
        print('  %-26s %-5d e.g. %s/%s -> %s'
              % (k, len(bydir[k]), bydir[k][0][0], bydir[k][0][1], bydir[k][0][2]))
    print()

    # Are these "items" actually NPCs? Read the inherit chain of the LPC target.
    print('== LPC target inherit check (per category) ==')
    seen = set()
    for z, rk, name, root, zs, src in rows:
        if (root, zs) in seen:
            continue
        seen.add((root, zs))
    cats = defaultdict(list)
    for z, rk, name, root, zs, src in rows:
        cats[(root, zs)].append((src, name, z, rk))
    for key in sorted(cats, key=lambda k: -len(cats[k])):
        root, zs = key
        src, name, z, rk = cats[key][0]
        base = None
        if zs and zs.startswith('kungfu/class/'):
            base = zs.split('/')[-1]
        elif zs and zs.startswith('clone/'):
            base = zs.split('/')[-1]
        if not base:
            print('  %-34s %-4d (no inherit probe)' % (str(key), len(cats[key])))
            continue
        cands = []
        # LPC basenames keep hyphens (yue-wife) while the UCL normalizes them
        # (yue_wife), so probe both spellings.
        for fname in (name, name.replace('_', '-')):
            for d in ('kungfu/class/' + base, 'clone/' + base):
                p = os.path.join(r'C:\files\git\mud', d, fname + '.c')
                if os.path.exists(p) and p not in cands:
                    cands.append(p)
        if not cands:
            print('  %-34s %-4d target .c NOT FOUND' % (str(key), len(cats[key])))
            continue
        inh = []
        for c in cands:
            t = io.open(c, encoding='utf-8', errors='replace').read()
            mm = re.search(r'^\s*inherit\s+([A-Za-z_][\w/]*)\s*;', t, re.M)
            inh.append(mm.group(1) if mm else '?')
        print('  %-34s %-4d inherits %s' % (str(key), len(cats[key]), ','.join(inh)))
    print()

    print('== summary: item vs npc ==')
    NPC_DIRS = ('clone/quarry', 'clone/worm', 'clone/beast')
    n_npc = sum(1 for r in rows if r[3] in ('kungfu', 'npc') or r[4] in NPC_DIRS)
    print('  NPC-in-items  : %d' % n_npc)
    print('  real ITEM     : %d' % (len(rows) - n_npc))
    print()

    print('== the real items, in detail ==')
    for z, rk, name, root, zs, src in rows:
        if root in ('kungfu', 'npc') or zs in NPC_DIRS:
            continue
        abs_path = None
        if src and os.path.exists(src):
            t = io.open(src, encoding='utf-8', errors='replace').read()
            for e in entries_of(t):
                if norm(e.split('/')[-1].split('"')[0].replace('-', '_')) == name:
                    abs_path = expand(e)
                    break
        if not abs_path:
            print('  %-9s %-12s %-16s <- (no absolute path)' % (z, rk, name))
            continue
        rel = abs_path[4:] if abs_path.startswith('DIR:') else abs_path.lstrip('/')
        if abs_path.startswith('DIR:'):
            rel = os.path.join(os.path.dirname(src).replace('\\', '/'), rel)
        cands = [rel + '.c', rel.replace('_', '-') + '.c']
        found = next((c for c in cands
                      if os.path.exists(os.path.join(LPC_ROOT, c))), None)
        print('  %-9s %-12s %-14s <- %-38s %s'
              % (z, rk, name, abs_path,
                 ('EXISTS ' + os.path.basename(found)) if found else 'DEFINITION MISSING'))

    print()
    unres = [r for r in rows if r[3] in ('?', 'MACRO', 'AMBIG')]
    print('still unresolved: %d' % len(unres))
    seen = set()
    for z, rk, name, root, zs, src in unres:
        if (z, rk) in seen:
            continue
        seen.add((z, rk))
        if len(seen) <= 25:
            raw = ''
            if src and os.path.exists(src):
                t = io.open(src, encoding='utf-8', errors='replace').read()
                o = entries_of(t)
                raw = ' | '.join(o[:4])
            print('  %s/%s %s  kind=%s  lpc=%s' % (z, rk, name, root, raw[:90]))


main()