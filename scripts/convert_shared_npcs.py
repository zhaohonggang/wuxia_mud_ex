#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 LPC 里「被多个区共用」的 NPC 补进 `data/world/clone_lib.ucl`。

## 背景

LPC 的 `clone/` 是全服共享对象层，任何区的房间都能引用。但 LPC 作者经常图省事，
直接跨区引私有路径：

    d/baituo/jiudian.c:   "/d/city/npc/xiaoer2" : 1
    d/chengdu/northgate.c "/d/city/npc/bing"    : 1

实测有 **56 个对象被 2 个以上的区引用（215 处）**，其中 53 个是 NPC：

    /d/city/npc/bing      被 11 个区引用
    /d/city/npc/xiaoer2   被 11 个区引用
    /d/city/npc/wujiang   被  9 个区引用
    /d/beijing/npc/kid1   被  8 个区引用

按 LPC 自己的 `clone/` 约定，这些本来就该是共享对象。既然转换器把
`set("objects")` 里的路径丢成了裸 id（`npc/bing`），引用它的区就都成了悬空 ——
之前只能一区一区手工抄 NPC（bing 抄 10 个区、walker 抄 35 个区…），
那正是在给这个坏味道打补丁。

这个脚本把它们**转一份到 clone_lib**，作为共享层。
配合 loader 的 `clone_lib` 回退（`dereference_in_clone/3`），各区引用就能解析到。

用法：

    python scripts/convert_shared_npcs.py --list          # 看清单
    python scripts/convert_shared_npcs.py                 # dry-run
    python scripts/convert_shared_npcs.py --apply

清单来源：`--scan` 现场扫 LPC（扫全树约 1 分钟）；默认读内置清单。
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
LPC = r'C:\files\git\mud'

# 被 2+ 个区引用的 NPC（路径 -> 引用它的区），由 scan() 现场生成后固化到这里
SHARED_NPCS = [
    ('d/city/npc/bing', 11),
    ('d/city/npc/xiaoer2', 11),
    ('d/city/npc/wujiang', 9),
    ('d/beijing/npc/kid1', 8),
    ('d/beijing/npc/ducha', 7),
    ('d/beijing/npc/old2', 7),
    ('d/beijing/npc/old1', 6),
    ('d/city/npc/liumang', 6),
    ('d/taishan/npc/jian-ke', 6),
    ('d/beijing/npc/dipi', 5),
    ('d/beijing/npc/girl2', 5),
    ('d/beijing/npc/haoke1', 5),
    ('d/beijing/npc/shusheng1', 5),
    ('d/city/npc/liumangtou', 5),
    ('d/beijing/npc/boy1', 4),
    ('d/beijing/npc/boy2', 4),
    ('d/beijing/npc/boy3', 4),
    ('d/beijing/npc/hunhun', 4),
    ('d/beijing/npc/richman1', 4),
    ('d/beijing/npc/tiaofu', 4),
    ('d/beijing/npc/youke', 4),
    ('d/huashan/npc/haoke', 4),
    ('d/taishan/npc/dao-ke', 4),
    ('d/taishan/npc/tangzi', 4),
    ('d/wudang/npc/guest', 4),
    ('d/beijing/npc/girl1', 3),
    ('d/beijing/npc/girl4', 3),
    ('d/beijing/npc/maiyi1', 3),
    ('d/beijing/npc/maiyi2', 3),
    ('d/beijing/npc/shusheng2', 3),
    ('d/beijing/npc/tangzi', 3),
    ('d/city/npc/huoji', 3),
    ('d/kaifeng/npc/qigai', 3),
    ('d/taishan/npc/tiao-fu', 3),
    ('d/beijing/npc/duke', 2),
    ('d/beijing/npc/guanzhong', 2),
    ('d/beijing/npc/liumang', 2),
    ('d/beijing/npc/shiren', 2),
    ('d/beijing/npc/xianren', 2),
    ('d/beijing/npc/xizi1', 2),
    ('d/beijing/npc/xizi2', 2),
    ('d/beijing/npc/xizi3', 2),
    ('d/hangzhou/npc/seng', 2),
    ('d/kaifeng/npc/guanbing', 2),
    ('d/kaifeng/npc/zhukao3', 2),
    ('d/shaolin/npc/shang1', 2),
    ('d/taishan/npc/seng-ren', 2),
    ('d/village/npc/poorman', 2),
    ('d/village/npc/seller', 2),
    ('d/wudang/npc/tufei1', 2),
    ('d/wudu/npc/xuetong', 2),
    ('d/zhongzhou/npc/jiading', 2),
]

_CHAR_BLOCK = re.compile(r'^\s*characters\s+"([\w-]+)"\s*\{', re.M)
_PLACEHOLDER = re.compile(r'name\s*=\s*"Item"')
_COLD_INHERIT = re.compile(
    r'^\s*inherit\s+(EQUIP|ARMOR|ARMOR_ITEM|GENERIC_ITEM|PIN|NPC_SKELETON)\s*;\s*$', re.M)
_NON_ITEM_BASES = {'ROOM', 'BULLETIN_BOARD', 'SKILL'}


def scan():
    """现场扫 LPC：找被 2+ 区引用的 NPC。"""
    from collections import defaultdict
    cross = defaultdict(set)

    def objects_of(s):
        i = s.find('void create()')
        m = re.search(r'set\(\s*"objects"\s*,\s*\(\s*[\[\{](.*?)[\]\}]\s*\)\s*\)',
                      s[i:] if i >= 0 else s, re.S)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []

    for dp, dn, fns in os.walk(LPC):
        dn[:] = [d for d in dn if d != '.git']
        for fn in fns:
            if not fn.endswith('.c'):
                continue
            p = os.path.join(dp, fn)
            rel = os.path.relpath(p, LPC).replace('\\', '/')
            mz = re.match(r'd/([^/]+)/', rel)
            if not mz:
                continue
            try:
                s = open(p, encoding='utf-8', errors='replace').read()
            except Exception:
                continue
            for o in objects_of(s):
                mo = re.match(r'/d/([^/]+)/(npc)/(.+)$', o)
                if mo and mo.group(1) != mz.group(1):
                    cross['%s/%s/%s' % (mo.group(1), mo.group(2), mo.group(3))].add(mz.group(1))

    return sorted(((k, len(v)) for k, v in cross.items() if len(v) >= 2),
                  key=lambda kv: (-kv[1], kv[0]))


def balanced(text, i):
    j = text.index('{', i)
    d = 0
    in_s = False
    esc = False
    for k in range(j, len(text)):
        c = text[k]
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
            d += 1
        elif c == '}':
            d -= 1
            if d == 0:
                return text[i:k + 1]
    return None


def extract(text, kind):
    m = re.compile(r'^\s*%s\s+"(\w+)"\s*\{' % kind, re.M).search(text)
    return (m.group(1), balanced(text, m.start())) if m else (None, None)


def load_converter():
    import importlib.util
    spec = importlib.util.spec_from_file_location('lpc_converter', CONVERTER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def unwrap(res):
    if isinstance(res, tuple) and res and isinstance(res[0], str):
        return res[0], (res[1] if len(res) > 1 and isinstance(res[1], list) else [])
    return res, []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lpc-root', default=LPC)
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--scan', action='store_true', help='现场扫 LPC 重新生成清单')
    args = ap.parse_args()

    if args.scan:
        rows = scan()
        print('扫到被 2+ 区引用的 NPC: %d 个' % len(rows))
        for p, n in rows:
            print('    ("%s", %d),' % (p, n))
        return 0

    have = set(re.findall(r'^\s*characters\s+"([\w-]+)"',
                          io.open(OUT_UCL, encoding='utf-8').read(), re.M))

    if args.list:
        print('clone_lib 现有 characters: %d' % len(have))
        print('%-30s %5s %s' % ('LPC 路径', '区数', 'clone_lib'))
        print('-' * 56)
        for rel, n in SHARED_NPCS:
            name = os.path.splitext(os.path.basename(rel))[0]
            print('%-30s %5d %s' % (rel, n, '有' if name in have else '缺'))
        print('\n需要补: %d / %d' % (sum(1 for r, _n in SHARED_NPCS
                                        if os.path.splitext(os.path.basename(r))[0] not in have),
                                    len(SHARED_NPCS)))
        return 0

    conv = load_converter()
    added, skipped, placeholders, failed = [], [], [], []

    for rel, nzones in SHARED_NPCS:
        name = os.path.splitext(os.path.basename(rel))[0]
        if name in have:
            skipped.append(name)
            continue

        path = os.path.join(args.lpc_root, *rel.split('/')) + '.c'
        if not os.path.exists(path):
            failed.append((name, '文件不存在: %s' % rel))
            continue

        ucl, _ = unwrap(conv.convert_file(path, zone_id=ZONE, include_header=True))
        cid, blk = extract(ucl, 'characters')

        if not blk:
            # 可能是继承关系导致的空产物，补 inherit NPC 后重试
            try:
                src = io.open(path, encoding='utf-8', errors='replace').read()
            except Exception:
                src = ''

            inh = re.findall(r'^\s*inherit\s+([A-Z_]+)\s*;', src, re.M)
            if inh and all(b in _NON_ITEM_BASES for b in inh):
                failed.append((name, '不是 NPC（inherit %s）' % ','.join(inh)))
                continue

            if re.search(r'^\s*inherit\s+', src, re.M):
                failed.append((name, '转换器判不出类型（inherit %s）' % ','.join(inh)))
                continue

            import shutil
            import tempfile
            tmpdir = tempfile.mkdtemp(prefix='shared_')
            tmp = os.path.join(tmpdir, name + '.c')
            try:
                with io.open(tmp, 'w', encoding='utf-8', newline='') as f:
                    f.write('inherit NPC;\n' + src)
                ucl, _ = unwrap(conv.convert_file(tmp, zone_id=ZONE, include_header=True))
            finally:
                shutil.rmtree(tmpdir, ignore_errors=True)
            cid, blk = extract(ucl, 'characters')

        if not blk:
            failed.append((name, '产物里没有 characters 块'))
            continue

        if _PLACEHOLDER.search(blk):
            placeholders.append(name)
            have.add(name)
            print('   - %-14s 占位名，跳过' % name)
            continue

        added.append((rel, nzones, name, blk))
        have.add(name)
        print('   + %-14s <- %-28s (%d 个区引用)' % (name, rel, nzones))

    print('\n新增 %d / 已存在 %d / 占位名跳过 %d / 失败 %d'
          % (len(added), len(skipped), len(placeholders), len(failed)))

    for nm, why in failed:
        print('   ! %-14s %s' % (nm, why))

    if not args.apply:
        print('\ndry-run（加 --apply 才写入）')
        return 0

    if added:
        with io.open(OUT_UCL, 'a', encoding='utf-8', newline='') as f:
            for rel, nzones, name, blk in added:
                f.write('\n# LPC %s 被 %d 个区共用，按 clone/ 约定作为共享 NPC\n'
                        % (rel, nzones))
                f.write(blk)
                f.write('\n')
        print('已追加 %d 个 characters 块到 %s' % (len(added), OUT_UCL))

    return 0


if __name__ == '__main__':
    sys.exit(main())