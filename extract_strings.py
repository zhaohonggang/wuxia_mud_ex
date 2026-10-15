import re

src = open(r'C:/files/git/mud/kungfu/skill/tonggui-jian/fen.c', encoding='utf-8').read()

# Extract the exact notify_fail strings
for m in re.finditer(r'notify_fail\((.+?)\)', src):
    s = m.group(1)
    # Evaluate the string concatenation
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', s)
    if parts:
        full = ''.join(parts)
        print(repr(full))
        # Also show bytes
        print(full.encode('utf-8'))