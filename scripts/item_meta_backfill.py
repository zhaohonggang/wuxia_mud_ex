"""回填 data/world 转换区物品的 meta（还原 LPC set() 语义）

背景：已归档的转换器生成 items 块时，只搬了 name/description/verbs，
把 set_weight() / set("value") / set("unit") / set("material") /
init_sword() 等 weapon 初始化 / food_supply / armor_prop/armor /
set("skill") 全部丢掉 —— 全库 841 个物品只有 75 个带 meta，且这 75 个
全部来自手工区 liuxi。后果是转换区武器无伤害、食物不可食、买卖无价。

本脚本按每个 items 块上方的 `# Generated from <path> by LPCConverter`
溯源到原始 .c，用新方法重新抽取字段，只在「该物品块还没有 meta」时补写，
不改动已有的 name/description/verbs（避免无谓改动）。

字段与 UCL 约定对照 lib/kantele/world/lpc_converter.ex 的
generate_item_ucl/build_item_meta，另补它漏掉的 set_weight/init_*/base_*/food_supply。

用法：python scripts/item_meta_backfill.py [--apply]
      不带 --apply 只统计不写盘。
"""
import os
import re
import sys
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_item

WORLD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'world')
MUD_D = r'C:\files\git\mud'

# 计划范围外的区（测试夹具 / 转换器语料 / 手工区），不动
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti', 'signature'}

GEN_RE = re.compile(r'^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$')
ITEMS_OPEN_RE = re.compile(r'^(\s*)items\s+"([^"]+)"\s*\{\s*$')


def skeleton(line):
    """去掉字符串内容与 # 注释，只留结构字符（算花括号深度用）"""
    out = []
    in_str = False
    i = 0
    n = len(line)
    while i < n:
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


def meta_lines(d, indent):
    """按既有 UCL 风格输出 meta 块；字段顺序固定，便于 diff"""
    out = []
    pad = ' ' * indent
    inner = ' ' * (indent + 2)

    if d.get('damage') is not None:
        out.append('%sdamage = %d' % (inner, d['damage']))
    if d.get('damage') is not None and d.get('skill_type'):
        out.append('%sskill_type = "%s"' % (inner, esc(d['skill_type'])))
    if d.get('value') is not None:
        out.append('%svalue = %d' % (inner, d['value']))
    if d.get('weight') is not None:
        out.append('%sweight = %d' % (inner, d['weight']))
    if d.get('unit'):
        out.append('%sunit = "%s"' % (inner, esc(d['unit'])))
    if d.get('material'):
        out.append('%smaterial = "%s"' % (inner, esc(d['material'])))
    if d.get('armor') is not None:
        out.append('%sarmor = %d' % (inner, d['armor']))
    if d.get('armor_type'):
        out.append('%sarmor_type = "%s"' % (inner, esc(d['armor_type'])))
    if d.get('food') is not None:
        out.append('%sfood = %d' % (inner, d['food']))
    if d.get('book'):
        bk = d['book']
        out.append('%sbook = {' % inner)
        for k in ('skill', 'min_skill', 'max_skill', 'exp_required', 'jing_cost', 'difficulty'):
            if bk.get(k) is None:
                continue
            v = bk[k]
            out.append('%s  %s = %s' % (inner, k, ('"%s"' % esc(v)) if isinstance(v, str) else v))
        out.append('%s}' % inner)

    if not out:
        return []
    return ['', '%smeta = {' % pad] + out + ['%s}' % pad]


def process_file(path, apply_, zone=''):
    raw = open(path, encoding='utf-8').read()
    lines = raw.split('\n')

    # 找所有 items 块（花括号深度定位，zone 文件是扁平 top-level 重复键）
    blocks = []
    depth = 0
    pending = None
    for i, line in enumerate(lines):
        opens = depth == 0 and ITEMS_OPEN_RE.match(line)
        if opens:
            m = ITEMS_OPEN_RE.match(line)
            pending = (i, m.group(1), m.group(2))
        nxt = depth + delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            s, ind, key = pending
            blocks.append((s, i, ind, key))
            pending = None
        depth = nxt

    if not blocks:
        return None

    stats = {'blocks': len(blocks), 'filled': 0, 'has_meta': 0, 'no_source': 0,
             'no_fields': 0, 'not_item': 0}
    fills = {}   # 行号(close) -> 需要插入的行

    for start, close, indent, key in blocks:
        body = lines[start + 1:close]
        # 块内是否已有 meta（只看本层：缩进 = indent+2）
        meta_ind = ' ' * (len(indent) + 2)
        if any(l.strip().startswith('meta') and l.startswith(meta_ind) for l in body):
            stats['has_meta'] += 1
            continue

        # 溯源：块上方最近的 Generated from
        src = None
        for j in range(start - 1, max(-1, start - 6), -1):
            m = GEN_RE.match(lines[j].strip())
            if m:
                src = m.group(1)
                break
        if not src:
            stats['no_source'] += 1
            continue

        local = src.replace('/', os.sep)
        if not os.path.isfile(local):
            stats['no_source'] += 1
            continue

        text = open(local, encoding='utf-8', errors='replace').read()
        d = lpc_item.extract(local)
        good, why = lpc_item.is_item_like(d, lpc_item.strip_comments(text))
        if not good:
            stats['not_item'] += 1
            stats.setdefault('not_item_list', []).append('%s/%s: %s (%s)' % (zone, key, why, src))
            continue

        ml = meta_lines(d, len(indent) + 2)
        if not ml:
            stats['no_fields'] += 1
            continue

        fills[close] = ml
        stats['filled'] += 1

    if not fills:
        return (stats, None)

    out = []
    for i, line in enumerate(lines):
        if i in fills:
            out.extend(fills[i])
        out.append(line)

    if apply_:
        open(path, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    return (stats, '\n'.join(out) != raw)


def main():
    apply_ = '--apply' in sys.argv
    zone = None
    for a in sys.argv[1:]:
        if a.startswith('--zone='):
            zone = a.split('=', 1)[1]

    total = {'blocks': 0, 'filled': 0, 'has_meta': 0, 'no_source': 0,
             'no_fields': 0, 'not_item': 0}
    not_items = []
    changed = []

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue
        if zone and z != zone:
            continue
        res = process_file(os.path.join(WORLD, fn), apply_, z)
        if not res:
            continue
        stats, did = res
        for k in total:
            total[k] += stats[k]
        not_items.extend(stats.get('not_item_list', []))
        if did:
            changed.append((z, stats['filled']))
            print('[%s] %s: %d 个物品补 meta（块 %d，已有 meta %d，无源 %d，非物品 %d，无字段 %d）'
                  % ('apply' if apply_ else 'dry', z, stats['filled'], stats['blocks'],
                     stats['has_meta'], stats['no_source'], stats['not_item'], stats['no_fields']))

    if not_items:
        print('\n=== 判为非物品（跳过，需人工确认）===')
        for s in not_items:
            print('  ' + s)

    print()
    print('=== 汇总 ===')
    print(json.dumps(total, ensure_ascii=False))
    print('改动区数: %d' % len(changed))
    if not apply_:
        print('(dry-run，未写入；加 --apply 生效)')


if __name__ == '__main__':
    main()