#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-1a2 回填：把房间级 `actions = { verb = "handler" }` 写进 data/world/*.ucl。

    python scripts/backfill_room_actions.py            # dry-run（默认，不写盘）
    python scripts/backfill_room_actions.py --apply    # 写盘

背景
----
P5-1a（commit 9d185a57）已在 Room 结构体加 `actions` 字段 + loader 读入
UCL `actions = { verb = "handler" }`，但全库尚无任何房间写过 `actions`。
本脚本把 LPC `add_action("do_move", "move")` 的 verb→handler 回源回填进房间块。

方向（已对齐冻结转换器 + NPC UCL，见 survey_room_actions_backfill.py 注释）：
LPC `add_action(handler_func, player_verb)` → UCL `actions = { "move" = "do_move" }`。

映射权威性（续做 12 / D24 + 本轮修正）
--------------------------------
不从 .c 路径推断 room id（路径形态不统一：d/dali/chahua1.c vs
d/room/caihong/houyuan.c）。改为从 UCL 房间块本身反查：每个 `rooms "key" { }`
的真实 room id = "#{zone}:#{key}"，块内 `# LPC: <path>` 给出源 .c。这样无论
路径怎么变，映射都权威正确。

安全协议（P4/P5，与 backfill_exit_vetoes.py 同形）
  1. dry-run 默认；--apply 才写盘
  2. 写盘前把目标 zone 文件复制到 tmp/backup-room-actions-<时间戳>/
  3. 幂等：房间块内已有 `actions =` 则跳过（不重复插）
  4. 只增不改：新块插在房间块收尾 } 之前，不动任何已有行；
     写后做「插入性子序列」断言 + 逐文件 validate_ucl 问题集对比（行号归一化）
  5. 动态 verb（add_action(变量, ...)）无法静态抽取 → 跳过并登记

绝不修改任何 .c；绝不删除 sidecar。
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
WORLD = os.path.join(ROOT, 'data', 'world')
MUD_ROOT = 'C:/files/git/mud'

EXCLUDED_ZONES = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola',
                  'sammatti', 'signature', 'clone_lib', 'test_generic',
                  'test_generic_1', 'test_generic_2', 'test_minimal_world_v2',
                  'test_minimal_world_v2_modified'}

ROOM_OPEN = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{\s*$')
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPCC = re.compile(r"^#\s*LPC:\s*(\S+)")
# add_action(handler_func, player_verb[, flag]) —— group1=handler, group2=verb
ADD_ACTION_RE = re.compile(
    r"""add_action\s*\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']""",
)
ADD_ACTION_DYN = re.compile(r"add_action\s*\(\s*(?![\"'])")


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


def build_room_index():
    """返回 room_id -> (zone, key, lpc_path)。从 UCL 房间块反查，权威。"""
    index = {}
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        zone = fn[:-4]
        if zone in EXCLUDED_ZONES:
            continue
        lines = open(os.path.join(WORLD, fn), encoding='utf-8').read().split('\n')
        depth = 0
        pending = None
        last_gen = None
        for i, line in enumerate(lines):
            s = line.strip()
            m = GEN.match(s)
            if m and depth == 0:
                last_gen = norm(m.group(1))
            if depth == 0:
                om = ROOM_OPEN.match(line)
                if om:
                    pending = (om.group(1), i)
            nxt = depth + skeleton_delta(line)
            if pending is not None and depth != 0 and nxt == 0:
                key, start = pending
                src = None
                for j in range(start + 1, i):
                    lm = LPCC.match(lines[j].strip())
                    if lm:
                        src = norm(lm.group(1))
                        break
                if src is None:
                    src = last_gen
                room_id = "%s:%s" % (zone, key)
                if src:
                    index[room_id] = (zone, key, src)
                pending = None
            depth = nxt
    return index


def extract_actions(lpc_path):
    """读 .c，返回 (actions: {verb: handler}, dyn_count)。"""
    full = os.path.join(MUD_ROOT, lpc_path)
    actions = {}
    dyn = 0
    if not os.path.exists(full):
        return actions, dyn, False
    text = open(full, encoding='utf-8', errors='replace').read()
    for handler, verb in ADD_ACTION_RE.findall(text):
        actions.setdefault(verb, handler)
    dyn = len(ADD_ACTION_DYN.findall(text))
    return actions, dyn, True


def find_block_close(lines, start):
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if i >= start and depth == 0:
            return i
    return -1


def actions_block_text(actions):
    """生成 actions 块文本（2 空格外层 / 4 空格内层，对齐既有 messages 惯例）。

    键用裸标识符（与 messages 块的 wield/unequip 同形；elias 支持 CJK 裸键，
    见框架探针 乾 = rooms.bagua7.id）。值为 handler 函数名，始终加引号。
    """
    lines = ['  actions = {']
    for verb in sorted(actions):
        handler = actions[verb]
        lines.append('    %s = "%s"' % (verb, handler))
    lines.append('  }')
    return lines


def room_has_actions(lines, start, end):
    for i in range(start + 1, end):
        if re.match(r'^\s*actions\s*=', lines[i]):
            return True
    return False


def process_zone(path, plan_for_zone):
    """把该区所有候选房间的 actions 块插进房间块收尾 } 之前。
    返回 (新增房间数, 幂等跳过数, 未找到数, 新增行数, 新行列表 or None)。
    plan_for_zone: { room_key: {verb: handler} }。
    """
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    orig_len = len(lines)
    written = skipped = missing = 0
    changed = False

    for room_key in sorted(plan_for_zone):
        room_start = None
        for i, ln in enumerate(lines):
            m = ROOM_OPEN.match(ln)
            if m and m.group(1) == room_key:
                room_start = i
                break
        if room_start is None:
            missing += 1
            continue
        room_end = find_block_close(lines, room_start)
        if room_end < 0:
            missing += 1
            continue
        if room_has_actions(lines, room_start, room_end):
            skipped += 1
            continue
        block = actions_block_text(plan_for_zone[room_key])
        # 插在收尾 } 之前；若 } 紧贴上一内容，追加块即可（块自带换行结构）
        lines[room_end:room_end] = block
        written += 1
        changed = True
        room_end += len(block)

    added = len(lines) - orig_len
    new_lines = lines if changed else None
    return written, skipped, missing, added, new_lines


def validate_file(path):
    """validate_ucl.py <file> → 归一化问题集（行号 → N，排除不可靠的 Syntax 检查）。

    注意：validate_ucl.py 的 Syntax 解析器不支持任何嵌套 map（key = { ... }），
    而 features / messages / armor_prop / actions 等 map 字段在真实文件里比比皆是，
    必然触发 `expected '='` 假阳性。故 Syntax 行不参与「新增问题」比对；
    真正的语法正确性由 elias（运行时 + 全量 mix test）判定。这里保留的
    Encoding / Chars / Structure / Integrity 才是可靠的回归护栏。
    """
    try:
        out = subprocess.run(
            [sys.executable, os.path.join(ROOT, 'scripts', 'validate_ucl.py'), path],
            capture_output=True, text=True, timeout=120, cwd=ROOT)
        text = out.stdout + out.stderr
    except Exception as e:  # noqa: BLE001
        return {'VALIDATE_ERROR: %r' % (e,)}
    # 行号归一化：`(line 100)` → `(line N)`，避免插入导致行号位移误判为新问题
    norm_text = re.sub(r'line \d+', 'line N', text)
    issues = set()
    for ln in norm_text.splitlines():
        s = ln.strip()
        if not s:
            continue
        if s.startswith('✅'):       # 全部通过 → 无问题（行内含路径，不可直接比较）
            continue
        if 'Syntax' in s:   # 解析器不支持 map，假阳性，排除
            continue
        issues.add(s)
    return issues


def subsequence_ok(orig_lines, new_lines):
    it = iter(new_lines)
    return all(any(l == x for x in it) for l in orig_lines)


def main():
    apply_ = '--apply' in sys.argv
    index = build_room_index()
    print('UCL 房间索引条目: %d' % len(index))

    # 收集候选：每个房间从其源 .c 抽 actions
    candidates = {}          # room_id -> {verb: handler}
    dyn_rooms = []
    missing_src = 0
    for room_id, (zone, key, lpc) in index.items():
        actions, dyn, ok = extract_actions(lpc)
        if not ok:
            missing_src += 1
            continue
        if actions:
            candidates[room_id] = actions
        if dyn:
            dyn_rooms.append(room_id)

    print('候选房间（含字面量 actions）: %d' % len(candidates))
    print('动态 verb 房间（跳过）: %d' % len(dyn_rooms))
    if missing_src:
        print('  源 .c 缺失: %d' % missing_src)

    # 按 zone 分组
    by_zone = {}
    for room_id, acts in candidates.items():
        zone = room_id.split(':', 1)[0]
        if zone in EXCLUDED_ZONES:
            continue
        key = room_id.split(':', 1)[1]
        by_zone.setdefault(zone, {})[key] = acts

    # ---- dry-run / 写前规划 ----
    plan = {}          # path -> (written, skipped, missing, added, new_lines)
    gate_failures = []
    total_written = total_skipped = total_missing = 0
    for zone in sorted(by_zone):
        path = os.path.join(WORLD, zone + '.ucl')
        if not os.path.exists(path):
            print('  !! zone 文件不存在: %s' % path)
            continue
        w, s, m, added, new_lines = process_zone(path, by_zone[zone])
        total_written += w
        total_skipped += s
        total_missing += m
        plan[path] = (w, s, m, added, new_lines)
        # 逐文件 validate 门禁：before vs after（after 用 new_lines 落临时文件）
        before = validate_file(path)
        if new_lines is not None:
            tmpf = os.path.join(SCRIPT_DIR, 'tmp',
                                os.path.basename(path) + '.p5a2.tmp')
            with open(tmpf, 'w', encoding='utf-8', newline='') as fh:
                fh.write('\n'.join(new_lines))
            after = validate_file(tmpf)
            os.remove(tmpf)
            new_issues = after - before
            if new_issues:
                gate_failures.append((zone, sorted(new_issues)[:5]))
        print('  %s.ucl: +%d / 幂等跳过 %d / 未找到 %d（预插 %d 行）'
              % (zone, w, s, m, added))

    print('\n=== 规划汇总 ===')
    print('全库新增房间数: %d / 幂等跳过: %d / 未找到: %d'
          % (total_written, total_skipped, total_missing))
    if gate_failures:
        print('  !! validate_ucl 门禁失败（以下区出现新问题，中止写盘）:')
        for zone, iss in gate_failures:
            print('     %s: %s' % (zone, iss))
        return 2
    print('  validate_ucl 门禁: 全库无新增问题 ✓')

    if not apply_:
        print('\n[DRY-RUN] 未写盘。加 --apply 执行写盘（先备份再写）。')
        return 0

    # ---- --apply：先备份，后写盘 ----
    ts = __import__('datetime').datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_dir = os.path.join(SCRIPT_DIR, 'tmp', 'backup-room-actions-' + ts)
    os.makedirs(backup_dir, exist_ok=True)
    written_files = 0
    for path, (w, s, m, added, new_lines) in plan.items():
        if new_lines is None:
            continue
        orig = open(path, encoding='utf-8').read()
        # 插入性子序列断言
        orig_lines = orig.split('\n')
        if not subsequence_ok(orig_lines, new_lines):
            print('  !! 插入性断言失败，跳过: %s' % path)
            continue
        # 备份（写盘之前）
        shutil.copy2(path, os.path.join(backup_dir, os.path.basename(path)))
        with open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write('\n'.join(new_lines))
        written_files += 1
    print('\n[APPLY] 写盘完成：%d 个区文件；备份目录 %s' % (written_files, backup_dir))
    print('下一步：跑 mix test / 探针确认 loader 读入 actions，然后提交。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
