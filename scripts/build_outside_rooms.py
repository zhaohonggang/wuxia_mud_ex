"""P1：把「目标在 d/ 之外」的出口变成真实出口

背景：转换时凡目标不在 mud/d 转换区（`/clone/shop/*`、`/b/*`）的出口都被跳过，
留下 `# skipped exit <dir>: target outside d/: <path>` 注释。共 17 条：
  - 15 个 `/clone/shop/<城>_shop`（inherit SHOP，从城中 `majiu` 上去的店铺）
  - `/b/yitian/jiulou`（会英楼上）、`/b/tulong/haigang`（东海之滨）

做法：
  1. 扫各区 room_exits 块后的 skipped 注释，拿到 (引用区, 房间 key, 方向, 源路径)
  2. 解析源 .c：short/long（含 @LONG heredoc）、exits、no_fight 等 flag、objects
  3. 在**引用区**里新建 rooms + room_exits 块（房间放在引用它的城区，
     这样 `down` 回 `majiu` 是同区引用；只有真跨城的方向才写 `<区>.rooms.<名>.id`）
  4. 把引用房间的 `<方向> = rooms.<新key>.id` 写进它的 room_exits 块，删除注释
  5. 店铺里照原 LPC 放一个伙计（/clone/shop/waiter）；WAITER 的上菜逻辑本项目
     未实现，这里只还原「房里有个伙计」这件事，脚本注释里已注明

用法：python scripts/build_outside_rooms.py [--apply]
"""
import os
import re
import sys
import hashlib
import collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_item

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
MUD = r'C:\files\git\mud'
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

SKIPPED_RE = re.compile(
    r'^\s*#\s*skipped exit (\S+): target outside d/: (\S+): no data/world zone to reference\s*$')
ROOM_EXITS_RE = re.compile(r'^(\s*)room_exits\s+"([^"]+)"\s*\{\s*$')
DIR_RE = re.compile(r'^\s*([a-z_]+)\s*=\s*(rooms\.[a-z0-9_]+\.id)\s*$')


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


def heredoc_or_set(src, key):
    """取 set("<key>", @LONG ... LONG) 或 set("<key>", "...") 的文本"""
    # 注意：LPC heredoc 结束标记要用正则回引用 \1（%1 是 Perl 语法，Python 不认）
    pat = r'set\s*\(\s*"' + key + r'"\s*,\s*@(\w+)\s*\n(.*?)\n\s*\1\s*\)'
    m = re.search(pat, src, re.S)
    if m:
        return lpc_item.clean_text(m.group(2).replace('\n', ''))
    m = re.search(r'set\s*\(\s*"' + key + r'"\s*,\s*(.*?)\)\s*;', src, re.S)
    if m:
        return lpc_item.literal_strings(m.group(1))
    return None


def parse_exits(src):
    """set("exits", ([ "dir" : path, ... ])) -> {dir: path}"""
    m = re.search(r'set\s*\(\s*"exits"\s*,\s*\(\s*\[(.*?)\]\s*\)\s*\)', src, re.S)
    if not m:
        return {}
    body = m.group(1)
    body = re.sub(r'/\*.*?\*/', '', body, flags=re.S)
    out = {}
    for d, path in re.findall(r'"(\w+)"\s*:\s*([^,]+?)\s*(?:,|$)', body):
        p = path.strip().rstrip(',').strip()
        if '__DIR__' in p:
            p = '__DIR__' + re.sub(r'[^"\s]*$', '', p) if False else p
        out[d] = p
    return out


def parse_flags(src):
    out = []
    for k in ('no_fight', 'outdoors', 'water'):
        if re.search(r'set\s*\(\s*"%s"\s*,\s*1\s*\)' % k, src):
            out.append(k)
    return out


def parse_room(src_path):
    raw = open(src_path, encoding='utf-8', errors='replace').read()
    src = lpc_item.strip_comments(raw)
    return {
        'name': one_line(heredoc_or_set(src, 'short')),
        'long': one_line(heredoc_or_set(src, 'long')),
        'exits': parse_exits(src),
        'flags': parse_flags(src),
        'objects': re.findall(r'__DIR__"([\w/]+)"', src) or [],
    }


def source_for(path):
    """LPC 绝对路径（/b/...、/clone/...）-> 本地源文件"""
    rel = path.strip('/').replace('/', os.sep)
    if not rel.endswith('.c'):
        rel += '.c'
    p = os.path.join(MUD, rel)
    return p if os.path.isfile(p) else None


def resolve_room_ref(target, cur_zone, zone_rooms, src_dir_zone=None):
    """把 LPC 路径/键变成 (zone, room_key)

    - `/d/<区>/...`  -> 该区同名房
    - `__DIR__"x"`  -> 与源同目录：目录名若是个已知区就落到该区，否则留在本区
    - 裸键          -> 本区
    """
    t = target.strip()
    if t.startswith('"') and t.endswith('"'):
        t = t[1:-1].strip()

    if t.startswith('__DIR__'):
        m = re.search(r'"([^"]+)"', t)
        if not m:
            return None
        key = m.group(1).replace('.c', '').replace('-', '_').lower()
        return (src_dir_zone or cur_zone, key)

    if t.startswith('/d/'):
        parts = t.split('/')
        return (parts[2], parts[-1].replace('.c', '').replace('-', '_').lower())

    return (cur_zone, t.replace('.c', '').replace('-', '_').lower())


def room_coords(lines, key):
    """取 rooms "<key>" 块的 x/y/z（转换器约定：up 使 z+1，见 city.ucl guangchang->cangku）"""
    pat = re.compile(r'^\s*rooms\s+"' + re.escape(key) + r'"\s*\{')
    for i, l in enumerate(lines):
        if pat.match(l):
            xyz = {}
            for j in range(i, min(i + 14, len(lines))):
                m = re.match(r'^\s*([xyz])\s*=\s*(-?\d+)', lines[j])
                if m:
                    xyz[m.group(1)] = int(m.group(2))
                if lines[j].strip() == '}' and len(xyz) == 3:
                    return xyz
            if len(xyz) == 3:
                return xyz
            break
    return None


def offset_xyz(base, direction):
    """按出口方向推算新房间坐标（up=z+1/east=x+1/...）"""
    if not base:
        return {'x': 0, 'y': 0, 'z': 0}
    x, y, z = base.get('x', 0), base.get('y', 0), base.get('z', 0)
    return {
        'up': {'x': x, 'y': y, 'z': z + 1},
        'down': {'x': x, 'y': y, 'z': z - 1},
        'east': {'x': x + 1, 'y': y, 'z': z},
        'west': {'x': x - 1, 'y': y, 'z': z},
        'north': {'x': x, 'y': y + 1, 'z': z},
        'south': {'x': x, 'y': y - 1, 'z': z}
    }.get(direction, {'x': x, 'y': y, 'z': z})


GEN_RE = re.compile(r'^\s*#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$')
ROOMS_RE = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{\s*$')


def norm_source(path):
    """把 LPC 源路径归一成可比较的键（转换器写在 # Generated from 后面）"""
    return path.strip().replace('\\', '/').lower()


def build_source_index():
    """源文件路径 -> (zone, room_key)

    转换器把 `/b/<区>/<房>.c` 也转成了对应区的房间（例如 `/b/tulong/haigang.c`
    与 `/d/tulong/tulong/haigang.c` 是同一间房的两种拷贝，内容只差函数内路径）。
    所以「目标在 d/ 之外」不等于「目标不存在」——必须先按源文件溯源查一遍，
    能查到就发跨区引用，别建重复房间。
    """
    idx = {}
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        last_src = None
        for line in open(os.path.join(WORLD, fn), encoding='utf-8'):
            m = GEN_RE.match(line)
            if m:
                last_src = norm_source(m.group(1))
                continue
            m = ROOMS_RE.match(line)
            if m and last_src:
                idx.setdefault(last_src, (z, m.group(1)))
                last_src = None
    return idx


def content_key(path):
    """源文件内容指纹：剥掉注释与所有路径字面量后取指纹

    同一个房间在原始世界里常有 `/d/...` 与 `/b/...` 两份拷贝，内容只差函数里
    写的路径（例如 `/b/tulong/haigang.c` 与 `/d/tulong/tulong/haigang.c`）。
    只按 `# Generated from` 的路径匹配会漏掉这种情况，所以再按内容指纹兜一层。
    """
    try:
        raw = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return None
    s = lpc_item.strip_comments(raw)
    s = re.sub(r'"/[a-z]?/?[^"]*"', '"<PATH>"', s)   # 路径字面量
    s = re.sub(r'__DIR__"[^"]*"', '"<DIR>"', s)
    s = re.sub(r'\s+', '', s)
    return hashlib.md5(s.encode('utf-8')).hexdigest()


def build_content_index():
    """内容指纹 -> [(zone, room_key)]，来自各区 rooms 块上方溯源到的 .c"""
    idx = collections.defaultdict(list)
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        last_src = None
        for line in open(os.path.join(WORLD, fn), encoding='utf-8'):
            m = GEN_RE.match(line)
            if m:
                last_src = m.group(1)
                continue
            m = ROOMS_RE.match(line)
            if m and last_src:
                local = os.path.join(MUD, last_src.replace('/', os.sep).lstrip('/'))
                k = content_key(local)
                if k:
                    idx[k].append((z, m.group(1)))
                last_src = None
    return idx


def main():
    apply_ = '--apply' in sys.argv

    # 各区房间 key 集合
    zone_rooms = {}
    for fn in os.listdir(WORLD):
        if fn.endswith('.ucl'):
            keys = set()
            for line in open(os.path.join(WORLD, fn), encoding='utf-8'):
                m = re.match(r'^\s*rooms\s+"([^"]+)"\s*\{', line)
                if m:
                    keys.add(m.group(1))
            zone_rooms[fn[:-4]] = keys

    # 扫 skipped 注释（只认紧跟 room_exits 块之后的）
    tasks = collections.defaultdict(list)   # zone -> [(room_key, dir, srcpath, line)]
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue
        path = os.path.join(WORLD, fn)
        lines = open(path, encoding='utf-8').read().split('\n')
        last_exits = None
        for i, line in enumerate(lines):
            m = ROOM_EXITS_RE.match(line)
            if m:
                last_exits = m.group(2)
                continue
            ms = SKIPPED_RE.match(line)
            if ms and last_exits:
                tasks[z].append((last_exits, ms.group(1), ms.group(2), i))
                last_exits = None

    total = sum(len(v) for v in tasks.values())
    print('skipped outside-d 出口: %d 条，%d 个区' % (total, len(tasks)))

    src_index = build_source_index()
    content_index = build_content_index()

    if not apply_:
        for z, ts in sorted(tasks.items()):
            for rk, d, p, ln in ts:
                print('  %-10s %-12s %-4s %s' % (z, rk, d, p))
        print('\n(dry-run，未写入)')
        return

    for z, ts in sorted(tasks.items()):
        path = os.path.join(WORLD, '%s.ucl' % z)
        lines = open(path, encoding='utf-8').read().split('\n')
        add = []
        drop = set()
        patch = collections.defaultdict(list)   # room_key -> [(dir, newkey)]

        for rk, direction, target, lineno in ts:
            src = source_for(target)

            # 先按源文件溯源：目标可能已经作为某个区的房间转进来了
            hit = src_index.get(norm_source(target))
            if not hit and src:
                # 同一间房可能有 /d 与 /b 两份拷贝，按内容指纹兜一层
                for tz2, tkey2 in content_index.get(content_key(src), []):
                    if tz2 != z:
                        hit = (tz2, tkey2)
                        break

            if hit:
                tz, tkey = hit
                patch[rk].append((direction, tz, tkey))
                drop.add(lineno)
                print('  [apply] %s: %s 的 %s -> 已存在 %s（源 %s，跨区引用）'
                      % (z, rk, direction, '%s:%s' % (tz, tkey), target))
                continue

            if not src:
                print('  [skip] %s/%s %s -> %s：源文件不存在' % (z, rk, direction, target))
                continue
            info = parse_room(src)
            new_xyz = offset_xyz(room_coords(lines, rk), direction)
            base = os.path.basename(src)[:-2].replace('-', '_').lower()
            key = base
            n = 2
            while key in zone_rooms[z]:
                key = '%s_%d' % (base, n)
                n += 1
            zone_rooms[z].add(key)

            # __DIR__"x" 的目录名若正好是个已知区（/b/tulong/... -> tulong），就落该区
            src_dir_zone = os.path.basename(os.path.dirname(src).replace('\\', '/'))
            src_dir_zone = src_dir_zone if src_dir_zone in zone_rooms else z

            # 新房间
            add.append('# Source: %s' % target)
            add.append('# Zone: %s' % z)
            add.append('')
            add.append('    rooms "%s" {' % key)
            add.append('      name = "%s"' % esc(info['name'] or key))
            add.append('      description = "%s"' % esc(info['long'] or ''))
            if info['flags']:
                add.append('  flags = [')
                for f in info['flags']:
                    add.append('    "%s",' % f)
                add[-1] = add[-1].rstrip(',')
                add.append('  ]')
            add.append('  x = %d' % new_xyz['x'])
            add.append('  y = %d' % new_xyz['y'])
            add.append('  z = %d' % new_xyz['z'])
            add.append('    }')
            add.append('')

            # 新房间的出口
            add.append('  room_exits "%s" {' % key)
            add.append('    room_id = rooms.%s.id' % key)
            for d, t in sorted(info['exits'].items()):
                tz, tkey = resolve_room_ref(t, z, zone_rooms, src_dir_zone)
                if tkey is None or tkey not in zone_rooms.get(tz, set()):
                    print('  [warn] %s/%s 的 %s -> %s：目标房 %s:%s 不存在，跳过该方向'
                          % (z, key, d, t, tz, tkey))
                    continue
                ref = ('rooms.%s.id' % tkey) if tz == z else ('%s.rooms.%s.id' % (tz, tkey))
                add.append('    %s = %s' % (d, ref))
            add.append('    }')
            add.append('')

            # 伙计（/clone/shop/waiter）
            if info['objects'] and 'waiter' in ' '.join(info['objects']):
                add.append('# Source: C:/files/git/mud/clone/shop/waiter.c')
                add.append('# Zone: %s' % z)
                add.append('')
                add.append('    characters "waiter" {')
                add.append('      name = "伙计"')
                add.append('      description = "一个忙前忙后的店伙计。"')
                add.append('  brain = brains.vendor')
                add.append('')
                add.append('  carry = [')
                add.append('    { id = clone_lib.items.cloth.id }')
                add.append('  ]')
                add.append('')
                add.append('  init = {')
                add.append('    add_actions = ["list", "buy"]')
                add.append('  }')
                add.append('    }')
                add.append('')
                add.append('  room_characters "%s" {' % key)
                add.append('    room_id = rooms.%s.id' % key)
                add.append('    characters = [')
                add.append('      { id = characters.waiter.id }    ]')
                add.append('  }')
                add.append('')

            patch[rk].append((direction, z, key))
            drop.add(lineno)
            print('  [apply] %s: %s 的 %s -> 新房 %s（源 %s）' % (z, rk, direction, key, target))

        # 改写：把方向写进被引用房间的 room_exits 块（闭合行之前），并删掉注释
        out = []
        i = 0
        while i < len(lines):
            line = lines[i]
            if i in drop:
                i += 1
                continue
            out.append(line)
            m = ROOM_EXITS_RE.match(line)
            if m:
                room_key = m.group(2)
                d = 0
                j = i
                while j < len(lines):
                    d += delta(lines[j])
                    if j > i and d == 0:
                        break
                    j += 1
                # 块内（不含闭合行）
                for k2 in range(i + 1, j):
                    if k2 not in drop:
                        out.append(lines[k2])
                # 新方向插在闭合行之前
                for direction, tz2, tkey2 in patch.get(room_key, []):
                    ref = ('rooms.%s.id' % tkey2) if tz2 == z else ('%s.rooms.%s.id' % (tz2, tkey2))
                    out.append('    %s = %s' % (direction, ref))
                # 闭合行原样保留
                if j < len(lines) and j not in drop:
                    out.append(lines[j])
                i = j + 1
                continue
            i += 1

        raw = '\n'.join(out).rstrip('\n')
        if add:
            raw += '\n\n' + '\n'.join(add)
        raw += '\n'
        old_raw = open(path, encoding='utf-8', newline='').read()
        if raw != old_raw:
            open(path, 'w', encoding='utf-8', newline='').write(raw)


if __name__ == '__main__':
    main()