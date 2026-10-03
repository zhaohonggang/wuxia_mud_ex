"""P3b：恢复 huashan:s 的六把火炬机关门（原方向名 hole1..hole6）。

原 LPC（/d/huashan/s.c）：

    set("exits", ([
        "hole1":__DIR__ "lockroom1",
        ...
        "hole6":__DIR__ "lockroom6",
        "out":__DIR__ "shandong",
    ]));

方向名带数字，elias 的 key 只接受 `^[A-Za-z_][A-Za-z_]*$`（实测 `hole`/`hole_` 可以，
`hole1`/`hole_1`/`6hole` 都不行），所以这 6 条被转换器跳过。

目标 lockroom1..6（石室）在数据里都在，而且已经内部互联、每间都有 `out -> s`，
缺的只是从 `s` 进去的这 6 个门。

命名：`hole1..hole6` -> `hole_a..hole_f`。保留「hole」概念与序数，只把数字换成
字母 —— 不能映射成方位（这六扇门是机关，不是东南西北）。

用法：python scripts/restore_hole_exits.py [--apply]
"""
import os
import re
import sys
import collections
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'data', 'world', 'huashan.ucl')

# hole1..hole6 -> hole_a..hole_f，目标 lockroom1..6（取自 LPC 源 s.c）
MAP = [
    ('hole1', 'hole_a', 'lockroom1'),
    ('hole2', 'hole_b', 'lockroom2'),
    ('hole3', 'hole_c', 'lockroom3'),
    ('hole4', 'hole_d', 'lockroom4'),
    ('hole5', 'hole_e', 'lockroom5'),
    ('hole6', 'hole_f', 'lockroom6'),
]

SKIP_RE = re.compile(r"^\s*#\s*skipped exit direction '(hole\d)':.*$")


def main():
    apply_ = '--apply' in sys.argv
    lines = open(TARGET, encoding='utf-8', newline='').read().split('\n')

    # 找到 room_exits "s" 块及其闭合行
    open_at = None
    for i, l in enumerate(lines):
        if re.match(r'^\s*room_exits\s+"s"\s*\{\s*$', l):
            open_at = i
            break
    if open_at is None:
        print('找不到 room_exits "s"')
        return

    close = None
    for j in range(open_at + 1, len(lines)):
        if lines[j].strip() == '}':
            close = j
            break
    if close is None:
        print('找不到闭合行')
        return

    # 紧随其后的 hole1..hole6 注释
    drop = set()
    found = {}
    for j in range(close + 1, min(close + 12, len(lines))):
        m = SKIP_RE.match(lines[j])
        if m:
            found[m.group(1)] = j
            drop.add(j)
        elif lines[j].strip() == '' or lines[j].lstrip().startswith('#'):
            continue
        else:
            break

    print('room_exits "s" 在行 %d-%d；找到 hole 注释 %d 条' % (open_at + 1, close + 1, len(found)))

    missing = [o for o, _, _ in MAP if o not in found]
    if missing:
        print('  [warn] 未找到注释: %s' % missing)

    # 校验目标房间都在
    text = '\n'.join(lines)
    absent = [t for _, _, t in MAP if ('rooms "%s"' % t) not in text]
    if absent:
        print('  [skip] 目标房间不存在: %s' % absent)
        return

    new_lines = ['    %s = rooms.%s.id' % (alias, tgt) for _, alias, tgt in MAP if _ in found]

    if not apply_:
        print('将新增: %s' % ' '.join(new_lines))
        print('将删除 %d 行注释' % len(drop))
        print('(dry-run，未写入；加 --apply 生效)')
        return

    out = []
    for i, l in enumerate(lines):
        if i in drop:
            continue
        if i == close:
            out.extend(new_lines)
        out.append(l)

    open(TARGET, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    print('已写入 %s：新增 %d 条出口，删除 %d 行注释' % (TARGET, len(new_lines), len(drop)))


if __name__ == '__main__':
    main()