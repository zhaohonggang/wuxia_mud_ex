"""Move the NPCs that lpc_converter filed under room_items into room_characters.

Why this exists
---------------
scripts/lpc_converter.py decides "is this set("objects") entry a person?" with

    def _contains_npc(path):
        return "npc" in path

a substring test on the path string.  Right for /d/<zone>/npc/xiaoer2, wrong for
every other place LPC keeps people, so

    set("objects", ([ CLASS_D("ouyang") + "/ouyangfeng" : 1 ]))

came out as `items.ouyangfeng.id`.  431 refs landed in room_items and, since the
NPCs never got a `characters` block, the mistake stayed quiet: a dangling *item*
reference is only a warning.

Two related gaps fall out of the same root cause:

  * _determine_object_type() cannot resolve the base classes under mud/inherit/,
    so `inherit QUARRY;` (clone/quarry/*) came out "generic" instead of npc;
  * the converter only ever walked /d, so /kungfu/class/<sect>/*.c and
    /clone/{quarry,worm,beast}/*.c never got a characters block at all.

What this script does
---------------------
It reuses lpc_converter's parser and UCL writers but decides npc-vs-item by
reading the target file's own inherit chain (resolving base classes out of
mud/inherit/) instead of matching the path.

Deliberately NOT a regeneration: re-running _generate_room_objects() rewrites
the whole room block and would revert the targeted fixes earlier commits made to
individual rooms.  So the pass is surgical -- it edits exactly the one ref line
per NPC and leaves every other byte of every room alone:

  * a ref whose target resolves definitively to 'npc' moves out of the
    room_items list into the room's room_characters list (creating that block if
    the room has none, in the position _generate_room_objects would use);
  * anything the resolver cannot answer with confidence is left untouched and
    reported, so the pass can never regress a correct ref;
  * definitions the moved refs now need are written to clone_lib.ucl, which is
    the loader's single shared layer (Kantele.World.Loader's @clone_zone_id).

lpc_converter.py is left alone; the authoritative classifier lives here.

Usage
-----
    python scripts/fix_npc_in_items.py             # report only
    python scripts/fix_npc_in_items.py --apply
    python scripts/fix_npc_in_items.py --apply --only shaolin beijing
"""
import io
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lpc_converter as C          # noqa: E402
from lpc_paths import entries_of, expand       # noqa: E402

LPC_ROOT = r'C:\files\git\mud'
WORLD = 'data/world'
CLONE_LIB = os.path.join(WORLD, 'clone_lib.ucl')

ROOM_ITEMS_HDR = re.compile(r'^[ \t]*room_items\s+"([\w-]+)"\s*\{', re.M)
ROOM_CHARS_HDR = re.compile(r'^[ \t]*room_characters\s+"([\w-]+)"\s*\{', re.M)
ROOMS_HDR = re.compile(r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', re.M)
ITEM_BLOCK = re.compile(r'^[ \t]*items\s+"([\w-]+)"\s*\{', re.M)
CHAR_BLOCK = re.compile(r'^[ \t]*characters\s+"([^"]+)"\s*\{', re.M)
REF_ITEM = re.compile(r'^[ \t]*\{\s*id\s*=\s*items\.([\w-]+)\.id\s*\}', re.M)
REF_CHAR = re.compile(r'^[ \t]*\{\s*id\s*=\s*characters\.([\w-]+)\.id\s*\}', re.M)
# Any ref line, either namespace, with the indentation and text as written.
REF_LINE = re.compile(r'^([ \t]*)\{\s*id\s*=\s*(items|characters)\.([\w-]+)\.id\s*\}', re.M)

APPLY = '--apply' in sys.argv


def argvals(flag):
    """Every non-flag argument after `flag`, so `--only a b c` keeps all three.

    Reading a single value would silently drop the rest: the docstring example
    `--only shaolin beijing` has to migrate both zones, not just shaolin.
    """
    out = []
    for i, a in enumerate(sys.argv):
        if a == flag:
            for rest in sys.argv[i + 1:]:
                if rest.startswith('--'):
                    break
                out.append(rest)
    return out


ONLY = set(argvals('--only')) or None
WRITE_DEFS = '--with-definitions' in sys.argv


# ---------------------------------------------------------------------------
# authoritative LPC type resolution
# ---------------------------------------------------------------------------

_inherit_index = None
_type_cache = {}


def build_inherit_index():
    """Base class name (lowercased, no .c) -> file under mud/inherit/."""
    global _inherit_index
    if _inherit_index is None:
        _inherit_index = {}
        for dirpath, _dirs, names in os.walk(os.path.join(LPC_ROOT, 'inherit')):
            for n in names:
                if n.endswith('.c'):
                    _inherit_index.setdefault(n[:-2].lower(),
                                              os.path.join(dirpath, n))
    return _inherit_index


def parse_lpc(path):
    with open(path, 'rb') as f:
        return C._parse_lpc(f.read(), path, os.path.dirname(path))


def find_inherit_file(name):
    key = name.strip().lower()
    return build_inherit_index().get(key[:-2] if key.endswith('.c') else key)


def resolve_lpc_type(path, depth=0):
    """'npc' | 'item' | 'room' | 'skill' | 'generic' for one LPC file.

    Same answer as lpc_converter._determine_object_type, except that a
    "generic" verdict now falls through to the file's own inherit list, which
    is what makes `inherit QUARRY;` (mud/inherit/char/quarry.c, itself
    `inherit NPC;`) resolve to npc.
    """
    if path in _type_cache:
        return _type_cache[path]
    if depth > 8 or not os.path.exists(path):
        return 'generic'

    _type_cache[path] = 'generic'                     # cycle guard
    try:
        ast = parse_lpc(path)
    except Exception:
        return 'generic'
    if ast is None:
        return 'generic'

    verdict = C._determine_object_type(C._merge_inherit_chain(ast))
    if verdict != 'generic':
        _type_cache[path] = verdict
        return verdict

    for inh in ast.inherits:
        base = find_inherit_file(inh)
        if base and base != path:
            got = resolve_lpc_type(base, depth + 1)
            if got != 'generic':
                _type_cache[path] = got
                return got
    return 'generic'


def lpc_path_for(expr):
    """Absolute LPC file for an expanded path expression, or None."""
    if not expr:
        return None
    e = expr.strip()
    if e.startswith('__DIR__') or e.startswith('CLASS_D'):
        return None
    if not e.startswith('/'):
        e = '/' + e
    for cand in (e, e.replace('-', '_'), e.replace('_', '-')):
        p = LPC_ROOT + cand.replace('/', os.sep) + '.c'
        if os.path.exists(p):
            return p
    return None


# ---------------------------------------------------------------------------
# world data text helpers
# ---------------------------------------------------------------------------

def read(path):
    raw = io.open(path, 'rb').read()
    nl = '\r\n' if b'\r\n' in raw else '\n'
    return raw.decode('utf-8'), nl


def write(path, text, nl):
    with io.open(path, 'wb') as f:
        f.write(text.replace('\n', nl).encode('utf-8'))


def brace_end(text, brace):
    depth = 0
    for j in range(brace, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return j + 1
    raise ValueError('unbalanced braces at offset %d' % brace)


def block_span(text, m):
    start = m.start()
    while start and text[start - 1] not in '\r\n':
        start -= 1
    return start, brace_end(text, text.index('{', m.end() - 1))


def room_sources(text):
    out, cur = {}, None
    for m in re.finditer(
            r'^(?:#\s*Generated from\s+(.+?)\s+by LPCConverter)?\s*$|'
            r'^[ \t]*rooms\s+"([\w-]+)"\s*\{', text, re.M):
        if m.group(1):
            cur = m.group(1)
        elif m.group(2) and cur:
            out.setdefault(m.group(2), cur)
    return out


def source_prefix(lpc_path):
    """The <source> half of the clone_lib id, taken from the LPC directory.

    clone_lib's NPC ids all carry a source prefix -- beijing_shiren,
    kaifeng_guanbing, yitian_zhaomin2 -- and
    test/kantele/world/cross_zone_npc_test.exs asserts none of them are bare.
    A bare id in the shared layer would also collide with the borrowing zone's
    own definition of the same name, so the prefix is not cosmetic.
    """
    rel = os.path.relpath(lpc_path, LPC_ROOT).replace('\\', '/')
    parts = rel.split('/')
    if parts[0] == 'kungfu' and len(parts) >= 4 and parts[1] == 'class':
        return parts[2]                       # kungfu/class/shaolin/... -> shaolin
    if parts[0] == 'clone' and len(parts) >= 3:
        return parts[1]                       # clone/quarry/...    -> quarry
    if parts[0] in ('d', 'b') and len(parts) >= 3:
        return parts[1]                       # d/beijing/npc/...   -> beijing
    return parts[-2]


def shared_id(lpc_path, bare):
    return '%s_%s' % (source_prefix(lpc_path), bare)


def list_bounds(block, key):
    """(head_end, close, pre_ws) for `key = [ ... ]` inside one UCL block.

    The whitespace between the last ref and the ']' has to be carried across:
    the converter glues it on ("{ id = items.x.id }    ]"), and dropping it
    would reflow a line the pass is not supposed to touch.
    """
    km = re.search(r'^[ \t]*%s\s*=\s*\[' % key, block, re.M)
    if not km:
        return None
    close = block.rindex(']')
    # everything between the last real character and the ']' -- newlines
    # included, because the converter puts ']' on its own line whenever the
    # list has more than one entry and glues it on for a single one
    pre_ws = re.search(r'\s*$', block[km.end():close]).group(0)
    return km.end(), close, pre_ws


def join_refs(refs, pre_ws):
    """Re-render a ref list the way the converter wrote it."""
    indent = re.match(r'^[ \t]*', refs[0][1]).group(0)
    return '\n' + ',\n'.join(indent + t.strip() for _n, t in refs) + pre_ws


def rewrite_list(block, key, drop):
    """Drop refs from the `key = [ ... ]` list, keeping the file's own style.

    Only the lines named in `drop` are removed; everything else is carried
    across byte for byte.  Re-rendering the list from the parsed refs would
    silently drop the entries REF_LINE cannot see -- random() candidate
    groups ("{ id = [a, b, c] }") and global.items refs live there too.

    Returns (new_block, removed_count).  new_block == '' means the list emptied
    and the caller should drop the whole block.  (None, 0) means nothing to do.
    """
    bounds = list_bounds(block, key)
    if not bounds:
        return None, 0
    head_end, close, pre_ws = bounds
    body = block[head_end:close]

    kept, removed = [], 0
    for line in body.split('\n'):
        m = REF_LINE.match(line)
        if m and m.group(2) == key and m.group(3) in drop:
            removed += 1
            continue
        kept.append(line)
    if not removed:
        return None, 0

    while kept and not kept[0].strip():      # the newline head_end left behind
        kept.pop(0)
    while kept and not kept[-1].strip():     # pre_ws carries these instead
        kept.pop()
    if not kept:
        return '', removed
    # dropping a middle entry leaves its predecessor's comma dangling, and
    # elias rejects a trailing comma
    kept[-1] = re.sub(r',[ \t]*$', '', kept[-1])
    return (block[:head_end] + '\n' + '\n'.join(kept) + pre_ws
            + block[close:], removed)


_src_objects = {}


def source_objects(room_src):
    """[(world_id, lpc_path)] for one room source, via lpc_paths' resolver.

    Reading the raw source with lpc_paths.entries_of/expand is what makes
    CLASS_D() and __DIR__ work; going through the AST's own key extractor does
    not reproduce these ids, so do it this way and let _room_id_from_path --
    the same function the converter used to mint the ids -- confirm the match.
    """
    if room_src in _src_objects:
        return _src_objects[room_src]
    text, _nl = read(room_src)
    out = []
    for entry in entries_of(text):
        x = expand(entry)
        if x is None:
            continue
        if x.startswith('DIR:'):
            rel = x[4:]
            full = os.path.dirname(room_src).replace('\\', '/') + '/' + rel
        else:
            rel, full = x, x
        out.append((C._room_id_from_path(rel), lpc_path_for(full)))
    _src_objects[room_src] = out
    return out


def find_lpc_for_id(world_id, room_src):
    for got, lp in source_objects(room_src):
        if got == world_id and lp:
            return lp
    return None


# ---------------------------------------------------------------------------
# definition generation
# ---------------------------------------------------------------------------

BRAIN_DIR = 'data/brains'
BRAIN_NOTE = ('  # brain = brains.%s  <- 转换器 infer_brain 编造，data/brains '
              '无此定义；注释掉前后都是 NullNode（见 '
              'docs/lpc-port-gaps.zh-CN.md §一之一）')


def comment_missing_brains(body):
    """Match the repo's handling of _infer_brain's invented brain names.

    data/brains only defines heihu / town_crier / villager, and clone_lib's
    existing entries already carry the brain commented out with that note
    rather than emitting a reference that resolves to nothing.
    """
    def sub(m):
        brain = m.group(1)
        if os.path.exists(os.path.join(BRAIN_DIR, brain + '.ucl')):
            return m.group(0)
        return BRAIN_NOTE % brain

    return re.sub(r'^  brain = brains\.(\w+)$', sub, body, flags=re.M)


def npc_ucl(lpc_path, npc_id):
    """C._generate_npc_ucl() plus the aliases it deliberately drops.

    _generate_npc_ucl reproduces a converter bug on purpose (its comment about
    the aliases rebinding inside an `if` block whose scope discards it).  These
    blocks are new rather than a regeneration, and a person with no aliases
    cannot be looked at or fought by name, so put them back -- with the world id
    first, the way clone_lib's existing entries do.
    """
    ast = parse_lpc(lpc_path)
    body = C._generate_npc_ucl(ast, 'clone_lib')

    # _generate_npc_ucl derives the id from the file's own basename, which would
    # put a bare id in the shared layer; the caller needs the prefixed one.
    body = re.sub(r'^(    characters\s+)"[^"]+"(\s*\{)',
                  lambda m: '%s"%s"%s' % (m.group(1), npc_id, m.group(2)),
                  body, count=1, flags=re.M)

    aliases = [npc_id]
    for a in (ast.create_fn.get('set_name') or {}).get('aliases') or []:
        s = C._extract_string(a, None)
        if s and s != npc_id and s not in aliases:
            aliases.append(s)
    line = '      aliases = [%s]\n' % ', '.join('"%s"' % a for a in aliases)

    m = re.search(r'^(      name = .*\n)', body, re.M)
    if m:
        body = body[:m.end()] + line + body[m.end():]
    return comment_missing_brains(body)


def item_ucl(lpc_path):
    return C._generate_item_ucl(parse_lpc(lpc_path), 'clone_lib')


# ---------------------------------------------------------------------------
# the pass
# ---------------------------------------------------------------------------

def main():
    files = sorted(f for f in os.listdir(WORLD) if f.endswith('.ucl'))
    zones = {}
    for f in files:
        text, _nl = read(os.path.join(WORLD, f))
        zones[f[:-4]] = {
            'file': f,
            'text': text,
            'items': set(ITEM_BLOCK.findall(text)),
            'characters': set(CHAR_BLOCK.findall(text)),
        }
    lib_items = zones['clone_lib']['items']
    lib_chars = zones['clone_lib']['characters']

    moves = []            # (zone, room, npc_id, lpc_path)
    undecidable = defaultdict(list)
    edits = defaultdict(list)          # zone -> [(start, end, replacement)]
    new_chars, new_items = {}, {}
    unsatisfiable = []

    for zid in sorted(zones):
        if zid == 'clone_lib' or (ONLY and zid not in ONLY):
            continue
        text = zones[zid]['text']
        srcs = room_sources(text)

        item_blocks, char_blocks = {}, {}
        for m in ROOM_ITEMS_HDR.finditer(text):
            item_blocks.setdefault(m.group(1), block_span(text, m))
        for m in ROOM_CHARS_HDR.finditer(text):
            char_blocks.setdefault(m.group(1), block_span(text, m))

        for room, (istart, iend) in sorted(item_blocks.items()):
            src = srcs.get(room)
            if not src or not os.path.exists(src):
                continue
            block = text[istart:iend]

            is_npc = []
            for m in REF_LINE.finditer(block):
                if m.group(2) != 'items':
                    continue
                bare = m.group(3)
                lp = find_lpc_for_id(bare, src)
                # an id the zone itself defines as a person, and that nothing
                # defines as an object, is a person wherever the ref sits --
                # this is what rescues the mingjiao refs whose .c files are
                # gone from the LPC tree while their definitions survived here
                local_person = (bare in zones[zid]['characters']
                                and bare not in zones[zid]['items']
                                and bare not in lib_items)
                if lp is None:
                    if local_person:
                        is_npc.append((bare, bare))
                    else:
                        undecidable['no LPC source found'].append(
                            (zid, room, bare))
                    continue
                verdict = resolve_lpc_type(lp)
                if verdict != 'npc':
                    if verdict == 'generic':
                        undecidable['type=%s' % verdict].append((zid, room, bare))
                    continue                      # item/room/skill: already right

                # the zone's own definition keeps the bare id and resolves
                # locally; otherwise the shared copy needs the source prefix
                if bare in zones[zid]['characters']:
                    target = bare
                else:
                    target = shared_id(lp, bare)
                    if target not in lib_chars and target not in new_chars:
                        new_chars[target] = (lp, npc_ucl(lp, target))
                is_npc.append((bare, target))

            if not is_npc:
                continue

            rebuilt, removed = rewrite_list(block, 'items',
                                            {b for b, _t in is_npc})
            assert removed == len(is_npc), 'rewrite_list removed %d of %d' % (
                removed, len(is_npc))

            char_edits = []
            if room in char_blocks:
                cstart, cend = char_blocks[room]
                cblock = text[cstart:cend]
                bounds = list_bounds(cblock, 'characters')
                if bounds:
                    head_end, close, pre_ws = bounds
                    body = cblock[head_end:close]
                    # append after the last real entry rather than
                    # re-rendering, so anything REF_LINE cannot parse
                    # survives untouched
                    seen = {m.group(3) for m in REF_LINE.finditer(body)
                            if m.group(2) == 'characters'}
                    add = [t for _b, t in is_npc if t not in seen]
                    if add:
                        tail = ''.join(
                            ',\n      { id = characters.%s.id }' % t
                            for t in add)
                        char_edits.append(
                            (cstart, cend,
                             cblock[:close].rstrip() + tail + pre_ws
                             + cblock[close:]))
                else:
                    # a room_characters block with no `characters = [` to
                    # append to. Moving anyway would drop the NPC on the
                    # floor, so leave the room alone entirely.
                    undecidable['room_characters has no list'].append(
                        (zid, room, is_npc[0][0]))
                    continue
            else:
                # create it where _generate_room_objects puts it: before
                # room_items. elias rejects a trailing comma, so build the list
                # through join_refs rather than one ",n"-terminated line each.
                lines = [(t, '      { id = characters.%s.id }' % t)
                         for _b, t in is_npc]
                new_cblock = ('  room_characters "%s" {\n'
                              '    room_id = rooms.%s.id\n'
                              '    characters = [%s    ]\n  }\n\n'
                              % (room, room, join_refs(lines, '')))
                char_edits.append((istart, istart, new_cblock))

            # rebuilt is '' when the items list emptied out: drop the block, and
            # with it the blank lines it leaves behind, keeping the one
            # separator line the file already had there.
            if rebuilt:
                edits[zid].append((istart, iend, rebuilt))
            else:
                tail = text[iend:]
                surplus = len(tail) - len(tail.lstrip('\n'))
                edits[zid].append((istart, iend + max(surplus - 1, 0), ''))
            edits[zid].extend(char_edits)

            for bare, target in is_npc:
                # '' marks a ref rescued by the zone's own definition, whose
                # LPC source no longer exists -- there is no file to point at
                moves.append((zid, room, bare, target,
                              find_lpc_for_id(bare, src) or ''))

    # ---------------------------------------------------------------- report
    print('refs to move to room_characters : %d' % len(moves))
    print('rooms affected                  : %d'
          % len({(z, r) for z, r, _b, _t, _p in moves}))
    print('zones touched                   : %d' % len(edits))
    print('new characters definitions      : %d' % len(new_chars))
    kept_bare = [m for m in moves if m[2] == m[3]]
    print('refs keeping the zone-local bare id: %d' % len(kept_bare))
    print()
    print('left alone (resolver not confident): %d' % sum(
        len(v) for v in undecidable.values()))
    for reason in sorted(undecidable):
        v = undecidable[reason]
        print('   %-22s %d' % (reason, len(v)))
        for zid, room, name in v[:6]:
            print('        %s/%s %s' % (zid, room, name))
    print()

    by_dir = defaultdict(int)
    by_zone = defaultdict(int)
    for zid, _room, _bare, _target, lp in moves:
        if not lp:
            continue
        rel = os.path.relpath(lp, LPC_ROOT).replace('\\', '/')
        by_dir['/'.join(rel.split('/')[:3])] += 1
        by_zone[zid] += 1
    print('moves by zone (smallest first):')
    for zid, n in sorted(by_zone.items(), key=lambda x: x[1]):
        print('   %-28s %d' % (zid, n))
    print()
    print('moves by LPC directory:')
    for d, n in sorted(by_dir.items(), key=lambda x: -x[1]):
        print('   %-28s %d' % (d, n))
    print()

    # Audit: every move must rest on an inherit chain that really is a person.
    # If _determine_object_type's own verdicts and the inherit-chain fallback
    # disagree, or an unexpected base shows up, that is where a wrong move would
    # come from -- so print the chains instead of trusting them.
    by_inherit = defaultdict(int)
    for _z, _r, _b, _t, lp in moves:
        if not lp:
            by_inherit[('<zone-local definition, LPC source gone>',)] += 1
            continue
        try:
            ast = parse_lpc(lp)
            chain = tuple(ast.inherits)
        except Exception:
            chain = ('<unparsed>',)
        by_inherit[chain] += 1
    print('moves by the target\'s own inherit chain:')
    for chain, n in sorted(by_inherit.items(), key=lambda x: -x[1]):
        print('   %-46s %d' % (','.join(chain), n))
    print()

    if not APPLY:
        print('dry run; pass --apply to write the zone files')
        return

    for zid in sorted(edits):
        path = os.path.join(WORLD, zones[zid]['file'])
        text, nl = read(path)
        for start, end, repl in sorted(edits[zid], reverse=True):
            text = text[:start] + repl + text[end:]
        write(path, text, nl)
    print('rewrote %d zone files' % len(edits))

    if WRITE_DEFS and new_chars:
        text, nl = read(CLONE_LIB)
        # every pre-existing top-level block in clone_lib is separated by
        # exactly one blank line, so match that: each entry already ends with
        # "}\n", and joining on "\n" leaves precisely one blank line between.
        entries = ['# LPC: %s\n%s\n'
                   % (re.sub(r'/{2,}', '/', lp.replace('\\', '/')),
                      ucl.rstrip('\n'))
                   for _n, (lp, ucl) in sorted(new_chars.items())]
        write(CLONE_LIB, text.rstrip('\n') + '\n\n' + '\n'.join(entries), nl)
        print('appended %d characters to clone_lib.ucl' % len(new_chars))


main()