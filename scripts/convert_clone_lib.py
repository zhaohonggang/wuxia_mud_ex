#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 LPC `clone/` 目录转换进 `data/world/clone_lib.ucl`。

## 为什么单独一个脚本

`clone/` 在 LPC 里是**全服共享对象层**：每个对象只有一份，任何区的 NPC 都能
引用（`carry_object("/clone/weapon/blade")`）。LPC 那边有 1003 个 .c，
分布在 40 个子目录，而 `data/world/clone_lib.ucl` 只转了 87 个。

直接用 `mix kantele.convert_lpc` 有两个问题：

1. **不能增量合并** —— 它按区覆写整个 `.ucl`，会把已经手工补的内容冲掉；
2. **Elixir 转换器认不出 ANSI 常量拼的名字** ——
   `set_name(NOR + WHT "干粮" NOR, (...))` 里 `name` 参数是三个 ANSI 常量
   夹一个字面量，Elixir 版会退回占位名 `name = "Item"`。
   `clone/herb`(53) / `clone/fam/pill`(32) / `clone/medicine`(16) 整目录都是
   这种写法。`scripts/lpc_converter.py` 有 `_extract_strings_from_macro_wrapped`
   能处理，已用它修好（见 `_SET_NAME_LOOSE`）。

所以这里走 Python 路线，并自己管合并。

## 用法

    # 看看会加哪些（不写文件）
    python scripts/convert_clone_lib.py --dry-run

    # 转指定子目录
    python scripts/convert_clone_lib.py --subdirs fam/pill medicine --apply

    # 全量（默认按价值排序，逐批确认）
    python scripts/convert_clone_lib.py --apply

    # 列出候选子目录及各自「已转 / 未转」数量
    python scripts/convert_clone_lib.py --list
"""
import argparse
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONVERTER = os.path.join(ROOT, 'scripts', 'lpc_converter.py')
ZONE = 'clone_lib'
OUT_UCL = os.path.join(ROOT, 'data', 'world', ZONE + '.ucl')

DEFAULT_LPC = r'C:\files\git\mud\clone'

# 按「被引用得多 + 玩家看得见」排的价值序
PRIORITY = [
    'fam/pill',     # 随身干粮/水，shop 的 vendor_goods 直接引用
    'medicine',     # 药品
    'herb',         # 草药（cook / 制药）
    'weapon',       # 兵器，carry_object 的主要来源
    'cloth',        # 衣物
    'food',         # 食物
    'item',
    'misc',
    'book',         # 秘籍
    'lonely',
    'tattoo',
    'board',
    'questob',
    'gift',
    'shop',
    'worm',
    'quarry',       # 狩猎物，暂缓（见 docs/dangling-room-items-report §六）
]

SKIP_DIRS = {
    # 狩猎物：移植等于把狩猎玩法带回来，工作量比生成 items 块大
    # （见 docs/dangling-room-items-report.zh-CN.md §六）
    'quarry',
    # 下面这些不是「玩家能拿在手里的物品」，而是世界设施 / 事件道具。
    # 它们确实有 create() + set_name，转换器也能产出 items 块，但转进来
    # 会让玩家在背包里见到「聊天室留言板」「盖房蓝图」这类东西。
    # 实测这批文件的共同特征：注释里明写「not setup now」，
    # 或 inherit 的是 BULLETIN_BOARD / 地图 / 家园这类设施基类。
    'board',
    'questob',
    'shop',
    'worm',
    'gift',
}

_ITEM_BLOCK = re.compile(r'^\s*items\s+"(\w+)"\s*\{', re.M)
# 占位名：转换器没解析出名字时会产这个
_PLACEHOLDER_NAME = re.compile(r'name\s*=\s*"Item"')


def existing_items(path):
    if not os.path.exists(path):
        return set()
    s = io.open(path, encoding='utf-8').read()
    return set(_ITEM_BLOCK.findall(s))


def load_converter():
    import importlib.util
    spec = importlib.util.spec_from_file_location('lpc_converter', CONVERTER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def lpc_files(lpc_root, subdir):
    base = os.path.join(lpc_root, *subdir.split('/'))
    if not os.path.isdir(base):
        return []
    return sorted(
        os.path.join(base, f) for f in os.listdir(base)
        if f.endswith('.c') and not f.endswith('Bak.c')
    )


def _unwrap(res):
    """convert_file 返回 (ucl, comments, ...) 的元组；容错处理裸字符串。

    注意实际是 **3 元组**（ucl / comments / 第三个未知），不是 2 元组 ——
    早先按 2 元组解包拿到的是 tuple，害我查了两轮。
    """
    if isinstance(res, tuple) and res and isinstance(res[0], str):
        return res[0], (res[1] if len(res) > 1 and isinstance(res[1], list) else [])
    return res, []


# 转换器靠 `inherit` 判断对象类型。`clone/` 里有一批叶子对象**没有任何
# inherit**（`medicine/*.c` 只 include "medicine.h"、`herb/*.c` 连
# `#include <ansi.h>` 都没有），于是 `_determine_object_type` 判不出 ITEM，
# `convert_file` 返回**空字符串**。
#
# 对这些文件补一条 inherit 再转 —— ITEM 是它们真实的类型
# （`base_unit` / `base_value` / `base_weight` / `setup()` 都在 ITEM 的接口上）。
#
# 注意插入点：herb/*.c 连 `#include <ansi.h>` 都没有（第一行是
# `#include "herb.h"`），所以不能拿 `<ansi.h>` 当锚点，改成插在**第一行
# `#include` 之前**。
def _with_forced_inherit(src_text):
    """给没有 inherit 的叶子对象补上 `inherit ITEM;`。"""
    if re.search(r'^\s*inherit\s+', src_text, re.M):
        return src_text, False, None

    lines = src_text.split('\n')
    idx = next((i for i, l in enumerate(lines)
                if l.lstrip().startswith('#include')), None)

    if idx is None:
        # 整个文件没有 #include：插在第一行代码前
        insert_at = next((i for i, l in enumerate(lines)
                          if l.strip() and not l.strip().startswith('//')), 0)
    else:
        insert_at = idx

    lines.insert(insert_at, 'inherit ITEM;')
    return '\n'.join(lines), True, None


# 转换器不认识的基类 -> 换ITEM。
#
# 除了「没有 inherit」，还有「inherit 了冷门基类」这一类空产物：
#   clone/cloth/qingyi.c   inherit EQUIP;
# EQUIP 在 LPC 里连 equip.h 都没有，是全 clone/cloth 唯一用它的
# （其余 33 个 CLOTH / 7 个 BOOTS / 1 个 WAIST），判不出类型就返回空串。
#
# ⚠️ **这是有损替换**：基类 EQUIP 在 LPC 里可能带着我们没理解的逻辑
# （额外字段、初始化行为、装备规则…），一律按 ITEM 转可能丢掉这些。
# 所以替换时会把原基类名写进 UCL 注释，留给以后补。
_COLD_INHERIT = re.compile(
    r'^\s*inherit\s+(EQUIP|ARMOR|ARMOR_ITEM|GENERIC_ITEM)\s*;\s*$', re.M)


def _with_known_inherit(src_text):
    """把转换器不认识的基类换成 ITEM，返回 (源码, 是否改动, 原基类名)。"""
    m = _COLD_INHERIT.search(src_text)
    if m is None:
        return src_text, False, None

    out = _COLD_INHERIT.sub('inherit ITEM;', src_text)
    return out, True, m.group(1)


def convert_one_from_text(conv, src_text, name):
    """从 LPC 源码文本转换（用于补过 inherit 的情况）。"""
    try:
        ucl, comments = _unwrap(conv.convert_string(
            src_text, zone_id=ZONE, include_header=True))
    except Exception as e:                      # noqa: BLE001
        return None, '%s: %s' % (type(e).__name__, e), []

    block, why = _extract_item_block(ucl)
    if block is None:
        return None, why, []
    return block, None, comments


def _extract_item_block(ucl):
    m = _ITEM_BLOCK.search(ucl)
    if not m:
        return None, '产物里没有 items 块'

    j = ucl.index('{', m.start())
    depth = 0
    in_s = False
    esc = False
    for k in range(j, len(ucl)):
        c = ucl[k]
        if in_s:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_s = False
            continue
        if c == '"':
            in_s = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return ucl[m.start():k + 1], None
    return None, 'items 块没配平'


def convert_one(conv, path):
    """返回 (item_id, ucl_text)；失败返回 (None, reason)。"""
    try:
        ucl, _comments = _unwrap(conv.convert_file(path, zone_id=ZONE,
                                                  include_header=True))
    except Exception as e:                      # noqa: BLE001
        return None, '%s: %s' % (type(e).__name__, e)

    block, why = _extract_item_block(ucl)
    if block is not None:
        return _ITEM_BLOCK.search(ucl).group(1), block

    # 兜底：没有 inherit 的叶子对象，补 `inherit ITEM;` 重转一次。
    # clone/medicine/*.c 整目录都是这样（只 #include 头文件、不 inherit），
    # 转换器判不出对象类型时会返回空字符串。
    try:
        src = io.open(path, encoding='utf-8', errors='replace').read()
    except Exception as e:                      # noqa: BLE001
        return None, '%s / 读源文件失败: %s' % (why, e)

    patched, changed, cold = _with_forced_inherit(src)
    how = '补 inherit ITEM（原文件没有 inherit，按 ITEM 处理）'
    note = None
    if not changed:
        # 第二级：不是「没有 inherit」，而是「inherit 了转换器不认识的基类」。
        #   clone/cloth/qingyi.c  inherit EQUIP;
        # EQUIP 在 LPC 里连 equip.h 都没有，是全 clone/cloth 唯一用它的
        # （其余 33 个 CLOTH / 7 个 BOOTS / 1 个 WAIST）。
        patched, changed, cold = _with_known_inherit(src)
        how = '把继承的 %s 换成 ITEM' % cold

        if changed:
            note = (
                '# 转换器不认识的基类，原文件写的是 `inherit %s;`\n'
                '# 这里一律按 ITEM 转换 —— %s 在 LPC 里可能带着我们没移植的逻辑\n'
                '#（额外字段 / 初始化 / 装备规则…），所以这是**有损替换**。\n'
                '# 以后要补这个基类时，请从 LPC 原文重新转，别直接改这里。\n'
                '# 来源: clone/.../%s.c'
                % (cold, cold, os.path.splitext(os.path.basename(path))[0]))

    if not changed:
        return None, why

    # lpc_converter 只暴露 convert_file（没有 convert_string），所以把补过
    # inherit 的源码写到临时文件再转。
    import shutil
    import tempfile
    # 关键：临时文件**必须用原来的文件名** —— 转换器是从路径推 items 的 id
    # 的，写成 clonefix_xxx.c 的话产物 id 会变成 clonefix_xxx，一堆垃圾。
    orig_id = os.path.splitext(os.path.basename(path))[0]
    tmpdir = tempfile.mkdtemp(prefix='clonefix_')
    tmp = os.path.join(tmpdir, orig_id + '.c')
    try:
        with io.open(tmp, 'w', encoding='utf-8', newline='') as f:
            f.write(patched)
        ucl2, _c2 = _unwrap(conv.convert_file(tmp, zone_id=ZONE,
                                              include_header=True))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    block2, why2 = _extract_item_block(ucl2)
    if block2 is None:
        return None, '%s（%s 后仍失败: %s）' % (why, how, why2)

    if note:
        block2 = note + '\n' + block2

    return _ITEM_BLOCK.search(block2).group(1), block2


def unhandled_comments(conv, path):
    """产物注释里如果有 (file not found) / UNHANDLED，如实报出来。"""
    try:
        _ucl, comments = _unwrap(conv.convert_file(path, zone_id=ZONE,
                                                    include_header=True))
    except Exception:                            # noqa: BLE001
        return []
    return [c for c in comments
            if 'file not found' in c or 'UNHANDLED' in c]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lpc-root', default=DEFAULT_LPC)
    ap.add_argument('--subdirs', nargs='*', default=None,
                    help='要转的 clone 子目录，如 fam/pill；默认按 PRIORITY 全量')
    ap.add_argument('--apply', action='store_true', help='真的写入（默认 dry-run）')
    ap.add_argument('--list', action='store_true', help='只列出候选子目录')
    args = ap.parse_args()

    if not os.path.isdir(args.lpc_root):
        print('找不到 LPC clone 目录: %s' % args.lpc_root)
        return 1

    have = existing_items(OUT_UCL)
    subdirs = args.subdirs if args.subdirs else PRIORITY

    if args.list:
        print('%-14s %6s %8s %8s' % ('子目录', '文件', '已转', '未转'))
        print('-' * 40)
        for sd in PRIORITY:
            if sd in SKIP_DIRS:
                continue
            files = lpc_files(args.lpc_root, sd)
            if not files:
                continue
            names = {os.path.splitext(os.path.basename(f))[0] for f in files}
            done = len(names & have)
            print('%-14s %6d %8d %8d' % (sd, len(files), done, len(names) - done))
        return 0

    conv = load_converter()

    added = []
    skipped = []
    failed = []
    placeholders = []

    for sd in subdirs:
        if sd in SKIP_DIRS:
            print('-- 跳过 %s（狩猎系统，单独排期）' % sd)
            continue

        files = lpc_files(args.lpc_root, sd)
        if not files:
            print('-- %s: 没有 .c 文件' % sd)
            continue

        print('== %s (%d 个文件)' % (sd, len(files)))

        for path in files:
            iid = os.path.splitext(os.path.basename(path))[0]
            if iid in have:
                skipped.append(iid)
                continue

            item_id, block = convert_one(conv, path)
            if item_id is None:
                failed.append((iid, block))
                continue
            if item_id in have:
                skipped.append(item_id)
                continue

            bad = unhandled_comments(conv, path)
            flag = '  !! %d 条未处理' % len(bad) if bad else ''

            # 占位名闸门：`name = "Item"` 说明转换器没解析出名字
            # （典型是 set_name 不在 create() 里，书名走文件顶层 titles 数组）。
            # 这种定义对玩家毫无价值，**不写入**，只报出来。
            if _PLACEHOLDER_NAME.search(block):
                placeholders.append((sd, item_id))
                have.add(item_id)
                print('   - %-16s 占位名，跳过' % item_id)
                continue

            added.append((sd, item_id, block, bad))
            have.add(item_id)
            print('   + %-16s%s' % (item_id, flag))

    print('\n新增 %d / 跳过已存在 %d / 失败 %d / 占位名跳过 %d'
          % (len(added), len(skipped), len(failed), len(placeholders)))

    if failed:
        print('\n失败明细:')
        for iid, why in failed[:15]:
            print('   %-16s %s' % (iid, why))

    if placeholders:
        print('\n占位名（name="Item"）已跳过 %d 个，源文件待人工确认:'
              % len(placeholders))
        for sd, iid in placeholders[:15]:
            print('   %-12s %s' % (sd, iid))
        if len(placeholders) > 15:
            print('   ... 另有 %d 个' % (len(placeholders) - 15))

    if not args.apply:
        print('\ndry-run（加 --apply 才写入）')
        return 0

    if not added:
        print('\n没有新增，无需写入')
        return 0

    with io.open(OUT_UCL, 'a', encoding='utf-8', newline='') as f:
        for _sd, iid, block, bad in added:
            f.write('\n')
            f.write('# 来自 LPC clone/（scripts/convert_clone_lib.py 增量追加）\n')
            f.write(block)
            f.write('\n')
            for c in bad:
                f.write('# 未处理: %s\n' % c.replace('\n', ' '))

    print('已追加 %d 个 items 块到 %s' % (len(added), OUT_UCL))
    return 0


if __name__ == '__main__':
    sys.exit(main())