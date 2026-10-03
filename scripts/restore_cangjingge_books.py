"""P3d：恢复武当藏经阁的「随机书」。

原 LPC（/d/wudang/cangjingge.c）：

    set("objects", ([
            CLASS_D("wudang") + "/daotong" : 1,
            "/clone/book/" + books[random(sizeof(books))] : 1,
            "/clone/book/" + books[random(sizeof(books))] : 1
    ]));

`books` 是一个 11 项的数组（含重复的 daodejing ×4），每次重置房间随机取 2 本。
转换时字符串拼接 + 随机下标无法解析，`books` 整个丢了，只剩两条注释。

做法：
  1. 把 books 用到的 7 个 /clone/book 物件转成 items 块，放进 clone_lib 区
     （与 P0c 的 /clone 搬运一致）
  2. 藏经阁的 room_items 里加两条**运行时候选**条目，复用 loader 已有的
     「一列表里随机取一个」机制（见 Kantele.World.Loader.parse_items/2）
  3. 删掉那两条 skipped 注释

注意：loader 是在**世界加载时**随机取一次，不是每次进房都重随（原 LPC 是
no_clean_up=0 的房间重置时重随）。这是既有机制的近似，标注在提交信息里。

用法：python scripts/restore_cangjingge_books.py [--apply]
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
CLONE_BOOK = r'C:\files\git\mud\clone\book'
WUDANG_SRC = r'C:\files\git\mud\d\wudang\cangjingge.c'
CLONE_LIB = os.path.join(WORLD, 'clone_lib.ucl')
WUDANG = os.path.join(WORLD, 'wudang.ucl')


def esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')


def one_line(s):
    """压成单行，并把 LPC 的 \\t / \\n 等转义序列还原成空格。

    不能把反斜杠原样 esc 成 `\\\\t` 塞进 UCL —— Elias 的词法器在嵌套转义上会
    直接语法错误（前面 vendor 条件那次踩过：`\"` 会截断字符串）。
    """
    import re as _re
    s = _re.sub(r'\\[tnr]', ' ', s or '')
    s = _re.sub(r'\\', ' ', s)
    return _re.sub(r'\s+', ' ', s).strip()


def render_item(key, d, src, zone):
    name = one_line(d.get('name')) or key
    desc = one_line(d.get('long')) or name
    verbs = d.get('verbs') or ['get', 'drop', 'read']

    out = ['# Source: %s' % src.replace('\\', '/'), '# Zone: %s' % zone, '']
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
        out.append('')
        out.append('      meta = {')
        out.extend(meta)
        out.append('      }')

    out.append('    }')
    out.append('')
    return out


def main():
    apply_ = '--apply' in sys.argv

    # 1) 源里的 books 数组（保留重复项，忠实原分布）
    src = open(WUDANG_SRC, encoding='utf-8', errors='replace').read()
    m = re.search(r'string\s*\*?\s*books\s*=\s*\(\{(.*?)\}\s*\)', src, re.S)
    if not m:
        print('源里找不到 books 数组')
        return
    books = re.findall(r'"([^"]+)"', m.group(1))
    uniq = []
    for b in books:
        if b not in uniq:
            uniq.append(b)
    print('books 数组 %d 项（去重 %d）: %s' % (len(books), len(uniq), books))

    # 2) 需要新建的 items
    lib_txt = open(CLONE_LIB, encoding='utf-8').read()
    missing = [b for b in uniq if ('items "%s"' % b) not in lib_txt]
    print('clone_lib 缺失的: %s' % missing)

    new_blocks = []
    for b in missing:
        p = os.path.join(CLONE_BOOK, b + '.c')
        if not os.path.isfile(p):
            print('  [skip] 源不存在: %s' % p)
            continue
        d = lpc_item.extract(p)
        d['verbs'] = lpc_item.infer_verbs(d.get('_inherits', []), d)
        new_blocks.extend(render_item(b, d, p, 'clone_lib'))
        print('  + items "%s"  %s' % (b, d.get('name')))

    if not apply_:
        print('\n(dry-run) 将新增 %d 个 items 块，并改写藏经阁 room_items' % len(missing))
        return

    # 3) 追加 items 到 clone_lib
    if new_blocks:
        lib_txt = lib_txt.rstrip('\n') + '\n\n' + '\n'.join(new_blocks)
        open(CLONE_LIB, 'w', encoding='utf-8', newline='').write(lib_txt)
        print('已写入 %s（+%d 块）' % (CLONE_LIB, len(missing)))

    # 4) 藏经阁：加两条随机候选 + 删注释
    lines = open(WUDANG, encoding='utf-8', newline='').read().split('\n')

    # 候选引用（clone_lib 跨区；保留原 books 数组的重复项，忠实原分布）
    cands = ','.join('clone_lib.items.%s.id' % b for b in books)

    drop = set()
    for i, l in enumerate(lines):
        if 'skipped unresolvable object path' in l and '/clone/book/' in l:
            drop.add(i)
    print('待删注释: %d 行' % len(drop))

    # 定位 room_items "cangjingge" 里 items 列表的收尾。
    # 注意转换器把 `]` 和最后一项放在同一行（`{ id = items.daotong.id }    ]`），
    # 所以不能「往下找第一个只含 ] 的行」——那样会跑到别的房间里去。
    start = None
    for i, l in enumerate(lines):
        if re.match(r'\s*room_items\s+"cangjingge"\s*\{', l):
            start = i
            break
    if start is None:
        print('找不到藏经阁 room_items')
        return

    close_line = None
    for j in range(start, min(start + 16, len(lines))):
        if ']' in lines[j] and 'items = [' in lines[j]:
            continue
        if ']' in lines[j]:
            close_line = j
            break
    if close_line is None:
        print('找不到藏经阁 items 列表收尾')
        return

    head, sep, tail = lines[close_line].partition(']')
    head = head.rstrip()
    if head and not head.endswith(','):
        head += ','

    picks = ['      { id = [%s] },' % cands, '      { id = [%s] }' % cands]
    new_line = head + '\n' + '\n'.join(picks) + '\n    ' + sep + tail

    print('插入点: 第 %d 行 -> %s' % (close_line + 1, lines[close_line].strip()[:50]))

    out = []
    for i, l in enumerate(lines):
        if i in drop:
            continue
        if i == close_line:
            out.append(new_line)
            continue
        out.append(l)

    open(WUDANG, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    print('已写入 %s：藏经阁 +2 条随机书候选，删 %d 行注释' % (WUDANG, len(drop)))


if __name__ == '__main__':
    main()