"""List next-batch candidates: room do_* handlers that are NOT pure-message and
NOT on a global verb, sorted by complexity. Excludes already-ported ones.

Already ported (room-scoped registry): huashan:lianhua, emei:shierpan3,
hangzhou:liuzhuang, huanggong:inwell, baituo:neishi, chengdu:guangchang,
register:prison.
"""
import re, json, sys

sys.path.insert(0, 'C:/files/git/wuxia_mud_ex/scripts/tmp')
from rank_simple_room_handlers import (  # noqa: E402
    survey, rids, find_source_for_room, extract_do_bodies, MUDC, score, DANGER,
)

PORTED = {
    'huashan:lianhua', 'emei:shierpan3', 'hangzhou:liuzhuang',
    'huanggong:inwell', 'baituo:neishi', 'chengdu:guangchang',
    'register:prison',
}

GLOBAL_VERBS = {
    'look', 'say', 'get', 'drop', 'put', 'give', 'eat', 'drink', 'fight',
    'kill', 'open', 'close', 'go', 'north', 'south', 'east', 'west', 'up',
    'down', 'inventory', 'score', 'help', 'quit', 'sleep', 'wake', 'wear',
    'wield', 'unwield', 'remove', 'suicide', 'who', 'tell', 'shout', 'ask',
    'buy', 'sell', 'list', 'search', 'steal', 'sit', 'stand', 'exert',
}

rows = []
for rid in rids:
    if rid in PORTED:
        continue
    zone, key = rid.split(':', 1)
    src, _ = find_source_for_room(zone, key)
    if not src or not src.startswith('d/'):
        continue
    try:
        txt = open(MUDC + '/' + src, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    actions = survey['room_id_candidates'][rid]
    if not isinstance(actions, dict):
        continue
    for name, body in extract_do_bodies(txt):
        verb = next((v for v, h in actions.items() if h == name), None)
        if verb is None or verb in GLOBAL_VERBS:
            continue
        low = body
        # skip pure-message only (already covered by MessageOnly table)
        mutating = any(k in low for k in (
            'set(', 'query(', 'move', 'destruct', 'call_out', 'command(',
            'clone', 'new(', 'tell_room', 'add_action', 'map_add', 'map_delete',
        ))
        rows.append({
            'score': score(body), 'room': rid, 'verb': verb, 'handler': name,
            'src': src, 'lines': body.count('\n'), 'mutating': mutating,
            'body': body,
        })

rows.sort(key=lambda r: (r['score'], r['lines']))
print('candidates:', len(rows))
print('mutating:', sum(1 for r in rows if r['mutating']))
print('pure    :', sum(1 for r in rows if not r['mutating']))
print()
for r in rows[:14]:
    print('=' * 78)
    print(f"score={r['score']:.1f} lines={r['lines']} room={r['room']} "
          f"verb={r['verb']} handler={r['handler']} mut={r['mutating']}")
    print(f"src={r['src']}")
    print(r['body'])
json.dump(rows, open('C:/files/git/wuxia_mud_ex/scripts/tmp/next_state_candidates.json',
                     'w', encoding='utf-8'), ensure_ascii=False, indent=1)
