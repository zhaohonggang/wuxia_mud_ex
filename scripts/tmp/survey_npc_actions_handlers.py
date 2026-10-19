"""P5-1 勘查（NPC 通道）：把 UCL 里 NPC 的 add_actions（只有 verb）回源成 verb→handler。

背景：冻结转换器把 NPC 的 `add_action(handler, verb)` 写进 UCL
`init = { add_actions = ["bian", ...] }`，但**只留了 verb、丢了 handler**
（loader 已读入 verbs，见 loader.parse_enter_init/1）。要做对象级分发，
必须知道每个 verb 对应哪个 handler 函数。

做法：
1. 扫所有 UCL 的 `characters "<key>" { ... }` 块，取出 init.add_actions 列表。
2. 用与 room 相同的「# Generated from <path>.c」注释归属规则找到该块的源 .c
   （块内注释优先，否则取块前最近的 depth-0 注释）。
3. 解析源 .c 里所有 `add_action("handler", "verb")`，建 verb→handler 映射。
4. 统计：命中 / 未命中（verb 在源里找不到）、一个 verb 多 handler（条件注册）、
   源文件缺失等。

只读，输出 tmp/survey_npc_actions_handlers.json + 终端摘要。
"""
import json
import os
import re
import glob

PROJ = 'C:/files/git/wuxia_mud_ex'
MUDC = 'C:/files/git/mud'
OUT = PROJ + '/scripts/tmp/survey_npc_actions_handlers.json'


def parse_lpc_from_comment(ln):
    m = re.search(r'#\s*Generated from\s+(\S+\.c)', ln)
    if m:
        p = m.group(1).replace('\\', '/')
        return re.sub(r'^.*?/mud/', '', p)
    m = re.search(r'#\s*LPC:\s*(\S+\.c)', ln)
    if m:
        return m.group(1).replace('\\', '/')
    return None


def find_source(lines, block_start):
    """取块起点之前**最近**的 `# Generated from` 注释。

    UCL 里每个 `rooms`/`characters` 块前都紧跟着自己的源文件注释，
    所以「最近的上一条 header」就是该块的源文件。不要用花括号深度做门控：
    description 等字符串里可能出现花括号，会让深度计数漂移。
    """
    for idx in range(block_start - 1, -1, -1):
        src = parse_lpc_from_comment(lines[idx])
        if src:
            return src
    return None


ADD_ACTION = re.compile(r'add_action\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')


def handlers_from_source(path):
    try:
        txt = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return None
    out = {}
    for handler, verb in ADD_ACTION.findall(txt):
        out.setdefault(verb, []).append(handler)
    return out


def blocks_of(lines, keyword):
    """yield (key, start_index) for `keyword "<key>" {`"""
    pat = re.compile(r'^\s*' + keyword + r'\s+"([^"]+)"\s*\{')
    for idx, ln in enumerate(lines):
        m = pat.match(ln)
        if m:
            yield m.group(1), idx


def actions_of(lines, start):
    """从块起点向下找 init = { add_actions = [ ... ] }"""
    depth = 0
    in_block = False
    joined = []
    for idx in range(start, len(lines)):
        ln = lines[idx]
        if not in_block:
            if re.search(r'\badd_actions\s*=\s*\[', ln):
                in_block = True
                joined.append(ln)
                if ']' in ln:
                    break
            continue
        joined.append(ln)
        if ']' in ln:
            break
    text = ' '.join(joined)
    return re.findall(r'"([^"]+)"', text)


records = []
missing_source = []
unmatched = []

for ucl in sorted(glob.glob(PROJ + '/data/world/*.ucl')):
    zone = os.path.basename(ucl)[:-4]
    lines = open(ucl, encoding='utf-8', errors='replace').read().splitlines()
    for key, start in blocks_of(lines, 'characters'):
        verbs = actions_of(lines, start)
        if not verbs:
            continue
        src = find_source(lines, start)
        rec = {
            'npc_id': f'{zone}:{key}',
            'src': src,
            'verbs': verbs,
            'mapping': {},
            'note': None,
        }
        if not src:
            rec['note'] = 'no_source'
            missing_source.append(rec['npc_id'])
        else:
            path = MUDC + '/' + src
            mapping = handlers_from_source(path)
            if mapping is None:
                rec['note'] = 'source_missing'
                missing_source.append(rec['npc_id'])
            else:
                for v in verbs:
                    if v in mapping:
                        rec['mapping'][v] = mapping[v]
                    else:
                        unmatched.append((rec['npc_id'], v))
                        rec['mapping'][v] = []
        records.append(rec)

total_verbs = sum(len(r['verbs']) for r in records)
matched = sum(1 for r in records for v, h in r['mapping'].items() if h)
multi = sum(1 for r in records for v, h in r['mapping'].items() if len(h) > 1)

print('NPC blocks with add_actions :', len(records))
print('verbs total                 :', total_verbs)
print('verbs matched to handler    :', matched)
print('verbs unmatched             :', len(unmatched))
print('verb with multiple handlers :', multi)
print('blocks without source       :', len(missing_source))

print('\n=== sample (first 12) ===')
for r in records[:12]:
    print(f"{r['npc_id']:28s} src={r['src']}")
    for v, h in r['mapping'].items():
        print(f"    {v:12s} -> {h or 'UNMATCHED'}")

if unmatched:
    print('\n=== unmatched verbs (first 20) ===')
    for npc, v in unmatched[:20]:
        print(f'  {npc:28s} {v}')

json.dump(records, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('\nwritten:', OUT)
