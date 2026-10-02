"""P0b：为「商人卖得出但世界里没有」的物品补建 items 块

背景：商人 goods 里有 206 条同区引用（items.<名>.id），但目标区根本没有这个
物品 —— 转换器当年认为源文件「已知」就写了引用，却没产出对应 items 块，
于是这些商品在运行时全部落空（buy/list 查不到）。实测 223 个 (区,名) 对应的
源 .c 全部存在（173 个在同区、50 个来自 /clone/herb 标准库）。

做法：
  1. 扫各区 UCL 的 goods 块，找出指向「本区不存在的物品」的引用
  2. 按 LPCConverter.room_id_from_path 的归一（basename 去扩展名、- → _、小写）
     定位源 .c；同区优先，其次 /clone 标准库
  3. 同区物品 -> 追加 items 块到该区 .ucl
     /clone 物品 -> 追加到新建的 data/world/clone_lib.ucl（标准库集中放），
                    并把引用改写为 clone_lib.items.<名>.id（loader 支持跨区引用）
  4. 排版与既有转换产物一致：items 缩进 4、name/description 6、verbs 2、meta 6

用法：python scripts/build_missing_items.py [--apply]
"""
import os
import re
import sys
import json
import collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_item

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
MUD = r'C:\files\git\mud'
CLONE_ZONE = 'clone_lib'

EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti', 'signature',
            CLONE_ZONE}

ENTRY_RE = re.compile(r'^(\s*)\{ id = (items\.[a-z0-9_]+\.id) \},?\s*$')


def skeleton(line):
    out = []
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if not in_str and c == '#':
            break
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            out.append(' ')
        else:
            if c == '"':
                in_str = True
                out.append(' ')
            else:
                out.append(c)
        i += 1
    return ''.join(out)


def delta(line):
    s = skeleton(line)
    return s.count('{') - s.count('}')


def esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')


def one_line(s):
    return re.sub(r'\s+', ' ', (s or '').replace('\n', '')).strip()


def norm(stem):
    return stem.replace('-', '_').lower()


def existing_items(path):
    keys = set()
    for line in open(path, encoding='utf-8'):
        m = re.match(r'^\s*items\s+"([^"]+)"\s*\{', line)
        if m:
            keys.add(m.group(1))
    return keys


def index_sources():
    idx = collections.defaultdict(list)
    for base, _dirs, files in os.walk(MUD):
        for fn in files:
            if fn.endswith('.c'):
                idx[norm(fn[:-2])].append(os.path.join(base, fn))
    return idx


def find_source(name, zone, srcs):
    same = [p for p in srcs.get(name, []) if ('/d/%s/' % zone) in p.replace('\\', '/')]
    if same:
        return same[0], 'same'
    others = srcs.get(name, [])
    if not others:
        return None, None
    return others[0], ('clone' if '/clone/' in others[0].replace('\\', '/') else 'other')


def render_item(key, d, src, zone, origin):
    """输出一个 items 块（排版对齐既有转换产物）"""
    name = one_line(d.get('name')) or key
    desc = one_line(d.get('long')) or name
    verbs = d.get('verbs') or ['get', 'drop']

    out = []
    out.append('# Source: %s' % src.replace('\\', '/'))
    out.append('# Zone: %s' % zone)
    out.append('')
    out.append('    items "%s" {' % key)
    out.append('      name = "%s"' % esc(name))
    out.append('      description = "%s"' % esc(desc))
    out.append('  verbs = [')
    for i, v in enumerate(verbs):
        out.append('    "%s"%s' % (v, ',' if i < len(verbs) - 1 else ''))
    out.append('  ]')

    meta = []
    if d.get('damage') is not None:
        meta.append('        damage = %d' % d['damage'])
    if d.get('damage') is not None and d.get('skill_type'):
        meta.append('        skill_type = "%s"' % esc(d['skill_type']))
    if d.get('value') is not None:
        meta.append('        value = %d' % d['value'])
    if d.get('weight') is not None:
        meta.append('        weight = %d' % d['weight'])
    if d.get('unit'):
        meta.append('        unit = "%s"' % esc(d['unit']))
    if d.get('material'):
        meta.append('        material = "%s"' % esc(d['material']))
    if d.get('armor') is not None:
        meta.append('        armor = %d' % d['armor'])
    if d.get('armor_type'):
        meta.append('        armor_type = "%s"' % esc(d['armor_type']))
    if d.get('food') is not None:
        meta.append('        food = %d' % d['food'])
    if d.get('book'):
        bk = d['book']
        meta.append('        book = {')
        for k in ('skill', 'min_skill', 'max_skill', 'exp_required', 'jing_cost', 'difficulty'):
            if bk.get(k) is None:
                continue
            v = bk[k]
            meta.append('          %s = %s' % (k, ('"%s"' % esc(v)) if isinstance(v, str) else v))
        meta.append('        }')

    if meta:
        out.append('')
        out.append('      meta = {')
        out.extend(meta)
        out.append('      }')

    out.append('    }')
    out.append('')
    return out


def scan_dangling():
    """返回 {(zone, name): [(file, lineno)]}，只扫范围内区"""
    zone_items = {}
    for fn in os.listdir(WORLD):
        if fn.endswith('.ucl') and fn[:-4] not in EXCLUDED:
            zone_items[fn[:-4]] = existing_items(os.path.join(WORLD, fn))

    found = collections.defaultdict(list)
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue
        path = os.path.join(WORLD, fn)
        lines = open(path, encoding='utf-8').read().split('\n')
        depth = 0
        in_goods = False
        for i, line in enumerate(lines):
            if in_goods:
                if line.strip() == ']':
                    in_goods = False
                else:
                    m = ENTRY_RE.match(line)
                    if m:
                        ref = m.group(2)
                        nm = ref[len('items.'):-len('.id')]
                        if nm not in zone_items.get(z, set()):
                            found[(z, nm)].append((fn, i))
            elif re.match(r'^\s*goods\s*=\s*\[\s*$', line) and depth >= 0:
                # 只认 NPC 块内的 goods（房间层不会用 items.<名>.id 形式）
                in_goods = True
            depth += delta(line)
    return found


def main():
    apply_ = '--apply' in sys.argv
    found = scan_dangling()
    srcs = index_sources()

    print('dangling (zone,name): %d  refs: %d'
          % (len(found), sum(len(v) for v in found.values())))

    per_zone = collections.defaultdict(list)   # zone -> [(key, src, d)]
    clone_items = []
    rewritten = collections.defaultdict(list)  # file -> [(lineno, old, new)]
    unresolved = []

    for (z, nm), refs in sorted(found.items()):
        src, origin = find_source(nm, z, srcs)
        if not src:
            unresolved.append((z, nm))
            continue
        d = lpc_item.extract(src)
        good, why = lpc_item.is_item_like(d, lpc_item.strip_comments(
            open(src, encoding='utf-8', errors='replace').read()))
        if not good:
            unresolved.append((z, nm, why))
            continue
        d['verbs'] = lpc_item.infer_verbs(d.get('_inherits', []), d)

        if origin == 'same':
            per_zone[z].append((nm, src, d))
        else:
            # /clone 标准库：集中到 clone_lib，引用改写为跨区
            clone_items.append((nm, src, d))
            for fn, lineno in refs:
                rewritten[fn].append((lineno, 'items.%s.id' % nm,
                                      '%s.items.%s.id' % (CLONE_ZONE, nm)))

    print('同区新建: %d   /clone 搬运: %d   无法定位: %d'
          % (sum(len(v) for v in per_zone.values()), len(clone_items), len(unresolved)))
    if unresolved:
        print('\n=== 无法定位 ===')
        for u in unresolved:
            print('  %s' % (u,))

    if not apply_:
        print('\n(dry-run，未写入)')
        return

    # 1) 同区物品
    for z, items in per_zone.items():
        path = os.path.join(WORLD, '%s.ucl' % z)
        raw = open(path, encoding='utf-8').read()
        add = []
        for nm, src, d in sorted(items):
            add.extend(render_item(nm, d, src, z, 'same'))
        open(path, 'w', encoding='utf-8', newline='').write(raw.rstrip('\n') + '\n\n' + '\n'.join(add))
        print('[apply] %s: +%d 物品' % (z, len(items)))

    # 2) clone_lib 新区
    if clone_items:
        path = os.path.join(WORLD, '%s.ucl' % CLONE_ZONE)
        header = [
            '# 标准库物品：原 LPC /clone 下的物件在 mud/d 转换中无处落放，',
            '# 集中放在本区，商人跨区引用（loader.dereference 支持 <区>.items.<名>.id）。',
            '',
            'zones "%s" {' % CLONE_ZONE,
            '  name = "标准库"',
            '}',
            '',
        ]
        body = []
        for nm, src, d in sorted(clone_items):
            body.extend(render_item(nm, d, src, CLONE_ZONE, 'clone'))
        open(path, 'w', encoding='utf-8', newline='').write('\n'.join(header + body))
        print('[apply] %s.ucl: +%d 物品（新建）' % (CLONE_ZONE, len(clone_items)))

    # 3) 引用改写
    for fn, edits in rewritten.items():
        path = os.path.join(WORLD, fn)
        lines = open(path, encoding='utf-8').read().split('\n')
        n = 0
        for lineno, old, new in edits:
            if old in lines[lineno]:
                lines[lineno] = lines[lineno].replace(old, new)
                n += 1
        open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
        print('[apply] %s: 改写 %d/%d 条引用 -> %s' % (fn, n, len(edits), CLONE_ZONE))


if __name__ == '__main__':
    main()