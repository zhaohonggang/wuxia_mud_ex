"""P3a：把 shaolin 八卦阵的 64 条 CJK 方向出口恢复成 ASCII（拼音）方向。

原 LPC 里房间出口方向名可以是任意字符串，八卦阵用八个卦名当方向：

    # /d/shaolin/bagua0.c
    set("exits", ([
        "乾" : __DIR__"bagua7",
        "巽" : __DIR__"bagua6",
        ...
        "坤" : __DIR__"bagua0",
    ]));

elias 的 key 只接受 ASCII（`^[A-Za-z_][A-Za-z_]*$`），所以这 64 条被转换器跳过，
`room_exits "bagua0"` 甚至变成空块（该房完全孤立）。

方向名用**拼音**而不是方位缩写：这些卦名不是东南西北，而是八卦阵的走法
（阵法逻辑在 /d/shaolin/bagua.h 的 check_dirs 里，按玩家 temp "bagua/count"
计数判断顺序对错）。映射成 nw/ne 会把「阵法走法」误导成「地理方位」。

注意：本脚本只恢复**拓扑**。`check_dirs`（陷阱/计数器，见 valid_leave 条件
`check_dirs(me,dir)`）带副作用（掉jing、减neili、改 temp），不在本轮范围，
所以恢复后八卦阵可自由走动、暂无陷阱。bagua0 的孤立状态则无论如何都是缺陷。

用法：python scripts/restore_bagua_exits.py [--apply]
"""
import os
import re
import sys
import collections
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
LPC = r'C:\files\git\mud\d\shaolin'
TARGET = os.path.join(WORLD, 'shaolin.ucl')

# 卦名 -> 拼音（作为出口方向名）
PINYIN = {
    '乾': 'qian', '兑': 'dui', '坎': 'kan', '坤': 'kun',
    '巽': 'xun', '离': 'li', '艮': 'gen', '震': 'zhen',
}

SKIPPED_RE = re.compile(r"^\s*#\s*skipped exit direction '(.+?)':\s*direction is not ASCII.*$")
EXITS_OPEN_RE = re.compile(r'^(\s*)room_exits\s+"([^"]+)"\s*\{\s*$')


def source_exits(room):
    """从 LPC 源取该房间的 (卦名, 目标房) 有序表"""
    path = os.path.join(LPC, '%s.c' % room)
    if not os.path.isfile(path):
        return None
    src = open(path, encoding='utf-8', errors='replace').read()
    m = re.search(r'set\("exits",\s*\(\[(.*?)\]\)\s*\)', src, re.S)
    if not m:
        return None
    pairs = re.findall(r'"([^"]+)"\s*:\s*__DIR__"([^"]+)"', m.group(1))
    return pairs


def main():
    apply_ = '--apply' in sys.argv
    lines = open(TARGET, encoding='utf-8', newline='').read().split('\n')

    # 找出所有 room_exits 块及其后紧跟的卦名注释
    blocks = []
    for i, l in enumerate(lines):
        m = EXITS_OPEN_RE.match(l)
        if m:
            blocks.append((i, m.group(2)))

    stats = collections.Counter()
    drop = set()
    inserts = collections.defaultdict(list)   # 行号(闭合行) -> [新增行]

    for i, room in blocks:
        if not room.startswith('bagua'):
            continue

        # 找该块的闭合行。注意转换器输出的缩进不自洽（开行 2 空格、闭合行 4 空格），
        # 所以不能用「同缩进」判定；room_exits 块内不嵌套，取第一个 `}` 即可。
        close = None
        for j in range(i + 1, len(lines)):
            if lines[j].strip() == '}':
                close = j
                break
        if close is None:
            print('  [skip] %s: 找不到 room_exits 闭合行' % room)
            continue

        # 收集紧随其后的卦名注释（允许中间夹空行/其它注释）
        trigs = []
        for j in range(close + 1, min(close + 14, len(lines))):
            ms = SKIPPED_RE.match(lines[j])
            if ms:
                trigs.append((j, ms.group(1)))
            elif lines[j].strip() == '' or lines[j].lstrip().startswith('#'):
                continue
            else:
                break

        if not trigs:
            continue

        pairs = source_exits(room)
        if not pairs:
            print('  [skip] %s: 源里没有 exits' % room)
            continue

        src_map = dict(pairs)
        new_lines = []
        missing = []
        for _, trig in trigs:
            if trig not in PINYIN:
                missing.append(trig)
                continue
            tgt = src_map.get(trig)
            if not tgt:
                missing.append(trig)
                continue
            new_lines.append('    %s = rooms.%s.id' % (PINYIN[trig], tgt))

        if missing:
            print('  [warn] %s: 卦名未映射 %s' % (room, missing))
        if len(new_lines) != 8:
            print('  [skip] %s: 只还原出 %d 条' % (room, len(new_lines)))
            continue

        inserts[close] = new_lines
        drop.update(j for j, _ in trigs)
        stats['rooms'] += 1
        stats['exits'] += len(new_lines)

    print('将恢复 %d 个房间 / %d 条出口，删除 %d 行注释'
          % (stats['rooms'], stats['exits'], len(drop)))

    if not apply_:
        print('(dry-run，未写入；加 --apply 生效)')
        return

    out = []
    for i, l in enumerate(lines):
        if i in drop:
            continue
        if i in inserts:
            out.extend(inserts[i])
        out.append(l)

    open(TARGET, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    print('已写入 %s' % TARGET)


if __name__ == '__main__':
    main()