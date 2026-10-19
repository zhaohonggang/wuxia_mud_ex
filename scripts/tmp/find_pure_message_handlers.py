"""Find PURE message-only room handlers (message_vision / write only, no state)
on NON-global verbs. Output candidate (room_id, verb, handler, mode, text) as JSON.

"Pure" = body contains message_vision(...) and/or write(...), and NO state mutation,
NO LPC query on this_player/this_object, NO damage/skill/move/present/random etc.
Used to populate the data-driven MessageOnly handler map.
"""
import re, json, os

exec(open('scripts/tmp/rank_simple_room_handlers.py').read().split('# candidates = []')[0])

PROJ = 'C:/files/git/wuxia_mud_ex'
MUDC = 'C:/files/git/mud'
survey = json.load(open(PROJ + '/scripts/tmp/p5a2_room_actions_survey.json'))
glob = set(re.findall(r'parse\(\s*"([^"]+)"', open(PROJ + '/lib/kantele/character/commands.ex', encoding='utf-8', errors='replace').read()))

# Things that make a handler NOT pure-message
BAD = [
    'set(', 'delete(', 'exits', '->query', 'query_skill', 'improve_skill',
    'receive_damage', 'add(', '->move', 'move(', 'destruct', 'new(', 'clone_object',
    'call_out', 'remove_call_out', 'command(', 'add_action', 'present(', 'environment(',
    'random(', 'this_object(', 'tell_object', 'tell_room', 'notify_fail',
    'map_delete', 'map_add', 'set_temp', 'query_temp', '->name(', '->short(',
    'combat_exp', 'qi', 'jing', 'force', 'damage', 'can_improve_skill', 'skill',
]

def lpc_strings(body):
    """Extract concatenated LPC string literal content from a body (best-effort)."""
    # join adjacent string literals separated by whitespace/newlines
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', body)
    if not parts:
        return None
    # unescape common LPC escapes
    txt = ''.join(parts)
    txt = txt.replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"')
    return txt

def clean_message(body):
    """Return (mode, text) if body is a pure message handler else None.
    mode = 'vision' if message_vision, else 'player' for write."""
    low = body
    for b in BAD:
        if b in low:
            return None
    has_vision = 'message_vision' in body
    has_write = re.search(r'\bwrite\s*\(', body) is not None
    if not (has_vision or has_write):
        return None
    # exactly one output call preferred
    if has_vision and has_write:
        return None
    # extract the call's string arg
    if has_vision:
        m = re.search(r'message_vision\s*\(', body)
        start = m.end()
    else:
        m = re.search(r'\bwrite\s*\(', body)
        start = m.end()
    # find balanced parens of the call
    depth = 1
    j = start
    while j < len(body) and depth > 0:
        if body[j] == '(':
            depth += 1
        elif body[j] == ')':
            depth -= 1
        j += 1
    call_args = body[start:j-1]
    # for message_vision, first arg is the message (may be concatenated literals)
    # strip trailing , me / , this_player() etc.
    txt = lpc_strings(call_args)
    if not txt:
        return None
    # only $N substitution supported; drop other $ markers if present (skip candidate)
    if re.search(r'\$[A-Za-z]', txt.replace('$N', '')):
        return None
    mode = 'vision' if has_vision else 'player'
    return mode, txt

out = []
rids = list(survey['room_id_candidates'].keys())
for rid in rids:
    zone, key = rid.split(':', 1)
    src, _ = find_source_for_room(zone, key)
    if not src or not src.startswith('d/'):
        continue
    p = MUDC + '/' + src
    if not os.path.exists(p):
        continue
    txt = open(p, encoding='utf-8', errors='replace').read()
    actions = survey['room_id_candidates'][rid]
    if not isinstance(actions, dict):
        continue
    for name, body in extract_do_bodies(txt):
        for verb, h in actions.items():
            if h != name or verb in glob:
                continue
            cm = clean_message(body)
            if cm is None:
                continue
            mode, msg = cm
            out.append({'room': rid, 'verb': verb, 'handler': name, 'mode': mode, 'text': msg, 'src': src})

out.sort(key=lambda x: (x['mode'], len(x['text'])))
print('pure message-only non-global candidates:', len(out))
for o in out:
    print('=== %s | %s | %s | %s' % (o['room'], o['verb'], o['handler'], o['mode']))
    print('    TEXT: ' + repr(o['text'])[:300])
json.dump(out, open(PROJ + '/scripts/tmp/pure_message_candidates.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('saved -> scripts/tmp/pure_message_candidates.json')
