"""补 shaolin:dmyuan2 缺失的心法书物品（/clone/book/xisuijing）。

背景
----
`shaolin/dmyuan2.c` 的 valid_leave 是：

    if (! present("xisui jing", this_object()))
        return notify_fail("本寺最高心法不见了，你怎敢就走？\n");

数据里 `room_items "dmyuan2"` 引用了 `items.xisuijing.id`（来自
`set("objects", ([ "/clone/book/xisuijing" : 1 ]))`），但**全库没有这个物品块**
—— /clone/book/xisuijing.c 从未转换。引用悬空 -> parse_items 跳过 -> 房里空 ->
`present("xisui jing", this_object())` 恒假 -> `!present(...)` 恒真 ->
「心法不见了不许走」会把玩家**永久锁死在这间房**（所有方向）。

所以启用该条件前必须先把书补上。本脚本：
  1. 从 C:/files/git/mud/clone/book/xisuijing.c 转出 items 块，放进 clone_lib
  2. 把 shaolin.ucl 里那条悬空引用改成跨区引用 clone_lib.items.xisuijing.id

用法：python scripts/add_xisuijing_book.py [--apply]
"""
import os
import re
import sys
import io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_item

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
SRC = r'C:\files\git\mud\clone\book\xisuijing.c'
CLONE_LIB = os.path.join(WORLD, 'clone_lib.ucl')
SHAOLIN = os.path.join(WORLD, 'shaolin.ucl')


def esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')


def one_line(s):
    import re as _re
    s = _re.sub(r'\\[tnr]', ' ', s or '')
    s = _re.sub(r'\\', ' ', s)
    return _re.sub(r'\s+', ' ', s).strip()


def main():
    apply_ = '--apply' in sys.argv

    if not os.path.isfile(SRC):
        print('源文件不存在: %s' % SRC)
        return

    lib = open(CLONE_LIB, encoding='utf-8').read()
    if 'items "xisuijing"' in lib:
        print('clone_lib 已有 xisuijing，跳过新增')
    else:
        d = lpc_item.extract(SRC)
        d['verbs'] = lpc_item.infer_verbs(d.get('_inherits', []), d)

        name = one_line(d.get('name')) or '洗髓'
        desc = one_line(d.get('long')) or name
        verbs = d.get('verbs') or ['get', 'drop', 'study']

        # set_name 的 id 表
        raw = open(SRC, encoding='utf-8', errors='replace').read()
        m2 = re.search(r'set_name\s*\((.*?)\)\s*;', raw, re.S)
        alias_src = m2.group(1) if m2 else ''

        block = ['# Source: C:/files/git/mud/clone/book/xisuijing.c', '# Zone: clone_lib', '']
        block.append('    items "xisuijing" {')
        block.append('      name = "%s"' % esc(name))
        block.append('      description = "%s"' % esc(desc))

        # 必须带上 LPC 的 id 表 —— 阻挡条件 `present("xisui jing", this_object())`
        # 就是靠它匹配的（物品 key 是 xisuijing，别名是 xisui jing）
        aliases = [one_line(a) for a in re.findall(r'"([^"]+)"', alias_src) if one_line(a)]

        if aliases:
            block.append('      aliases = [%s]'
                         % ', '.join('"%s"' % esc(a) for a in aliases))

        block.append('  verbs = [')
        for i, v in enumerate(verbs):
            block.append('    "%s"%s' % (v, ',' if i < len(verbs) - 1 else ''))
        block.append('  ]')

        meta = []
        if d.get('value') is not None:
            meta.append('        value = %d' % d['value'])
        if d.get('weight') is not None:
            meta.append('        weight = %d' % d['weight'])
        if d.get('unit'):
            meta.append('        unit = "%s"' % esc(d['unit']))
        if d.get('material'):
            meta.append('        material = "%s"' % esc(d['material']))
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
            block.append('')
            block.append('      meta = {')
            block.extend(meta)
            block.append('      }')
        block.append('    }')
        block.append('')

        print('将新增 clone_lib.items.xisuijing：name=%s' % name)
        print('  字段: value=%s weight=%s book=%s' % (d.get('value'), d.get('weight'), d.get('book')))

        if apply_:
            open(CLONE_LIB, 'w', encoding='utf-8', newline='').write(
                lib.rstrip('\n') + '\n\n' + '\n'.join(block))
            print('已写入 %s' % CLONE_LIB)

    # 修 shaolin 的悬空引用 -> 跨区
    sh = open(SHAOLIN, encoding='utf-8', newline='').read()
    if 'clone_lib.items.xisuijing.id' in sh:
        print('shaolin 引用已是跨区，无需修改')
    elif 'items.xisuijing.id' in sh:
        n = sh.count('items.xisuijing.id')
        sh2 = sh.replace('items.xisuijing.id', 'clone_lib.items.xisuijing.id')
        print('将修正 shaolin.ucl 的 %d 处悬空引用 -> clone_lib.items.xisuijing.id' % n)
        if apply_:
            open(SHAOLIN, 'w', encoding='utf-8', newline='').write(sh2)
            print('已写入 %s' % SHAOLIN)
    else:
        print('shaolin.ucl 里没有 items.xisuijing 引用')

    if not apply_:
        print('(dry-run，未写入；加 --apply 生效)')


if __name__ == '__main__':
    main()