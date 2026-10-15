import re

src = open(r'C:/files/git/mud/kungfu/skill/tonggui-jian/fen.c', encoding='utf-8').read()

defs = {}
for m in re.finditer(r'^\s*#\s*define\s+(\w+)\s+(.+?)\s*$', src, re.M):
    strs = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
    if strs:
        defs[m.group(1)] = ''.join(strs)

s = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
s = re.sub(r'^\s*#[^\n]*$', '', s, flags=re.M)

for name, val in sorted(defs.items(), key=lambda kv: -len(kv[0])):
    lit = '"%s"' % val.replace("\\", "\\\\").replace('"', '\\"')
    s = re.sub(r'\b%s\b' % re.escape(name), lit, s)

s = re.sub(r'//[^\n]*', '', s)

COLORS = {"NOR","HIR","HIG","HIY","HIB","HIM","HIC","HIW","HIK","RED","GRN","YEL","BLU","MAG","CYN","WHT","BLK","BOLD","BLINK","REV","HBRED","HBGRN","HBYEL","HBBLU","HBMAG","HBCYN","HBWHT","HBBLK"}

toks = re.split(r'("(?:[^"\\]|\\.)*")', s)
parts = []
for t in toks:
    if t.startswith('"') and t.endswith('"'):
        parts.append(t)
    else:
        parts.append(re.sub(r'\b(%s)\b' % "|".join(COLORS), '', t))

s = "".join(parts)

def join_adjacent(s):
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r'"\s*((?:[^"\\]|\\.)*)"[ \t\r\n]*"((?:[^"\\]|\\.)*)"', lambda m: '"' + m.group(1) + m.group(2) + '"', s)
    return s

s = join_adjacent(s)

msgs = [x for x in re.findall(r'"((?:[^"\\]|\\.)*)"', s) if re.search(r'[\u4e00-\u9fff]', x)]

for m in msgs:
    print(repr(m))