"""A 项第一步：给「LPC 本来就拦所有方向」的 valid_leave 加 all_dirs = true。

为什么需要这个标记
------------------
运行时对「条件里没有 dir」的条目一律跳过（LpcCondition.direction_scoped?/1），
因为转换器处理嵌套 if 时会丢外层守卫，照做会把该房所有出口都拦掉。
但有一批房间的 LPC **本来就没有方向守卫**，条件对所有方向成立是设计如此：

    city:eproom / nproom / sproom / wproom   玩拱猪时不能走
    city:lichunyuan2                          妓院里的嫖客不许走
    city:qiyuan2 / qiyuan3 / qiyuan4          还坐着（棋盘）不许走
    huashan:chufang / xiangyang:juyichufang   端着汤/饭不许走
    lingxiao:wave                            玄冰蝎王封锁去路
    shaolin:dmyuan2                           本寺最高心法不见了，不许走

这批逐个回 LPC 源核对过（valid_leave 里确实没有 dir 判断），所以显式标
`all_dirs = true`，让运行时正常执行。

**不包含** huashan:bingqifang：它的 LPC 是数背包里 `zhujian` 的数量
（`for (i...) if (inv[i]->query("id") == "zhujian") j++;` 再 `if (j > 1)`），
转换时整个 for 循环丢失，只剩 `j > 1`（j 是未声明的局部变量）。
真实语义是「背包里竹剑超过一把就不许带走」，当前表达式语言没有
「按 id 统计背包数量」的能力，保持不执行。

用法：python scripts/mark_all_dirs_vetoes.py [--apply]
"""
import os
import re
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

# (区, 房间) —— 已逐个回 LPC valid_leave 核对
ALL_DIRS = [
    ('city', 'eproom'),
    ('city', 'lichunyuan2'),
    ('city', 'nproom'),
    ('city', 'qiyuan2'),
    ('city', 'qiyuan3'),
    ('city', 'qiyuan4'),
    ('city', 'sproom'),
    ('city', 'wproom'),
    ('huashan', 'chufang'),
    ('lingxiao', 'wave'),
    ('shaolin', 'dmyuan2'),
    ('xiangyang', 'juyichufang'),
]

COND = re.compile(r'^(\s*)condition = "(.*)"\s*$')


def main():
    apply_ = '--apply' in sys.argv
    done = 0
    missing = []

    for zone, room in ALL_DIRS:
        path = os.path.join(WORLD, '%s.ucl' % zone)
        lines = open(path, encoding='utf-8', newline='').read().split('\n')

        # 找 rooms "<room>" 块内的 valid_leave 条目
        try:
            r_start = next(i for i, l in enumerate(lines)
                           if re.match(r'\s*rooms\s+"%s"\s*\{' % re.escape(room), l))
        except StopIteration:
            missing.append('%s:%s（找不到房间）' % (zone, room))
            continue

        # valid_leave 块范围
        v_start = next((i for i in range(r_start, min(r_start + 60, len(lines)))
                        if 'valid_leave = [' in lines[i]), None)
        if v_start is None:
            missing.append('%s:%s（没有 valid_leave）' % (zone, room))
            continue

        v_end = next(i for i in range(v_start + 1, min(v_start + 60, len(lines)))
                     if lines[i].strip() == ']')

        block = lines[v_start:v_end]
        has_all = any('all_dirs' in l for l in block)
        cond_idx = [i for i, l in enumerate(block) if COND.match(l)]

        if has_all:
            print('  %s:%s 已有 all_dirs，跳过' % (zone, room))
            continue
        if not cond_idx:
            missing.append('%s:%s（valid_leave 里没有 condition）' % (zone, room))
            continue

        # 在每条 condition 后插入 all_dirs = true（用 condition 行的缩进）
        new_block = []
        for l in block:
            new_block.append(l)
            m = COND.match(l)
            if m and 'dir' not in m.group(2):
                new_block.append('%sall_dirs = true' % m.group(1))

        if new_block == block:
            print('  %s:%s 无需改动' % (zone, room))
            continue

        lines[v_start:v_end] = new_block

        if apply_:
            open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))

        done += 1
        print('  %s:%s 标记 all_dirs（%d 条条件）'
              % (zone, room, sum(1 for l in new_block if COND.match(l))))

    print()
    print('共处理 %d 个房间' % done)
    if missing:
        print('未处理:')
        for m in missing:
            print('  ' + m)
    if not apply_:
        print('(dry-run，未写入；加 --apply 生效)')


if __name__ == '__main__':
    main()