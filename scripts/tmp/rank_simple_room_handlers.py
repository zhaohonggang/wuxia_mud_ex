"""Rank per-room do_* bodies by porting simplicity for P5-1b-3 E2E template.

Strategy:
- For each of the 304 backfilled candidate rooms, find its source .c.
- Source attribution: a `rooms "key" {` block inherits the most recent `# LPC:`
  line that appears BEFORE it (depth 0), OR a `# LPC:` line INSIDE the block
  (depth >= 1) which takes precedence (audit_block_attribution lesson).
- Extract every `do_*` function body, match against the room's UCL `actions`
  verb->handler map.
- Score simplicity: penalize state mutation / LPC queries; reward pure output.
- Print the simplest candidates with full bodies for manual template selection.
"""
import re, glob, json

ROOT = 'C:/files/git'
MUDC = ROOT + '/mud'
PROJ = 'C:/files/git/wuxia_mud_ex'

survey = json.load(open(PROJ + '/scripts/tmp/p5a2_room_actions_survey.json'))
rids = list(survey['room_id_candidates'].keys())


def parse_lpc_from_comment(ln):
    """Extract a relative .c path (to MUDC) from either a
    `# LPC: d/foo/bar.c` or `# Generated from C:/files/git/mud/d/foo/bar.c ...`
    header line. Returns e.g. 'd/foo/bar.c' or None."""
    # Converter style: full windows path
    m = re.search(r'#\s*Generated from\s+(\S+\.c)', ln)
    if m:
        p = m.group(1).replace('\\', '/')
        # strip leading C:/files/git/mud/ if present
        p = re.sub(r'^.*?/mud/', '', p)
        return p
    # audit style: relative path
    m = re.search(r'#\s*LPC:\s*(\S+\.c)', ln)
    if m:
        return m.group(1).replace('\\', '/')
    return None


def find_source_for_room(zone, key):
    """Return the .c path (relative to MUDC) for a given room id `zone:key`."""
    ucl = f'{PROJ}/data/world/{zone}.ucl'
    try:
        lines = open(ucl, encoding='utf-8', errors='replace').read().splitlines()
    except Exception:
        return None
    depth = 0
    cur_src = None          # most recent depth-0 header
    in_block = False
    block_src = None        # header found inside current block
    for ln in lines:
        src = parse_lpc_from_comment(ln)
        if src and depth == 0:
            cur_src = src
        if re.match(r'^\s*rooms\s+"', ln):
            in_block = True
            block_src = None
            depth += 1
            m = re.match(r'^\s*rooms\s+"([^"]+)"', ln)
            if m.group(1) == key:
                return (block_src or cur_src), None
        elif ln.strip() == '}':
            if in_block and depth == 1:
                in_block = False
            if depth > 0:
                depth -= 1
        else:
            if in_block and depth >= 1:
                s2 = parse_lpc_from_comment(ln)
                if s2:
                    block_src = s2
    return None, None


def extract_do_bodies(txt):
    """Return list of (name, body) for every int do_* in the .c text."""
    out = []
    for mt in re.finditer(r'\bint\s+(do_[A-Za-z_]+)\s*\([^)]*\)\s*\{', txt):
        i = txt.index('{', mt.start())
        depth = 0
        j = i
        while j < len(txt):
            ch = txt[j]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = txt[mt.start():j + 1]
        out.append((mt.group(1), body))
    return out


# dangerous patterns that make an E2E port harder
DANGER = [
    'set("exits', 'set("exits/', 'exits', '->set', 'map_delete', 'map_add',
    'add_action', 'add_actions', 'command', 'remove_call_out', 'call_out',
    'set_temp', 'set("born', 'query("born', 'born_family', '->query("born',
    'environment(', 'present(', 'this_object(', 'this_player()->query',
    '->move', 'destruct', 'clone_object', 'new(', 'tell_room',
]


def score(body):
    s = 0
    low = body.lower()
    for d in DANGER:
        if d in body:
            s += 10
    # pure-output helpers are good
    for good in ['message_vision', 'tell_object', 'notify_fail', 'write(', 'say(']:
        if good in body:
            s -= 2
    # number of lines
    s += body.count('\n') * 0.5
    # presence of complex control flow
    if re.search(r'\bif\b', body):
        s += 3
    if re.search(r'\belse\b', body):
        s += 2
    if re.search(r'\bfor\b|\bwhile\b|\bforeach\b', body):
        s += 4
    if 'return' in body:
        s += 1
    return s


candidates = []
for rid in rids:
    zone, key = rid.split(':', 1)
    src, _ = find_source_for_room(zone, key)
    if not src or not src.startswith('d/'):
        continue
    path = MUDC + '/' + src
    try:
        txt = open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    bodies = extract_do_bodies(txt)
    if not bodies:
        continue
    # survey stores the verb->handler map directly as the value
    actions = survey['room_id_candidates'][rid]
    if not isinstance(actions, dict):
        continue
    for name, body in bodies:
        sc = score(body)
        # only consider handlers referenced by this room's actions
        verb = None
        for v, h in actions.items():
            if h == name:
                verb = v
        if verb is None:
            continue
        candidates.append((sc, rid, src, verb, name, body.count('\n'), body))

candidates.sort(key=lambda x: (x[0], x[5]))
print('total referenced do_* bodies among 304 rooms:', len(candidates))
print('=== simplest 20 ===')
for c in candidates[:20]:
    print(f'\n--- score={c[0]:.1f} lines={c[5]} rid={c[1]} verb={c[3]} handler={c[4]} src={c[2]}')
    print(c[6])
