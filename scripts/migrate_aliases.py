"""P2b：给已转换的角色/物品补 `aliases`（LPC `set_name` 的第二个参数）

背景：LPC 的 `present(id, env)`、`get`、`ask` 都靠 `set_name` 的 id 表匹配，
而转换时只保留了 `name`，把别名整组丢了。后果是 60 个阻挡条件里引用的
`present('shi wei', ...)` 之类拼音 id 有 57 个匹配不上 —— valid_leave 机制
等于没上线。

本脚本按每个块上方的 `# Generated from <path> by LPCConverter` 溯源到原始 .c，
抽出 `set_name(<名>, ({ "id1", "id2" }))` 的别名表，写进：

    items "x" {
      name = "..."
      aliases = ["id1", "id2"]     <- 新增
    ...
    characters "y" {
      name = "..."
      aliases = ["id1", "id2"]     <- 新增

只补没有 aliases 的块，不动其它字段。别名表为空（源里只有一个名字）时跳过。

用法：python scripts/migrate_aliases.py [--apply]
"""
import os
import re
import sys
import time
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

GEN = re.compile(r'^\s*#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$')
BLOCK = re.compile(r'^(\s*)(items|characters)\s+"([^"]+)"\s*\{\s*$')
NAME_LINE = re.compile(r'^\s*name\s*=\s*"(.*)"\s*$')
ALIASES_LINE = re.compile(r'^\s*aliases\s*=')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_item


def write_with_retry(path, content, zone, attempts=5):
    """Windows bind mount 偶发 OSError 22"""
    for i in range(attempts):
        try:
            with open(path, 'w', encoding='utf-8', newline='') as fh:
                fh.write(content)
            return True
        except OSError as e:
            if i == attempts - 1:
                print('  [FAIL] %s 写入失败：%s' % (zone, e))
                return False
            time.sleep(0.3)
    return False


def main():
    apply_ = '--apply' in sys.argv
    stats = collections.Counter()
    per_zone = collections.Counter()
    failed = 0
    samples = []

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue

        path = os.path.join(WORLD, fn)
        raw = open(path, encoding='utf-8', newline='').read()
        lines = raw.split('\n')
        out = []
        last_src = None
        i = 0
        n = 0

        while i < len(lines):
            line = lines[i]
            m = GEN.match(line)
            if m:
                last_src = m.group(1)
                out.append(line)
                i += 1
                continue

            m = BLOCK.match(line)
            if not m:
                out.append(line)
                i += 1
                continue

            indent, kind, key = m.group(1), m.group(2), m.group(3)

            # 块内找 name 行、确认没有 aliases
            j = i + 1
            name_at = None
            has_aliases = False
            depth = 0
            while j < len(lines):
                if ALIASES_LINE.match(lines[j]):
                    has_aliases = True
                mn = NAME_LINE.match(lines[j])
                if mn and name_at is None and depth == 0:
                    name_at = j
                depth += lpc_item_delta(lines[j])
                if depth == 0 and j > i:
                    break
                j += 1

            block = lines[i:j + 1]
            src_path = last_src.replace('/', os.sep).lstrip('\\') if last_src else None
            aliases = read_aliases(src_path)

            if has_aliases or aliases is None or len(aliases) == 0 or name_at is None:
                stats[kind + ':skip'] += 1
                out.extend(block)
                last_src = None
                i = j + 1
                continue

            # 在 name 行之后插 aliases（缩进对齐 name）
            name_indent = lines[name_at][:len(lines[name_at]) - len(lines[name_at].lstrip())]
            alias_line = '%saliases = [%s]' % (
                name_indent, ', '.join('"%s"' % a.replace('"', "'") for a in aliases))
            out.extend(block[:name_at - i + 1])
            out.append(alias_line)
            out.extend(block[name_at - i + 1:])
            stats[kind + ':filled'] += 1
            n += 1
            if len(samples) < 12:
                samples.append((z, kind, key, aliases))
            last_src = None
            i = j + 1

        if n:
            per_zone[z] = n
            if apply_ and not write_with_retry(path, '\n'.join(out), z):
                failed += 1

    for label, count in sorted(stats.items()):
        print('  %-22s %d' % (label, count))

    print('\n合计补 aliases %d 处（%d 个区）；写入失败 %d 个区'
          % (sum(per_zone.values()), len(per_zone), failed))

    print('\n样例：')
    for z, kind, key, al in samples:
        print('  %-10s %-10s %-14s %s' % (z, kind, key, al[:5]))

    if not apply_:
        print('\n(dry-run，未写入；加 --apply 生效)')


def lpc_item_delta(line):
    s = lpc_item.strip_comments(line) if '#' in line else line
    # 简单计括号：字符串内的括号不计
    out = []
    in_str = False
    i = 0
    while i < len(s):
        c = s[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == '{':
                out.append('{')
            elif c == '}':
                out.append('}')
        i += 1
    return ''.join(out).count('{') - ''.join(out).count('}')


def read_aliases(src_path):
    if not src_path:
        return None
    full = os.path.join(r'C:\files\git\mud', src_path)
    if not os.path.isfile(full):
        return None
    try:
        src = lpc_item.strip_comments(open(full, encoding='utf-8', errors='replace').read())
    except OSError:
        return None

    m = re.search(r'\bset_name\s*\((.*?)\)\s*;', src, re.S)
    if not m:
        return None
    al = re.search(r'\(\s*\{(.*?)\}\s*\)', m.group(1), re.S)
    if not al:
        return None
    out = []
    for lit in re.findall(r'"((?:[^"\\]|\\.)*)"', al.group(1)):
        v = lpc_item.clean_text(lit)
        if v and v not in out:
            out.append(v)
    return out


if __name__ == '__main__':
    main()