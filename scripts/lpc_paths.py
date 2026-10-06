"""Resolve LPC path expressions in set("objects") before classifying.

Handles the three shapes that show up in the LPC source:
  "/clone/quarry/yang2"                          literal
  __DIR__"npc/yahuan"                             room-relative
  CLASS_D("ouyang") + "/ouyangfeng"              macro-composed
"""
import io
import os
import re

CLASS_D = '/kungfu/class/'


def expand(expr):
    """Turn one set("objects") entry into an absolute LPC path, or None."""
    e = expr.strip()

    m = re.match(r'^CLASS_D\("([^"]+)"\)\s*\+\s*"([^"]+)"$', e)
    if m:
        return '%s%s/%s' % (CLASS_D, m.group(1), m.group(2))

    m = re.match(r'^__DIR__"([^"]+)"$', e)
    if m:
        return 'DIR:' + m.group(1)

    m = re.match(r'^"([^"]+)"$', e)
    if m:
        return m.group(1)

    return None


ENTRY = re.compile(
    r'^(?:__DIR__)?'
    r'(?:CLASS_D\("[^"]+"\)\s*\+\s*)?'
    r'"[^"]+"\s*(?::\s*[^,\)\]]+)?$'
)


COMMENT = re.compile(r'//[^\n]*')


def split_entries(body):
    """Split the (...) of set("objects", ([...])) into raw entry strings."""
    body = COMMENT.sub('', body)
    out = []
    depth = 0
    cur = ''
    for ch in body:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            if cur.strip():
                out.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def strip_count(entry):
    """`CLASS_D("ouyang") + "/ouyangfeng" : 2` -> `CLASS_D("ouyang") + "/ouyangfeng"`."""
    e = entry.strip()
    # the path expression always ends with a quoted string; drop anything after it
    last = e.rfind('"')
    if last == -1:
        return e
    return e[:last + 1].strip()


def entries_of(src_text):
    # A room may call set("objects", ...) more than once -- LPC overwrites, but
    # the converter merged them, so collect every occurrence.
    out = []
    seen = set()
    for m in re.finditer(r'set\(\s*"objects"\s*,\s*\(\[(.*?)\]\)\s*\)',
                         src_text, re.S):
        for e in split_entries(m.group(1)):
            e = strip_count(e)
            # dedupe: LPC often repeats an object, and a room with two
            # set("objects") blocks can list the same path twice
            if ENTRY.fullmatch(e) and e not in seen:
                seen.add(e)
                out.append(e)
    return out


def classify(path):
    """-> (root, zone, basename) for an absolute LPC object path."""
    r = path.lstrip('/')
    parts = r.split('/')
    base = parts[-1]

    if parts[0] == 'clone':
        return ('clone', 'clone/' + parts[1] if len(parts) > 2 else 'clone', base)

    # /kungfu/class/<cls>/<file>
    if len(parts) >= 4 and parts[0] == 'kungfu' and parts[1] == 'class':
        return ('kungfu', 'kungfu/class/' + parts[2], base)

    # /u/<user>/obj|item/<file>
    if len(parts) >= 4 and parts[0] == 'u' and parts[2] in ('obj', 'item'):
        return ('item', 'u/' + parts[1], base)

    # /b/<branch>/npc/<file>
    if len(parts) >= 4 and parts[0] in ('b', 'd') and parts[2] == 'npc':
        return ('npc', parts[1], base)

    # /d/<zone>/obj|item/<file>
    m = re.match(r'([a-z]+)/([^/]+)/(?:obj|item)/(.+)$', r)
    if m:
        return ('item', m.group(2), base)

    # /d/<zone>/<file>
    m = re.match(r'([a-z]+)/(?:obj|item)/(.+)$', r)
    if m:
        return ('item', m.group(1), base)

    m = re.match(r'([a-z]+)/([^/]+)/npc/(.+)$', r)
    if m:
        return ('npc', m.group(2), base)

    # /d/<zone>/<subdir>/<file>  e.g. /d/hangzhou/honghua/huo
    m = re.match(r'([a-z]+)/([^/]+)/([^/]+)/(.+)$', r)
    if m:
        return ('npc', m.group(2), base)

    if '/' not in r:
        return ('bare', None, base)

    return ('?', None, base)


def lpc_objects(path, room_zone):
    if not path or not os.path.exists(path):
        return []
    s = io.open(path, encoding='utf-8', errors='replace').read()
    out = []
    for e in entries_of(s):
        p = expand(e)
        if p is None:
            out.append(('MACRO', None, e))
            continue
        if p.startswith('DIR:'):
            rel = p[4:]
            sub = rel.split('/')[0]
            kind = 'npc' if sub == 'npc' else 'item'
            out.append((kind, room_zone, rel.split('/')[-1]))
            continue
        out.append(classify(p))
    return out


# ---------------------------------------------------------------------------
# Type resolution: is this LPC file a person, an item, a room or a skill?
#
# This is the authoritative answer, shared by lpc_converter (so a future
# conversion files NPCs correctly) and by the migration scripts.  It lives here
# rather than in either one because both need it and neither should own it.
#
# lpc_converter._determine_object_type/1 works on an AST and answers "generic"
# for `inherit QUARRY;` because the marker itself names no type -- the type
# lives one hop up, in mud/inherit/char/quarry.c (`inherit NPC;`).  So a
# "generic" verdict falls through to a walk over the base classes.
LPC_ROOT = os.environ.get('MUD_LPC_ROOT', r'C:\files\git\mud')

_inherit_index = None
_type_cache = {}


def inherit_index():
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


def find_inherit_file(name):
    key = name.strip().lower()
    return inherit_index().get(key[:-2] if key.endswith('.c') else key)


def _with_c(p):
    return p if p.endswith('.c') else p + '.c'


def object_file(expr, src_dir):
    """Absolute LPC file for one set("objects") entry, or None.

    `src_dir` is the directory of the file that wrote the entry, which is what
    __DIR__ means.  All three spellings from `expand()` are handled, plus the
    .c suffix each of them usually omits.
    """
    if not expr:
        return None
    e = expr.strip()

    m = re.match(r'^CLASS_D\("([^"]+)"\)\s*\+\s*"([^"]+)"$', e)
    if m:
        return os.path.normpath(os.path.join(
            LPC_ROOT, 'kungfu', 'class', m.group(1), _with_c(m.group(2))))

    m = re.match(r'^__DIR__\s*"([^"]+)"$', e)
    if m:
        return os.path.normpath(os.path.join(src_dir, _with_c(m.group(1))))

    # A bare path, quoted or not.
    #
    # The unquoted form is the one that actually reaches us in practice:
    # lpc_converter._extract_key_path/1 returns the *contents* of the string
    # literal, so `"npc/x" : 1` arrives as `npc/x`.  Only the quoted spelling used
    # to be accepted, which meant object_file/2 returned None for every entry and
    # _object_is_npc/3 fell through to its `"npc" in path` guess for all of them
    # -- so the inherit-chain verdict never ran outside of `__DIR__"..."` files.
    p = e
    if len(p) >= 2 and p[0] == p[-1] and p[0] in "\"'":
        p = p[1:-1]

    # Anything with an operator or bracket in it is an expression we cannot pin
    # to one file; returning a bogus path here would be worse than None.
    # `/` and `-` are legitimate in LPC paths (shaolin/dao-yi, npc/li), so they
    # are deliberately not in this set.
    if not p or re.search(r'[\s()\[\]{}+<>=!&|?,;]', p):
        return None

    if p.startswith('/'):
        return os.path.normpath(os.path.join(
            LPC_ROOT, _with_c(p.lstrip('/'))))

    return os.path.normpath(os.path.join(src_dir, _with_c(p)))


def resolve_type(path, depth=0):
    """'npc' | 'item' | 'room' | 'skill' | 'generic' for one LPC file.

    Same verdict as lpc_converter._determine_object_type/1 except that
    "generic" now falls through to the file's own base classes, which is what
    makes `inherit QUARRY;` (mud/inherit/char/quarry.c, itself `inherit NPC;`)
    come out as npc instead of an object nothing can be spawned from.
    """
    # Imported here, not at module level: lpc_converter imports this module, so
    # a top-level import would be circular.
    import lpc_converter as C

    if path in _type_cache:
        return _type_cache[path]
    if depth > 8 or not path or not os.path.exists(path):
        return 'generic'

    _type_cache[path] = 'generic'                     # cycle guard
    try:
        with open(path, 'rb') as f:
            ast = C._parse_lpc(f.read(), path, os.path.dirname(path))
    except Exception:
        return 'generic'
    if ast is None:
        return 'generic'

    verdict = C._determine_object_type(C._merge_inherit_chain(ast))
    if verdict != 'generic':
        _type_cache[path] = verdict
        return verdict

    for inh in ast.inherits or []:
        base = find_inherit_file(inh)
        if base and os.path.normcase(base) != os.path.normcase(path):
            got = resolve_type(base, depth + 1)
            if got != 'generic':
                _type_cache[path] = got
                return got

    # mud/inherit/char/npc.c is `inherit CHARACTER;`, and CHARACTER is neither
    # a type marker nor a file under mud/inherit/, so the walk above reaches
    # nothing from it.  Nothing in the corpus inherits that file directly, so
    # this is latent rather than live -- but the directory is unambiguous, so
    # answer from it.
    if os.path.normcase(os.path.dirname(path)) == os.path.normcase(
            os.path.join(LPC_ROOT, 'inherit', 'char')):
        _type_cache[path] = 'npc'
        return 'npc'

    return 'generic'