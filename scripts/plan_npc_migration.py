"""Size the job of moving the 431 NPC-in-items refs into room_characters.

For every dangling room_items ref that LPC says is an NPC, report:
  * the distinct LPC target file
  * whether the borrowing zone already has a `characters "<name>"` definition
  * whether any other zone has one
so we can tell "just move the ref" apart from "also need to write the definition".
"""
import io
import os
import re
from collections import defaultdict

from lpc_paths import classify, expand, lpc_objects, entries_of

WORLD = 'data/world'
LPC_ROOT = r'C:\files\git\mud'

GEN = re.compile(r'^#\s*Generated from\s+(.+?)\s+by LPCConverter')
ROOM_ITEMS = re.compile(r'^[ \t]*room_items\s+"([\w-]+)"\s*\{', re.M)
ROOM_CHARS = re.compile(r'^[ \t]*room_characters\s+"([\w-]+)"\s*\{', re.M)
CHAR_BLOCK = re.compile(r'^[ \t]*characters\s+"([^"]+)"\s*\{', re.M)
ITEM_BLOCK = re.compile(r'^[ \t]*items\s+"([\w-]+)"\s*\{', re.M)
REF_ITEM = re.compile(r'^[ \t]*\{\s*id\s*=\s*items\.([\w-]+)\.id\s*\}', re.M)
REF_CHAR = re.compile(r'^[ \t]*\{\s*id\s*=\s*characters\.([\w-]+)\.id\s*\}', re.M)

NPC_DIRS = ('clone/quarry', 'clone/worm', 'clone/beast')


def norm(n):
    return n.lower().replace('-', '_')


def block(text, i):
    depth = 0
    for j in range(i, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    return ''


def zone_names(path, kind):
    s = io.open(path, encoding='utf-8', errors='replace').read()
    rx = CHAR_BLOCK if kind == 'characters' else ITEM_BLOCK
    return set(rx.findall(s))


def main():
    files = sorted(f for f in os.listdir(WORLD) if f.endswith('.ucl'))
    clone_items = zone_names(os.path.join(WORLD, 'clone_lib.ucl'), 'items')
    clone_chars = zone_names(os.path.join(WORLD, 'clone_lib.ucl'), 'characters')
    zone_chars = {f[:-4]: zone_names(os.path.join(WORLD, f), 'characters')
                  for f in files}

    rows = []
    for fn in files:
        if fn == 'clone_lib.ucl':
            continue
        zone = fn[:-4]
        p = os.path.join(WORLD, fn)
        s = io.open(p, encoding='utf-8', errors='replace').read()
        local_items = zone_names(p, 'items')

        room_src, cur = {}, None
        for m in re.finditer(
                r'^(?:#\s*Generated from\s+(.+?)\s+by LPCConverter)?\s*$|'
                r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', s, re.M):
            if m.group(1):
                cur = m.group(1)
            elif m.group(2) and cur:
                room_src.setdefault(m.group(2), cur)

        # rooms that already place characters, to spot duplicates later
        placed = {}
        for m in ROOM_CHARS.finditer(s):
            body = block(s, s.index('{', m.end() - 1))
            placed.setdefault(m.group(1), set()).update(REF_CHAR.findall(body))

        for m in ROOM_ITEMS.finditer(s):
            rk = m.group(1)
            body = block(s, s.index('{', m.end() - 1))
            lrefs = lpc_objects(room_src.get(rk), zone)
            for name in REF_ITEM.findall(body):
                if name in local_items or name in clone_items:
                    continue
                named = [r for r in lrefs if norm(r[2]) == name]
                if len(named) != 1:
                    continue
                root, zs, _ = named[0]
                if root not in ('kungfu', 'npc') and zs not in NPC_DIRS:
                    continue          # a real item, handled elsewhere
                rows.append({
                    'zone': zone, 'room': rk, 'name': name,
                    'root': root, 'src_dir': zs,
                    'in_zone': name in zone_chars[zone],
                    'in_clone': name in clone_chars,
                    'in_any': sorted(z for z, cs in zone_chars.items() if name in cs),
                    'already_placed': name in placed.get(rk, set()),
                    'room_src': room_src.get(rk),
                })

    print('NPC refs to migrate: %d' % len(rows))
    print()

    targets = defaultdict(list)
    for r in rows:
        targets[(r['root'], r['src_dir'])].append(r)
    print('distinct (kind, LPC dir): %d' % len(targets))
    distinct_files = set()
    for r in rows:
        if r['room_src']:
            distinct_files.add(r['room_src'])
    print('distinct LPC .c referenced: %d' % len(distinct_files))
    print()

    have, need, dup = [], [], []
    for r in rows:
        if r['already_placed']:
            dup.append(r)
        elif r['in_zone']:
            have.append(r)
        else:
            need.append(r)

    print('== 只差「挪引用」（本区已有 characters 定义）: %d 条 ==' % len(have))
    byz = defaultdict(int)
    for r in have:
        byz[r['zone']] += 1
    for z, c in sorted(byz.items(), key=lambda x: -x[1]):
        print('  %-14s %d' % (z, c))
    print()

    print('== 需要新写 characters 定义: %d 条 ==' % len(need))
    d = defaultdict(set)
    for r in need:
        d[(r['root'], r['src_dir'])].add(r['name'])
    for k in sorted(d, key=lambda x: -len(d[x])):
        print('  %-30s %d 个不同 NPC' % (str(k), len(d[k])))
    print()

    print('== 房间已用 room_characters 放了同一个 NPC（会造成重复放置）: %d ==' % len(dup))
    for r in dup[:15]:
        print('  %s/%s %s' % (r['zone'], r['room'], r['name']))
    print()

    orphan = [r for r in need if not r['in_any'] and not r['in_clone']]
    print('== 全库都没有该 NPC 定义（纯新写）: %d 条 / %d 个 =='
          % (len(orphan), len({r['name'] for r in orphan})))


main()