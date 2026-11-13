#!/usr/bin/env python3
"""回填「严格对齐 LPC 尸体/生肉/篝火闭环」所需物品 meta。

数据来源：
  clone/quarry/item/meat.h        -> raw_meat / broil_to
  clone/misc/needfire.c           -> needfire no_get / no_fire
  clone/misc/corpse.c             -> corpse no_get / is_corpse
  d/xiyu/obj/fire.c               -> fire_source / fire_count
  clone/misc/wood.c, d/*/obj/*.c  -> fire_to
  clone/food/meat.c               -> 烤肉 food_supply

用法: python scripts/backfill_corpse_broil_meta.py [--apply]
不带 --apply 只做 dry-run 打印。
"""

import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")

# LPC clone/quarry/item/*.c 里 inherit "meat.h" 的 20 项，端口 UCL 实际存在 19 项
RAW_MEAT = [
    "turou", "zhurou", "lurou", "hurou", "gourou", "yangrou", "xiongrou",
    "diaorou", "eyurou", "baorou", "zhangrou", "yingrou", "xiangrou",
    "paorou", "langrou", "jizirou", "jirou", "lirou", "sherou",
]

FUEL_KEYS = {"wood", "ganchai", "shuzhi", "largewood"}

START = re.compile(r'^(\s*)items\s+"([^"]+)"\s*\{\s*$')
META_START = re.compile(r'^(\s*)meta\s*=\s*\{\s*$')


def block_end(lines, start):
    """从 items "x" { 那一行起，按花括号计数找块尾（字符串里不含花括号）。"""
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            return i
    raise ValueError("unbalanced block at line %d" % (start + 1))


def meta_end(lines, start, limit):
    depth = 0
    for i in range(start, limit):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            return i
    raise ValueError("unbalanced meta at line %d" % (start + 1))


def add_meta(lines, key, additions):
    """给 items "key" 块补 meta 键；返回 (新行列表, 是否修改)。"""
    for idx, line in enumerate(lines):
        m = START.match(line.rstrip("\r\n"))
        if not m or m.group(2) != key:
            continue

        indent = m.group(1)
        end = block_end(lines, idx)

        meta_idx = None
        for j in range(idx + 1, end):
            mm = META_START.match(lines[j].rstrip("\r\n"))
            if mm:
                meta_idx = j
                break

        body = []
        for k, v in additions.items():
            body.append('%s  %s = %s\n' % (indent, k, v))

        if meta_idx is not None:
            mend = meta_end(lines, meta_idx, end)
            existing = "\n".join(lines[meta_idx:mend])
            body = [
                pair for pair in body
                if ("%s =" % pair.split("=")[0].strip()) not in existing
            ]
            if not body:
                return lines, False
            return lines[:mend] + body + lines[mend:], True

        # 无 meta 块：整块新建，插到 items 块结束前
        new = ['%s  meta = {\n' % indent] + body + ['%s  }\n' % indent]
        return lines[:end] + new + lines[end:], True

    return lines, False


def process(path, changes, apply):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    original = list(lines)
    applied = []
    for key, additions in changes.items():
        lines, changed = add_meta(lines, key, additions)
        if changed:
            applied.append(key)

    if not applied:
        return 0

    if apply and lines != original:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.writelines(lines)

    return len(applied)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    clone_lib = os.path.join(WORLD, "clone_lib.ucl")
    changes = {}

    for key in RAW_MEAT:
        changes[key] = {
            "raw_meat": "true",
            "broil_to": '"clone_lib:meat"',
        }

    changes["meat"] = {"food": "300"}
    changes["corpse"] = {
        "is_corpse": "true",
        "no_get": '"你搬不动这具尸体。"',
    }
    changes["needfire"] = {
        "no_get": '"你也不怕烧了手？"',
        "no_fire": '"这正在燃烧啊，你的脑子是不是有问题？"',
        "aliases": '["needfire", "gou huo", "huo", "篝火"]',
    }
    changes["wood"] = {"fire_to": '"clone_lib:needfire"'}

    total = process(clone_lib, changes, args.apply)
    print("clone_lib.ucl: %d item blocks %s" % (total, "written" if args.apply else "would change"))

    # 火折（xiyu:fire）
    xiyu = os.path.join(WORLD, "xiyu.ucl")
    n = process(xiyu, {
        "fire": {"fire_source": "true", "fire_count": "10"}
    }, args.apply)
    print("xiyu.ucl: %d item blocks %s" % (n, "written" if args.apply else "would change"))

    # 各区的干柴 / 树枝 / 大木料（LPC 各自 fire() 生成 needfire）
    fuel_total = 0
    fuel_files = 0
    for path in sorted(glob.glob(os.path.join(WORLD, "*.ucl"))):
        if path in (clone_lib, xiyu):
            continue
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        keys = [k for k in FUEL_KEYS if re.search(r'items\s+"%s"\s*\{' % k, text)]
        if not keys:
            continue
        c = {k: {"fire_to": '"clone_lib:needfire"'} for k in keys}
        n = process(path, c, args.apply)
        if n:
            fuel_total += n
            fuel_files += 1
            print("  %s: %s" % (os.path.basename(path), ", ".join(keys)))

    print("fuel files: %d, blocks: %d" % (fuel_files, fuel_total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
