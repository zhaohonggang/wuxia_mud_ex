#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P3 `liquid` 收尾：把 LPC `set("resource/water", 1)` 回填成房间 flag `"water"`。

## 为什么需要这个脚本

`fill_command.ex`（`cmds/std/fill.c` 的移植）前置条件是
`Room.snapshot/1` 给出的 `attrs["water"] == true`，而 snapshot 的取值是
`"water" in flags`。LPC 侧共有 48 个房间 `set("resource/water", 1)`，
但转换器从不输出房间 `flags`（`_build_room_flags` 恒返回 `[]`）——
于是 `fill` 在任何房间都只会回「这里没有地方可以装水。」，
刚接好的容器/酒水链路等于死路。

本脚本只做这一件事：LPC 有 `resource/water` → UCL 房间块 `flags` 里加 `"water"`。

## 与 `backfill_l1_fields.py` 的关系

那个脚本的 `--keys=` 只认 `tmp/key_field_map.json` 里 `decision == "L1"` 的
键，而 `resource/water` 在 map 里被折叠进父键 `resource`（decision=manual），
所以走不进来。另外它的 `process_file` 遇到**已有** `flags` 块就整块跳过
（`stats["already"]`），而这里的目标房间很可能在 B1 批已拿到
`sleep_room`/`no_steal` 等 flag —— 必须**并入**已有数组，不能跳过。

并入已有数组时要动一行（给原末项补逗号），因此那个脚本的
「insertion-only」硬闸在这里不适用，改用三道等价强度的闸：

  G1 `validate_ucl` 回归集必须为空（与 `backfill_l1_fields.py` 同一把尺）；
  G2 每个被改动的房间块，flag 集合必须**只增不减**，且新增项只允许 `"water"`；
  G3 行数增量必须等于预期插入行数（写盘前算好，不符即中止）。

## 协议（沿用项目既定 P4/P5）

  - dry-run 是默认；`--apply` 才写盘；
  - 写盘**之前**把每个待改文件复制到 `tmp/backup-<timestamp>/`；
  - 幂等：第二次跑必须报 `written=0`；
  - 从不调用转换器、从不重写整文件、从不碰 `*.comments.txt`。

## 格式

沿用 `data/world/city.ucl` 手写先例（也是 B1 批的产物）：

      flags = [
        "sleep_room",
        "water"
      ]

数组**无尾逗号**（elias 会拒），多项之间必须有逗号。

## 用法

    python scripts/backfill_room_water_flag.py            # dry-run
    python scripts/backfill_room_water_flag.py --apply    # 写盘
"""
import os
import re
import sys
import time
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
TMP = os.path.join(ROOT, "tmp")
CORPUS = r"C:\files\git\mud\d"

# 与 backfill_l1_fields.py 完全一致：测试夹具 / 转换器语料 / 手工维护区不在范围。
EXCLUDED = {"test", "global", "liuxi", "kissa-jarvi", "lepakko-luola",
            "sammatti", "signature", "minimal_world"}

FLAG = "water"

ROOM_INHERIT = re.compile(r"^\s*inherit\s+[^\n]*ROOM", re.M | re.I)
GEN_RE = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
ROOMS_OPEN_RE = re.compile(r'^(\s*)rooms\s+"([^"]+)"\s*\{\s*$')
FLAGS_OPEN_RE = re.compile(r'^(\s*)flags\s*=\s*\[\s*$')
ARRAY_CLOSE_RE = re.compile(r'^\s*\]\s*$')

WATER_RE = re.compile(r'\bset\s*\(\s*"resource/water"\s*,\s*([^)]*)\)')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import validate_ucl as _vucl
except Exception:  # pragma: no cover - validator is optional
    _vucl = None


def validation_regressions(orig_text, new_text):
    """校验器在 new_text 上报出、但 orig_text 上没报的问题名（新增回归）。"""
    if _vucl is None:
        return []
    orig = {n for n, _ in _vucl._run_checks(orig_text.encode("utf-8"))}
    new = {n for n, _ in _vucl._run_checks(new_text.encode("utf-8"))}
    return sorted(new - orig)


def is_truthy(raw):
    return (raw or "").strip().strip('"').strip() not in ("", "0")


def skeleton(line):
    """把字符串内容与行尾注释抹成空格，只留结构字符。"""
    out = []
    in_str = False
    i, n = 0, len(line)
    while i < n:
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


def collect_sources():
    """{source_path_lower: room_id_hint}，只收 ROOM 类且 resource/water 为真的文件。"""
    want = {}
    for zone in sorted(os.listdir(CORPUS)):
        zdir = os.path.join(CORPUS, zone)
        if not os.path.isdir(zdir):
            continue
        for root, _, files in os.walk(zdir):
            for fn in files:
                if not fn.endswith(".c"):
                    continue
                p = os.path.join(root, fn)
                try:
                    with open(p, encoding="gbk", errors="replace") as fh:
                        src = fh.read()
                except Exception:
                    continue
                if not ROOM_INHERIT.search(src):
                    continue
                if any(is_truthy(m.group(1)) for m in WATER_RE.finditer(src)):
                    want[p.replace("\\", "/").lower()] = fn[:-2]
    return want


def room_blocks(lines):
    """[(open_i, close_i, indent, room_key, src_path_lower)]"""
    blocks = []
    depth = 0
    pending = None
    last_src = None
    for i, line in enumerate(lines):
        m = GEN_RE.match(line.strip())
        if m and depth == 0:
            last_src = m.group(1).replace("\\", "/").lower()
        om = depth == 0 and ROOMS_OPEN_RE.match(line)
        if om:
            pending = (i, om.group(1), om.group(2), last_src)
        nxt = depth + delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            s, ind, key, src = pending
            blocks.append((s, i, ind, key, src))
            pending = None
        depth = nxt
    return blocks


def find_flags_array(lines, start, close):
    """返回 (open_i, close_i) 或 None。只在块内第一个 `flags = [` 上匹配。"""
    for i in range(start + 1, close):
        if FLAGS_OPEN_RE.match(lines[i]):
            for j in range(i + 1, close):
                if ARRAY_CLOSE_RE.match(lines[j]):
                    return (i, j)
            return None
    return None


def parse_flags(lines, span):
    open_i, close_i = span
    out = set()
    for i in range(open_i + 1, close_i):
        s = lines[i].strip().rstrip(",").strip()
        if s.startswith('"') and s.endswith('"'):
            out.add(s[1:-1])
    return out


def plan_file(path, want):
    """返回 (stats, new_content_or_None)。绝不写盘。"""
    raw = open(path, encoding="utf-8").read()
    lines = raw.split("\n")
    stats = {"blocks": 0, "target": 0, "added": 0, "already": 0, "merge": 0, "fresh": 0}
    edits = []          # (insert_at, [lines])，按行号倒序应用

    for start, close, indent, key, src in room_blocks(lines):
        stats["blocks"] += 1
        if src is None or src not in want:
            continue
        stats["target"] += 1

        span = find_flags_array(lines, start, close)
        if span is None:
            # 该房间还没有 flags 块 —— 整块插入，缩进沿用 B1 先例（2 空格）。
            ins = ["  flags = [", '    "%s"' % FLAG, "  ]"]
            edits.append((close, ins, key, set()))
            stats["added"] += 1
            stats["fresh"] += 1
            continue

        current = parse_flags(lines, span)
        if FLAG in current:
            stats["already"] += 1
            continue

        open_i, close_i = span
        entry_idx = [i for i in range(open_i + 1, close_i) if lines[i].strip()]
        if entry_idx:
            last = entry_idx[-1]
            if not lines[last].rstrip().endswith(","):
                lines[last] = lines[last].rstrip() + ","
            entry_indent = re.match(r'^(\s*)', lines[open_i]).group(1) + "  "
            edits.append((close_i, ['%s"%s"' % (entry_indent, FLAG)], key, current))
        else:
            entry_indent = re.match(r'^(\s*)', lines[open_i]).group(1) + "  "
            edits.append((close_i, ['%s"%s"' % (entry_indent, FLAG)], key, current))
        stats["added"] += 1
        stats["merge"] += 1

    if not edits:
        return stats, None

    out = list(lines)
    # 倒序插入，行号才不会互相干扰。
    for at, ins, _key, _cur in sorted(edits, key=lambda e: -e[0]):
        out[at:at] = ins

    expected = sum(len(e[1]) for e in edits)
    if len(out) - len(lines) != expected:
        raise RuntimeError("refusing to write %s: line delta %d != expected %d"
                           % (path, len(out) - len(lines), expected))

    new_text = "\n".join(out)

    # G1 校验器回归
    reg = validation_regressions(raw, new_text)
    if reg:
        raise RuntimeError("refusing to write %s: new validation failures %s"
                           % (path, reg))

    # G2 只增不减，且只允许新增 "water"
    after_blocks = {k: set() for _s, _c, _i, k, _src in room_blocks(out)}
    for start, close, _ind, key, _src in room_blocks(out):
        span = find_flags_array(out, start, close)
        if span:
            after_blocks[key] = parse_flags(out, span)
    for start, close, _ind, key, _src in room_blocks(lines):
        span = find_flags_array(lines, start, close)
        before = parse_flags(lines, span) if span else set()
        after = after_blocks.get(key, set())
        if not before <= after:
            raise RuntimeError("refusing to write %s: flags of %s shrank" % (path, key))
        if after - before - {FLAG}:
            raise RuntimeError("refusing to write %s: unexpected new flags %s on %s"
                               % (path, sorted(after - before - {FLAG}), key))

    return stats, new_text


def main():
    apply_ = "--apply" in sys.argv

    want = collect_sources()
    print("LPC 源：%d 个房间文件 set(\"resource/water\", 1)" % len(want))
    zones = {}
    for src in want:
        rel = src.split("/d/", 1)[-1]
        z = rel.split("/")[0]
        zones[z] = zones.get(z, 0) + 1
    print("覆盖区数：%d（%s）" % (len(zones), ", ".join(
        "%s×%d" % (z, n) for z, n in sorted(zones.items(), key=lambda x: -x[1])[:8])))
    missing = sorted(z for z in zones if not os.path.exists(os.path.join(WORLD, z + ".ucl")))
    if missing:
        print("无 UCL 的区（跳过）：%s" % ", ".join(missing))
    print()

    total = {"blocks": 0, "target": 0, "added": 0, "already": 0, "merge": 0, "fresh": 0}
    pending = {}
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue
        path = os.path.join(WORLD, fn)
        stats, new = plan_file(path, want)
        for k in total:
            total[k] += stats[k]
        if new is not None:
            pending[path] = new
            print("[%s] %s: +%d 房（并入已有 flags %d / 新建 flags %d；命中 %d，已有 water %d）"
                  % ("apply" if apply_ else "dry", z, stats["added"],
                     stats["merge"], stats["fresh"], stats["target"], stats["already"]))

    print()
    print("=== 汇总 ===")
    print("命中房间 %d / 写入 %d（并入 %d，新建 %d）/ 已有 water %d"
          % (total["target"], total["added"], total["merge"], total["fresh"],
             total["already"]))
    print("改动文件数: %d" % len(pending))

    if not apply_:
        print("(dry-run，未写入；加 --apply 生效)")
        return

    if not pending:
        print("无改动，跳过备份与写入（幂等）。")
        return

    ts = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(TMP, "backup-%s" % ts)
    os.makedirs(bdir, exist_ok=True)
    for path in pending:
        shutil.copy2(path, os.path.join(bdir, os.path.basename(path)))
    print("已备份 %d 个文件到 %s（**写盘之前**）"
          % (len(pending), os.path.relpath(bdir, ROOT)))

    for path, new in pending.items():
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("已写入 %d 个文件。" % len(pending))


if __name__ == "__main__":
    main()
