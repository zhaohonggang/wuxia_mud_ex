import re
content = open('data/world/global.ucl').read()
matches = list(re.finditer(r'"\\', content))
for m in matches:
    print(f'Pos {m.start()}: {content[max(0,m.start()-20):m.start()+30]}')