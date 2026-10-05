"""Namespace cross-zone-borrowed NPCs as <source_zone>_<id> and centralise
them in clone_lib, then resolve them through a local-first clone_lib failover.

Background
----------
LPC rooms place NPCs by absolute path, so /d/beijing/npc/shiren may legitimately
appear in d/chengdu and d/jingzhou rooms. Our converter emitted a *bare*
`characters.shiren.id` in those zones, which silently resolved to whatever
`shiren` the borrowing zone happened to define - or to nothing.

Two different NPCs share the id `bing`: /d/city/npc/bing is a city soldier,
/d/xiangyang/npc/bing is a "song soldier" with 20000 exp. A bare id cannot
express "this room holds *city's* soldier", so those collided.

This script:
  1. finds every cross-zone borrow by aligning UCL `room_characters` entries
     with the LPC room file's `set("objects", ...)` list (alignment is by
     normalised name, because LPC counts can be expressions like random(2));
  2. copies each borrowed NPC's definition into clone_lib under the id
     `<source_zone>_<id>`, so /d/beijing/npc/shiren becomes `beijing_shiren`
     and can never collide with another zone's `bing`;
  3. rewrites the borrowing rooms' references to that id;
  4. leaves `/clone/**` references (already the shared layer) as bare ids.

Refs whose LPC counterpart cannot be identified are never touched.

Usage
-----
    python scripts/namespace_borrowed_npcs.py            # dry run
    python scripts/namespace_borrowed_npcs.py --apply    # write
"""
import argparse
import io
import os
import re
import shutil
import sys
import tempfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
CLONE_LIB = 'clone_lib'
CONVERTER = os.path.join(ROOT, 'scripts', 'lpc_converter.py')

_OBJ_RE = re.compile(r'set\(\s*"objects"\s*,\s*\(\s*[\[\{](.*?)[\]\}]\s*\)\s*\)', re.S)
_GEN_RE = re.compile(r'^#\s*Generated from (.+?) by LPCConverter', re.M)
_RC_RE = re.compile(r'^[ \t]*room_characters\s+"([^"]+)"\s*\{', re.M)
_CE_RE = re.compile(r'\{\s*id\s*=\s*characters\.([\w-]+)\.id\s*\}')
_CLONE_LIB_C = os.path.join(WORLD, 'clone_lib.ucl')


def norm(n):
    return n.replace('-', '_').lower()


# --------------------------------------------------------------------------
# LPC side
# --------------------------------------------------------------------------
def lpc_refs(lpc_path, room_zone):
    """Ordered [(raw_ref, count, is_random_expr)] from set("objects", (...))."""
    if not lpc_path or not os.path.exists(lpc_path):
        return []
    s = io.open(lpc_path, encoding='utf-8', errors='replace').read()
    m = _OBJ_RE.search(s)
    if not m:
        return []
    out = []
    for mm in re.finditer(r'(__DIR__)?"([^"]+)"\s*(?::\s*([^,\]\}]+))?', m.group(1)):
        d, ref, cnt = mm.group(1), mm.group(2), (mm.group(3) or '').strip()
        is_rand = 'random' in cnt
        out.append((('__DIR__' + ref) if d else ref,
                    None if is_rand else (int(cnt) if cnt.isdigit() else 1),
                    is_rand))
    return out


def classify(ref, room_zone):
    """-> (kind, zone, name) with zone == 'CLONE' for /clone/** references."""
    r = ref
    if r.startswith('__DIR__'):
        r = 'd/%s/%s' % (room_zone, r[len('__DIR__'):].lstrip('/'))
    r2 = r.lstrip('/')
    if r2.startswith('clone/'):
        parts = r2[len('clone/'):].split('/')
        base = parts[-1]
        if len(parts) >= 2 and parts[0] in ('npc', 'beast', 'animal', 'living'):
            return ('npc', 'CLONE', base)
        return ('item', CLONE_LIB, base)
    m = re.match(r'([a-z]+)/([^/]+)/npc/(.+)$', r2)
    if m:
        return ('npc', m.group(2), m.group(3).split('/')[-1])
    m = re.match(r'([a-z]+)/npc/(.+)$', r2)
    if m:
        return ('npc', m.group(1), m.group(2).split('/')[-1])
    m = re.match(r'([a-z]+)/([^/]+)/(?:obj|item)/(.+)$', r2)
    if m:
        return ('item', m.group(2), m.group(3).split('/')[-1])
    m = re.match(r'([a-z]+)/obj/(.+)$', r2)
    if m:
        return ('item', m.group(1), m.group(2).split('/')[-1])
    return ('other', None, r2)


def build_global_index(lpc_root):
    """basename -> {(zone, name)} for every npc .c; 'CLONE' for clone/npc."""
    idx = defaultdict(set)
    for dirpath, dirnames, filenames in os.walk(lpc_root):
        dirnames[:] = [d for d in dirnames if d != '.git']
        for fn in filenames:
            if not fn.endswith('.c'):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), lpc_root)
            rel = rel.replace(chr(92), '/')
            m3 = re.match(r'([a-z]+)/([^/]+)/npc/(.+)\.c$', rel)
            if m3:
                root, zone, name = m3.group(1), m3.group(2), m3.group(3)
                base = norm(name.split('/')[-1])
                idx[base].add(('CLONE' if root == 'clone' else zone, base))
                continue
            m2 = re.match(r'([a-z]+)/npc/(.+)\.c$', rel)
            if m2:
                root, name = m2.group(1), m2.group(2)
                base = norm(name.split('/')[-1])
                idx[base].add(('CLONE' if root == 'clone' else root, base))
    return idx


def find_lpc_npc(lpc_root, zone, name):
    """Locate <root>/<zone>/npc/<name>.c (or <zone>/npc/<name>.c for /adm).

    Tolerates hyphen/underscore spelling and case, since LPC filenames are
    inconsistent (18jingang-4bo.c, LiSouci.c).
    """
    want = {name.lower(), name.replace('_', '-').lower(), name.lower().replace('_', '-')}
    for dirpath, dirnames, filenames in os.walk(lpc_root):
        dirnames[:] = [d for d in dirnames if d != '.git']
        rel = os.path.relpath(dirpath, lpc_root).replace(chr(92), '/')
        parts = rel.split('/')
        if not parts or parts[-1] != 'npc':
            continue
        if len(parts) < 2 or parts[-2] != zone:
            continue
        low = {f.lower() for f in filenames}
        for c in want:
            if c + '.c' in low:
                for f in filenames:
                    if f.lower() == c + '.c':
                        return os.path.join(dirpath, f)
    return None


# --------------------------------------------------------------------------
# UCL side
# --------------------------------------------------------------------------
def block_span(s, m):
    j = s.index('{', m.start())
    depth = 0
    for k in range(j, len(s)):
        if s[k] == '{':
            depth += 1
        elif s[k] == '}':
            depth -= 1
            if depth == 0:
                return (m.start(), k + 1)
    return None


def room_character_blocks(s):
    """[(room, lpc_path, block_start, block_end, [(entry_id, abs_off, abs_end)])]"""
    gens = [(m.start(), m.group(1)) for m in _GEN_RE.finditer(s)]
    out = []
    for m in _RC_RE.finditer(s):
        sp = block_span(s, m)
        if not sp:
            continue
        b0, b1 = sp
        src = None
        for pos, p in gens:
            if pos < b0:
                src = p
            else:
                break
        mm = re.search(r'characters\s*=\s*\[(.*?)\]', s[b0:b1], re.S)
        entries = []
        if mm:
            arr_off = b0 + mm.start(1)
            for e in _CE_RE.finditer(mm.group(1)):
                entries.append((e.group(1), arr_off + e.start(), arr_off + e.end()))
        out.append((m.group(1), src, b0, b1, entries))
    return out


def char_blocks(s):
    """[(name, start, end)] for every `characters "x" { ... }` block."""
    out = []
    for m in re.finditer(r'^[ \t]*characters\s+"([\w-]+)"\s*\{', s, re.M):
        sp = block_span(s, m)
        if sp:
            out.append((m.group(1), sp[0], sp[1]))
    return out


def balanced(text, i):
    j = text.index('{', i)
    d = 0
    in_s = False
    esc = False
    for k in range(j, len(text)):
        c = text[k]
        if in_s:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_s = False
            continue
        if c == '"':
            in_s = True
        elif c == '{':
            d += 1
        elif c == '}':
            d -= 1
            if d == 0:
                return text[i:k + 1]
    return None


def rename_char_block(blk, new_id):
    """Rewrite the `characters "old" {` key to `characters "new" {`."""
    return re.sub(r'^(\s*characters\s+)"[^"]*"',
                  lambda m: '%s"%s"' % (m.group(1), new_id),
                  blk, count=1)


# --------------------------------------------------------------------------
# planning
# --------------------------------------------------------------------------
class Plan(object):
    def __init__(self):
        self.edits = defaultdict(list)      # ucl path -> [(off, end, new_text, old_id, new_id)]
        self.needed = {}                     # new_id -> (zone, name)
        self.kept_local = 0
        self.kept_clone = 0
        self.skipped = []                    # no LPC counterpart
        self.non_npc = 0
        self.ambiguous = []


def build_plan(lpc_root, verbose=True):
    plan = Plan()
    gidx = build_global_index(lpc_root)

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl') or fn == 'clone_lib.ucl':
            continue
        zone = fn[:-4]
        path = os.path.join(WORLD, fn)
        s = io.open(path, encoding='utf-8').read()
        local_chars = {norm(n) for (n, _a, _b) in char_blocks(s)}

        for room, src, b0, b1, entries in room_character_blocks(s):
            if not entries:
                continue
            lpc_path = None
            if src:
                lpc_path = src.replace('/', os.sep)
                if not os.path.exists(lpc_path):
                    lpc_path = None
            refs = lpc_refs(lpc_path, zone) if lpc_path else []

            byname = defaultdict(list)
            for raw, _cnt, _r in refs:
                k, sz, name = classify(raw, zone)
                byname[norm(name)].append((k, sz, name))

            for cid, off, end in entries:
                cands = byname.get(norm(cid), [])
                npc = [c for c in cands if c[0] == 'npc' and c[1] != 'CLONE']
                clone = [c for c in cands if c[0] == 'npc' and c[1] == 'CLONE']

                if npc:
                    pairs = {(c[1], c[2]) for c in npc}
                    if len(pairs) > 1:
                        plan.ambiguous.append(
                            '%s/%s: %s -> %s' % (zone, room, cid, sorted(pairs)))
                        continue
                    sz, name = npc[0][1], npc[0][2]
                elif clone:
                    plan.kept_clone += 1
                    continue
                elif cands:
                    # id matched a non-npc LPC ref (e.g. /clone/horse/zaohongma)
                    plan.non_npc += 1
                    continue
                else:
                    # 没有 LPC 里**显式的**跨区 NPC 引用，就无法证明这是借用。
                    #
                    # 之前这里会退回 gidx（按名字在全树里搜同�� .c），那会把
                    # liuxi/room_characters 里的 `characters.heihu.id`（本区自己
                    # 定义 heihu）判成 minimal_world 的 heihu，改写成
                    # `characters.minimal_world_heihu.id` —— 定义是别人的，skills /
                    # loot 全丢，还凭空给 clone_lib 塞一个垃圾定义。
                    # 名字相同不等于跨区借用；没有路径证据就保持本地。
                    plan.skipped.append('%s/%s: %s (no explicit cross-zone LPC ref)'
                                        % (zone, room, cid))
                    continue

                if sz == zone:
                    plan.kept_local += 1
                    continue

                # 本区已有同名定义：local-first，绝不替换成本区外的版本。
                if norm(cid) in local_chars:
                    plan.kept_local += 1
                    continue

                new_id = '%s_%s' % (sz, norm(name))
                plan.needed[new_id] = (sz, norm(name))
                plan.edits[path].append(
                    (off, end,
                     '{ id = characters.%s.id }' % new_id, cid, new_id))

    return plan


def load_converter():
    import importlib.util
    spec = importlib.util.spec_from_file_location('lpc_converter', CONVERTER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def definition_for(new_id, sz, name, lpc_root, zone_ucl_cache, conv):
    """Return the `characters "<new_id>" { ... }` block text, or None."""
    upath = os.path.join(WORLD, sz + '.ucl')
    if upath in zone_ucl_cache:
        us = zone_ucl_cache[upath]
    elif os.path.exists(upath):
        us = io.open(upath, encoding='utf-8').read()
        zone_ucl_cache[upath] = us
    else:
        us = None
    if us is not None:
        for nm, b0, b1 in char_blocks(us):
            if norm(nm) == norm(name):
                return rename_char_block(us[b0:b1], new_id)

    src = find_lpc_npc(lpc_root, sz, name)
    if not src:
        return None
    body = io.open(src, encoding='utf-8', errors='replace').read()
    res = conv.convert_file(src, zone_id=CLONE_LIB, include_header=True)
    ucl = res[0] if isinstance(res, tuple) else res
    for nm, b0, b1 in char_blocks(ucl):
        if norm(nm) == norm(name):
            return rename_char_block(ucl[b0:b1], new_id)
    if not re.search(r'^\s*inherit\s+', body, re.M):
        return None
    tmpd = tempfile.mkdtemp(prefix='npc_')
    try:
        tmp = os.path.join(tmpd, name + '.c')
        with io.open(tmp, 'w', encoding='utf-8', newline='') as f:
            f.write('inherit NPC;\n' + body)
        res = conv.convert_file(tmp, zone_id=CLONE_LIB, include_header=True)
        ucl = res[0] if isinstance(res, tuple) else res
        for nm, b0, b1 in char_blocks(ucl):
            if norm(nm) == norm(name):
                return rename_char_block(ucl[b0:b1], new_id)
    finally:
        shutil.rmtree(tmpd, ignore_errors=True)
    return None


def report(plan, lpc_root):
    L = []
    total_refs = sum(len(v) for v in plan.edits.values())
    L.append('=' * 74)
    L.append('namespace_borrowed_npcs  (dry run)')
    L.append('=' * 74)
    L.append('refs to rewrite            : %d' % total_refs)
    L.append('distinct new ids          : %d' % len(plan.needed))
    L.append('refs kept (local bare id) : %d' % plan.kept_local)
    L.append('refs kept (/clone bare)   : %d' % plan.kept_clone)
    L.append('refs matched non-npc ref  : %d' % plan.non_npc)
    L.append('refs skipped (no source)  : %d' % len(plan.skipped))
    L.append('ambiguous                 : %d' % len(plan.ambiguous))
    L.append('zone files touched        : %d' % len(plan.edits))
    L.append('')
    c = defaultdict(int)
    for nid, (sz, _n) in plan.needed.items():
        c[sz] += 1
    L.append('source zones: ' + ', '.join('%s=%d' % (k, v)
                                          for k, v in sorted(c.items(), key=lambda kv: -kv[1])))
    L.append('')
    L.append('source availability:')
    cache = {}
    conv = load_converter()
    have, missing, from_lpc = [], [], []
    for nid, (sz, name) in sorted(plan.needed.items()):
        upath = os.path.join(WORLD, sz + '.ucl')
        ok = False
        if os.path.exists(upath):
            us = cache.get(upath)
            if us is None:
                us = io.open(upath, encoding='utf-8').read()
                cache[upath] = us
            ok = any(norm(nm) == norm(name) for nm, _a, _b in char_blocks(us))
        if ok:
            have.append(nid)
        elif find_lpc_npc(lpc_root, sz, name):
            from_lpc.append(nid)
        else:
            missing.append(nid)
    L.append('  copy from source zone UCL : %d' % len(have))
    L.append('  convert from LPC .c       : %d' % len(from_lpc))
    L.append('  NO SOURCE                 : %d  %s' % (len(missing), missing))
    L.append('')
    if plan.ambiguous:
        L.append('AMBIGUOUS (%d)' % len(plan.ambiguous))
        for a in plan.ambiguous[:20]:
            L.append('   ' + a)
    if plan.skipped:
        L.append('')
        L.append('SKIPPED (%d) - no LPC counterpart, left untouched' % len(plan.skipped))
        for sk in plan.skipped[:30]:
            L.append('   ' + sk)
    return '\n'.join(L)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lpc-root', default=r'C:\files\git\mud')
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()

    plan = build_plan(args.lpc_root)
    print(report(plan, args.lpc_root))
    if not args.apply:
        print('\n(dry run; nothing written)')
        return 0

    conv = load_converter()
    cache = {}
    blocks, missing = [], []
    for nid, (sz, name) in sorted(plan.needed.items()):
        blk = definition_for(nid, sz, name, args.lpc_root, cache, conv)
        if blk:
            blocks.append((nid, blk))
        else:
            missing.append(nid)

    if missing:
        print('\nrefusing to apply: %d ids have no source: %s'
              % (len(missing), missing))

    # 1. drop the old un-namespaced shared NPCs from clone_lib
    s = io.open(_CLONE_LIB_C, encoding='utf-8').read()
    drop = []
    for nm, b0, b1 in char_blocks(s):
        if '_' in nm:
            continue
        # only remove the blocks convert_shared_npcs.py added
        head = s[max(0, b0 - 200):b0]
        if 'LPC' in head and 'clone/' in head:
            drop.append((b0, b1))
    for b0, b1 in reversed(drop):
        s = s[:b0] + s[b1:]
    print('removed %d un-namespaced shared NPCs from clone_lib' % len(drop))

    # 2. append the namespaced definitions
    add = []
    for nid, blk in blocks:
        add.append('# LPC 跨区借用：id 前缀是来源区，避免同名 NPC 互相覆盖\n')
        add.append(blk)
        add.append('\n\n')
    s = s.rstrip('\n') + '\n\n' + ''.join(add)
    io.open(_CLONE_LIB_C, 'w', encoding='utf-8', newline='').write(s)
    print('appended %d namespaced NPCs to clone_lib' % len(blocks))

    # 3. rewrite the borrowing rooms' references
    touched = 0
    for path, edits in plan.edits.items():
        t = io.open(path, encoding='utf-8').read()
        for off, end, new, _o, _n in sorted(edits, key=lambda e: -e[0]):
            t = t[:off] + new + t[end:]
        io.open(path, 'w', encoding='utf-8', newline='').write(t)
        touched += 1
    print('rewrote refs in %d zone files' % touched)

    if missing:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())