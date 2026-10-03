"""A 项第二步：把 LPC 外层方向守卫合并进 valid_leave 的 condition。

背景
----
转换器处理嵌套 if 时只保留最内层条件，丢掉外层的方向判断：

    if (dir != "east") return ::valid_leave(me, dir);       // ← 丢了
    if (room && present("la ma", room) && ...) {
        if ((int)me->query_skill("force") < 100) return notify_fail(...);   // ← 只留下这行

于是 UCL 里的条件对所有方向成立，运行时用 LpcCondition.direction_scoped?/1 跳过
（否则会把该房所有出口都拦掉，把人锁死）。

本脚本从 LPC 源码抽方向守卫，与内层条件合成一条完整表达式，例如：

    (int)me->query_skill('force') < 100
    -> ((int)me->query_skill('force') < 100) && dir == 'east'

**只替换 condition 那一行**，不重排块结构、不动 direction
（这些条目的 direction 本来就是 `~`，方向判断已在条件里）。

跳过的两类（合并也解决不了）
  - beijing:kediandayuan：条件依赖**目的地房间**内容
    （find_object(query("exits/east")) 后 present("la ma", room)），
    当前表达式语言无法表达「按出口名定位另一个房间」
  - huashan:bingqifang：语义是「背包里 zhujian 超过一把」，转换时整个 for 循环丢失
    只剩 `j > 1`；需要「按 id 统计背包数量」的能力
  - taishan:nantian：条件里有裸标识符 `mengzhu`（应为字符串）
  - xiyu:xxh6：`(int)this_player()->query_temp(...)` 链式调用

用法：python scripts/merge_direction_guards.py [--apply]
"""
import os
import re
import sys
import io
import collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
LPC_ROOT = r'C:\files\git\mud'
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

SKIP_ROOMS = {('beijing', 'kediandayuan'), ('huashan', 'bingqifang')}
COND_LINE = re.compile(r'^(\s*)condition = "(.*)"\s*$')
REFUSE = '->refuse('


def read_source(src):
    if not src:
        return None
    p = os.path.join(LPC_ROOT, src.replace('C:/files/git/mud/', '').replace('/', os.sep))
    if not os.path.isfile(p):
        return None
    s = open(p, encoding='utf-8', errors='replace').read()
    m = re.search(r'\bint\s+valid_leave\s*\(.*?\n\}', s, re.S)
    return m.group(0) if m else None


def extract_guards(body):
    """抽方向守卫 -> (dirs, kind)。抽不到返回 (None, None)"""
    if not body:
        return (None, None)
    ne = re.findall(r'dir\s*!=\s*"([^"]+)"', body)
    if ne:
        # `if (dir != "x") return ...` -> 守卫作用于 dir == x
        return (sorted(set(ne)), 'dir!=')
    eq = re.findall(r'dir\s*==\s*"([^"]+)"', body)
    if eq:
        return (sorted(set(eq)), 'dir==')
    return (None, None)


def merge(inner, dirs):
    if len(dirs) == 1:
        return "(%s) && dir == '%s'" % (inner, dirs[0])
    parts = ' || '.join("dir == '%s'" % d for d in dirs)
    return "(%s) && (%s)" % (inner, parts)


def unsupported_shape(c):
    if re.search(r'!=\s*[a-z_][a-z0-9_]*\s*$', c):
        return '裸标识符当值'
    if 'this_player()' in c and '->query_temp(' in c:
        return 'this_player()-> 链式调用'
    return None


def main():
    apply_ = '--apply' in sys.argv

    # (file, room) -> {(old_cond, new_cond)}
    plan = collections.defaultdict(lambda: collections.defaultdict(dict))
    unresolved = []
    collected = 0

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl') or fn[:-4] in EXCLUDED:
            continue
        z = fn[:-4]
        lines = open(os.path.join(WORLD, fn), encoding='utf-8').read().split('\n')

        # 记录每个 rooms 块的溯源
        src_of = {}
        cur = None
        last_src = None
        for l in lines:
            m = re.match(r'# Generated from (\S+) by LPCConverter', l)
            if m:
                last_src = m.group(1)
            m = re.match(r'\s*rooms\s+"([^"]+)"\s*\{', l)
            if m:
                cur = m.group(1)
                src_of[cur] = last_src

        # 已标 all_dirs 的房间（本就没有方向守卫，LPC 原意就是拦所有方向）-> 跳过
        marked = set()
        for m in re.finditer(r'rooms "([^"]+)" \{(.*?)(?=rooms "|\Z)', '\n'.join(lines), re.S):
            if 'all_dirs = true' in m.group(2):
                marked.add(m.group(1))

        # 逐行找 condition，按所在 rooms 归类
        cur = None
        for l in lines:
            m = re.match(r'\s*rooms\s+"([^"]+)"\s*\{', l)
            if m:
                cur = m.group(1)
            mc = COND_LINE.match(l)
            if not mc or cur is None:
                continue
            collected += 1
            c = mc.group(2)

            if (z, cur) in SKIP_ROOMS or cur in marked:
                continue
            if 'dir' in c:
                continue                                    # 已含方向
            if "query('gender')" in c or 'query("gender")' in c:
                continue
            if 'check_dirs' in c or 'check_out' in c or REFUSE in c:
                continue

            bad = unsupported_shape(c)
            if bad:
                unresolved.append('%s:%s（%s）' % (z, cur, bad))
                continue

            dirs, kind = extract_guards(read_source(src_of.get(cur)))
            if not dirs:
                unresolved.append('%s:%s（源码里抽不出方向守卫）' % (z, cur))
                continue

            plan[fn][cur][c] = merge(c, dirs)

    total = sum(len(v) for f in plan.values() for v in f.values())
    print('扫到 condition %d 条；将合并 %d 条' % (collected, total))

    print()
    print('=== 合并清单 ===')
    for fn in sorted(plan):
        for room in sorted(plan[fn]):
            for old, new in plan[fn][room].items():
                print('%s:%s' % (fn[:-4], room))
                print('   旧 %s' % old)
                print('   新 %s' % new)
    if unresolved:
        print('\n未处理:')
        for u in sorted(set(unresolved)):
            print('  ' + u)

    if not apply_:
        print('\n(dry-run，未写入；加 --apply 生效)')
        return

    # 逐文件只替换 condition 行，不动其它任何行
    for fn, rooms in plan.items():
        path = os.path.join(WORLD, fn)
        lines = open(path, encoding='utf-8', newline='').read().split('\n')
        cur = None
        changed = 0
        for i, l in enumerate(lines):
            m = re.match(r'\s*rooms\s+"([^"]+)"\s*\{', l)
            if m:
                cur = m.group(1)
            mc = COND_LINE.match(l)
            if mc and cur in rooms:
                old = mc.group(2)
                if old in rooms[cur]:
                    lines[i] = '%scondition = "%s"' % (mc.group(1), rooms[cur][old])
                    changed += 1
        open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
        print('已写入 %s（%d 行）' % (fn, changed))


if __name__ == '__main__':
    main()