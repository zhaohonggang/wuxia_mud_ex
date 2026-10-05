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