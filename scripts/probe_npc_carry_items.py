"""How many extra item definitions would the orphan NPCs drag in?

The room's LPC source is parsed with lpc_paths, so CLASS_D() / __DIR__ expand
to real absolute LPC paths -- guessing from the room's own directory finds
nothing for /kungfu/class/<sect>/<npc>.

For every dangling room_items ref that is an NPC with no `characters`
definition anywhere in data/world, list the items that NPC carries or wears and
whether each already has a definition.
"""
import io
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lpc_paths import classify, entries_of, expand  # noqa: E402

WORLD = 'data/world'
LPC_ROOT = r'C:\files\git\mud'

GEN = re.compile(r'^#\s*Generated from\s+(.+?)\s+by LPCConverter')
ROOM_ITEMS = re.compile(r'^[ \t]*room_items\s+"([\w-]+)"\s*\{', re.M)
ITEM_BLOCK = re.compile(r'^[ \t]*items\s+"([\w-]+)"\s*\{', re.M)
CHAR_BLOCK = re.compile(r'^[ \t]*characters\s+"([^"]+)"\s*\{', re.M)
REF_ITEM = re.compile(r'^[ \t]*\{\s*id\s*=\s*items\.([\w-]+)\.id\s*\}', re.M)

CARRY = re.compile(r'carry_object\(\s*"([^"]+)"')
ARMOR = re.compile(r'->wear\(\s*\)')
ITEM_SLOT = re.compile(
    r'set\(\s*"(?:item\d+|armor|weapon)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')


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


def defs(path, rx):
    return set(rx.findall(io.open(path, encoding='utf-8', errors='replace').read()))


def room_sources(s):
    out, cur = {}, None
    for m in re.finditer(
            r'^(?:#\s*Generated from\s+(.+?)\s+by LPCConverter)?\s*$|'
            r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', s, re.M):
        if m.group(1):
            cur = m.group(1)
        elif m.group(2) and cur:
            out.setdefault(m.group(2), cur)
    return out


def lpc_base(rel):
    """Basename of an LPC path.

    os.path.basename() is no good here: LPC paths use '/', and on Windows
    os.path only splits on '\\', so it would hand back the whole path.
    """
    return norm(rel.rstrip('/').rsplit('/', 1)[-1])


def abs_lpc(src, expanded):
    """Absolute LPC path for an expanded entry, trying - and _ spellings."""
    if expanded.startswith('DIR:'):
        # room-relative: keep it LPC-style, then anchor it under the room's dir
        expanded = os.path.dirname(src).replace('\\', '/') + '/' + expanded[4:]
    for cand in (expanded, expanded.replace('-', '_'), expanded.replace('_', '-')):
        # carry_object() strings are not always absolute ("clone/misc/cloth")
        p = os.path.normpath(LPC_ROOT + os.sep + cand.lstrip('/').replace('/', os.sep))
        if os.path.exists(p + '.c'):
            return p + '.c', cand
    return None, expanded


def main():
    files = sorted(f for f in os.listdir(WORLD) if f.endswith('.ucl'))
    lib = os.path.join(WORLD, 'clone_lib.ucl')
    lib_items = defs(lib, ITEM_BLOCK)
    world_items = {f[:-4]: defs(os.path.join(WORLD, f), ITEM_BLOCK) for f in files}
    world_chars = {f[:-4]: defs(os.path.join(WORLD, f), CHAR_BLOCK) for f in files}

    orphans = {}          # LPC abs path -> [world name, ...]
    for fn in files:
        if fn == 'clone_lib.ucl':
            continue
        zone = fn[:-4]
        p = os.path.join(WORLD, fn)
        s = io.open(p, encoding='utf-8', errors='replace').read()
        local_items = world_items[zone]
        srcs = room_sources(s)

        cache = {}
        for m in ROOM_ITEMS.finditer(s):
            src = srcs.get(m.group(1))
            if not src or not os.path.exists(src):
                continue
            if src not in cache:
                txt = io.open(src, encoding='utf-8', errors='replace').read()
                ent = []
                for e in entries_of(txt):
                    x = expand(e)
                    if x is None:
                        continue
                    a, rel = abs_lpc(src, x)
                    if a:
                        ent.append((lpc_base(rel), a, rel))
                cache[src] = ent
            for name in REF_ITEM.findall(block(s, s.index('{', m.end() - 1))):
                if name in local_items or name in lib_items:
                    continue
                if any(name in world_chars[z] for z in world_chars):
                    continue
                hit = [a for b, a, _r in cache[src] if b == name]
                if len(hit) == 1:
                    orphans.setdefault(hit[0], []).append('%s/%s' % (zone, name))

    print('orphan NPCs with no characters definition anywhere: %d' % len(orphans))
    print('refs pointing at them: %d' % sum(len(v) for v in orphans.values()))
    print()

    buckets = defaultdict(set)
    n_refs = 0
    for path in sorted(orphans):
        txt = io.open(path, encoding='utf-8', errors='replace').read()
        refs = set(CARRY.findall(txt))
        for lit in ITEM_SLOT.findall(txt):
            refs.add(lit)
        n_weared = len(ARMOR.findall(txt))
        for r in refs:
            n_refs += 1
            a, rel = abs_lpc(path, r)
            if a is None:
                buckets['LPC 文件找不到'].add(rel)
                continue
            root, zs, base = classify(rel)
            n = norm(base)
            if n in lib_items or any(n in world_items[z] for z in world_items):
                buckets['已有 items 定义'].add(n)
            else:
                buckets['LPC 有 / world 无定义'].add(n)
        if n_weared and not refs:
            buckets['只 wear() 道具，无 carry_object 路径'].add(
                os.path.relpath(path, LPC_ROOT))

    print('carry/wear item refs inside those NPCs: %d' % n_refs)
    print()
    for k in ('已有 items 定义', 'LPC 有 / world 无定义', 'LPC 文件找不到',
              '只 wear() 道具，无 carry_object 路径'):
        v = buckets.get(k, set())
        print('== %s: %d ==' % (k, len(v)))
        for n in sorted(v)[:30]:
            print('   ' + n)
        print()


main()