#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4an 定向反灌：把**数组形式** `add_action("do_x", ({"v1","v2"}))` 的 verb→handler
写进 data/world/*.ucl 的房间 `actions = { ... }` 块。

    python scripts/backfill_array_form_actions.py --room hengyang:outzigai1            # dry-run
    python scripts/backfill_array_form_actions.py --room hengyang:outzigai1 --apply    # 写盘

背景
----
`backfill_room_actions.py` 的 `ADD_ACTION_RE` 只匹配**字符串形式**
`add_action("do_x", "verb")`；LPC 里还有 26 处**数组形式**
`add_action("do_x", ({"tui","push"}))`（一个 handler 挂多个玩家动词），
冻结转换器与上述脚本都抽不到，导致这些房间的 UCL 没有 `actions` 块、
对应 `do_*` handler 在引擎里不可达（`RoomActionDispatcher` 查不到 verb）。

本脚本只补这一类，且**必须显式 `--room zone:key` 指定目标**（不做全库自动扫），
逐房验证后再推进，与 P5-4an 批次的增量纪律一致。

安全协议（同 backfill_room_actions.py / backfill_exit_vetoes.py）
  1. dry-run 默认；--apply 才写盘
  2. 写盘前把目标 zone 文件复制到 tmp/backup-array-actions-<时间戳>/
  3. 幂等：房间块内已有 `actions =` 则跳过（不重复插）
  4. 只增不改：新块插在房间块收尾 } 之前，不动任何已有行；
     写后做「插入性子序列」断言 + validate_ucl 问题集对比（行号归一化）
  5. 写盘用 `newline=''` + '\n' join（UCL 纪律：禁止 CRLF）

绝不修改任何 .c；绝不删除 sidecar。
"""
import io
import os
import re
import shutil
import subprocess
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
WORLD = os.path.join(ROOT, 'data', 'world')
MUD_ROOT = 'C:/files/git/mud'

ROOM_OPEN = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{\s*$')
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPCC = re.compile(r"^#\s*LPC:\s*(\S+)")
# 数组形式：add_action("do_x", ({"v1", "v2"})) —— group1=handler, group2=动词数组原文
# 注意 LPC 数组字面量是 `({...})`（单层圆括号包花括号），不是 `((...))`。
ADD_ACTION_ARRAY = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*(\(\s*\{[^}]*\}\s*\))""",
)


def skeleton_delta(line):
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if not in_str and ch == "#":
            break
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
            out.append(" ")
        else:
            if ch == '"':
                in_str = True
                out.append(" ")
            else:
                out.append(ch)
        i += 1
    s = "".join(out)
    return s.count("{") - s.count("}")


def norm(p):
    return p.replace("\\", "/").lower()


def room_lpc_path(zone_path, room_key):
    """从 UCL 房间块反查源 .c（块内 `# LPC: <path>` 优先，否则上一条 Generated）。"""
    lines = open(zone_path, encoding='utf-8').read().split('\n')
    depth = 0
    last_gen = None
    for i, line in enumerate(lines):
        s = line.strip()
        m = GEN.match(s)
        if m and depth == 0:
            last_gen = norm(m.group(1))
        om = ROOM_OPEN.match(line)
        if om and om.group(1) == room_key and depth == 0:
            end = find_block_close(lines, i)
            for j in range(i + 1, max(end, i + 1)):
                lm = LPCC.match(lines[j].strip())
                if lm:
                    return norm(lm.group(1))
            return last_gen
        depth += skeleton_delta(line)
    return None


def find_block_close(lines, start):
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if i >= start and depth == 0:
            return i
    return -1


def extract_array_actions(lpc_path):
    """读 .c，返回 {verb: handler}（数组形式）。"""
    full = os.path.join(MUD_ROOT, lpc_path)
    if not os.path.exists(full):
        return None
    text = open(full, encoding='utf-8', errors='replace').read()
    actions = {}
    for handler, arr in ADD_ACTION_ARRAY.findall(text):
        for verb in re.findall(r"""["']([^"']+)["']""", arr):
            actions.setdefault(verb, handler)
    return actions


def actions_block_text(actions):
    lines = ['  actions = {']
    for verb in sorted(actions):
        lines.append('    %s = "%s"' % (verb, actions[verb]))
    lines.append('  }')
    return lines


def room_has_actions(lines, start, end):
    for i in range(start + 1, end):
        if re.match(r'^\s*actions\s*=', lines[i]):
            return True
    return False


def validate_file(path):
    """validate_ucl.py <file> → 归一化问题集（行号 → N，排除 Syntax 假阳性）。"""
    try:
        out = subprocess.run(
            [sys.executable, os.path.join(ROOT, 'scripts', 'validate_ucl.py'), path],
            capture_output=True, text=True, timeout=120, cwd=ROOT)
        text = out.stdout + out.stderr
    except Exception as e:  # noqa: BLE001
        return {'VALIDATE_ERROR: %r' % (e,)}
    norm_text = re.sub(r'line \d+', 'line N', text)
    issues = set()
    for ln in norm_text.splitlines():
        s = ln.strip()
        if not s or s.startswith('✅') or 'Syntax' in s:
            continue
        issues.add(s)
    return issues


def subsequence_ok(orig_lines, new_lines):
    it = iter(new_lines)
    return all(any(l == x for x in it) for l in orig_lines)


def parse_rooms(argv):
    rooms = []
    i = 0
    while i < len(argv):
        if argv[i] == '--room' and i + 1 < len(argv):
            rooms.append(argv[i + 1])
            i += 2
            continue
        i += 1
    return rooms


def main():
    argv = sys.argv[1:]
    apply_ = '--apply' in argv
    targets = parse_rooms(argv)

    if not targets:
        print('用法: python scripts/backfill_array_form_actions.py --room <zone:key> [--room ...] [--apply]')
        print('  （dry-run 默认；--apply 才写盘，写前自动备份）')
        return 2

    by_zone = {}
    for t in targets:
        if ':' not in t:
            print('  !! --room 需为 zone:key 形式: %r' % t)
            return 2
        zone, key = t.split(':', 1)
        by_zone.setdefault(zone, {})[key] = None

    plan = {}
    gate_failures = []
    total_written = total_skipped = total_missing = 0

    for zone in sorted(by_zone):
        path = os.path.join(WORLD, zone + '.ucl')
        if not os.path.exists(path):
            print('  !! zone 文件不存在: %s' % path)
            return 2

        lines = open(path, encoding='utf-8').read().split('\n')
        orig_len = len(lines)
        written = skipped = missing = 0
        changed = False

        for room_key in sorted(by_zone[zone]):
            lpc = room_lpc_path(path, room_key)
            if not lpc:
                print('  !! %s:%s 找不到源 .c（房间块或 Generated 注释缺失）' % (zone, room_key))
                missing += 1
                continue
            actions = extract_array_actions(lpc)
            if not actions:
                print('  !! %s:%s 源 %s 无数组形式 add_action' % (zone, room_key, lpc))
                missing += 1
                continue

            room_start = None
            for i, ln in enumerate(lines):
                m = ROOM_OPEN.match(ln)
                if m and m.group(1) == room_key:
                    room_start = i
                    break
            if room_start is None:
                print('  !! %s:%s 房间块未找到' % (zone, room_key))
                missing += 1
                continue
            room_end = find_block_close(lines, room_start)
            if room_end < 0:
                missing += 1
                continue
            if room_has_actions(lines, room_start, room_end):
                print('  = %s:%s 已有 actions 块，幂等跳过' % (zone, room_key))
                skipped += 1
                continue

            block = actions_block_text(actions)
            lines[room_end:room_end] = block
            written += 1
            changed = True
            room_end += len(block)
            print('  + %s:%s <- %s  (%d verbs: %s)'
                  % (zone, room_key, lpc, len(actions), ', '.join(sorted(actions))))

        added = len(lines) - orig_len
        new_lines = lines if changed else None
        plan[path] = new_lines
        total_written += written
        total_skipped += skipped
        total_missing += missing

        before = validate_file(path)
        if new_lines is not None:
            tmpf = os.path.join(SCRIPT_DIR, 'tmp', os.path.basename(path) + '.array.tmp')
            os.makedirs(os.path.dirname(tmpf), exist_ok=True)
            with open(tmpf, 'w', encoding='utf-8', newline='') as fh:
                fh.write('\n'.join(new_lines))
            after = validate_file(tmpf)
            os.remove(tmpf)
            new_issues = after - before
            if new_issues:
                gate_failures.append((zone, sorted(new_issues)[:5]))

        print('  %s.ucl: +%d 房 / 幂等跳过 %d / 未找到 %d（预插 %d 行）'
              % (zone, written, skipped, missing, added))

    print('\n=== 规划汇总 ===')
    print('新增房间数: %d / 幂等跳过: %d / 未找到: %d' % (total_written, total_skipped, total_missing))
    if gate_failures:
        print('  !! validate_ucl 门禁失败（中止写盘）:')
        for zone, iss in gate_failures:
            print('     %s: %s' % (zone, iss))
        return 2
    print('  validate_ucl 门禁: 无新增问题 ✓')

    if not apply_:
        print('\n[DRY-RUN] 未写盘。加 --apply 执行写盘（先备份再写）。')
        return 0

    # ---- 写盘：备份 → 写 → 子序列断言 ----
    stamp = time.strftime('%Y%m%d-%H%M%S')
    backup_dir = os.path.join(SCRIPT_DIR, 'tmp', 'backup-array-actions-%s' % stamp)
    os.makedirs(backup_dir, exist_ok=True)

    for path, new_lines in plan.items():
        if new_lines is None:
            continue
        shutil.copy2(path, os.path.join(backup_dir, os.path.basename(path)))
        orig_lines = open(path, encoding='utf-8').read().split('\n')
        assert subsequence_ok(orig_lines, new_lines), '插入性子序列断言失败: %s' % path
        with open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write('\n'.join(new_lines))
        print('  已写盘 %s（备份于 %s）' % (os.path.basename(path), backup_dir))

    print('\n完成。重跑本脚本（不带 --apply）应全部「幂等跳过」。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
