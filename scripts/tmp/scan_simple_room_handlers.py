import re, glob, json

d = json.load(open('scripts/tmp/p5a2_room_actions_survey.json'))
cands = d['room_id_candidates']

# room_id -> source .c via UCL # LPC: header
room2c = {}
for ucl in glob.glob('data/world/*.ucl'):
    zone = re.sub(r'\.ucl', '', ucl.split('/')[-1])
    t = open(ucl, encoding='utf-8', errors='replace').read().splitlines()
    cur_lpc = None
    for line in t:
        m = re.search(r'# LPC:\s*(\S+)\s*\(', line)
        if m:
            cur_lpc = m.group(1)
        m2 = re.search(r'^rooms\s+"([^"]+)"', line)
        if m2:
            rid = zone + ':' + m2.group(1)
            room2c[rid] = cur_lpc

simple = []
for rid, c in room2c.items():
    if rid not in cands:
        continue
    if not c or not c.startswith('d/'):
        continue
    path = '/c/files/git/mud/' + c
    try:
        txt = open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        continue
    for mt in re.finditer(r'int\s+(do_[a-z_]+)\s*\([^)]*\)\s*\{', txt):
        i = txt.index('{', mt.start())
        depth = 0
        j = i
        while j < len(txt):
            if txt[j] == '{':
                depth += 1
            elif txt[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = txt[mt.start():j + 1]
        if 'set(' in body or 'exits' in body or '->query' in body:
            continue
        if not ('message_vision' in body or 'tell_object' in body or 'write' in body or 'say' in body):
            continue
        if body.count('\n') > 7:
            continue
        simple.append((body.count('\n'), rid, c, mt.group(1), body))

simple.sort()
print('simple backfilled room message-only handlers:', len(simple))
for s in simple[:12]:
    print('===' + str(s[1]) + ' handler=' + s[3])
    print('   ' + s[4].replace('\n', ' / ')[:300])
