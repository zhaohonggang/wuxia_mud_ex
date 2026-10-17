"""P4 回填：把 LPC valid_leave 的 notify_fail 判条件写成 UCL exit_vetoes。

    python scripts/backfill_exit_vetoes.py            # dry-run（默认）
    python scripts/backfill_exit_vetoes.py --apply    # 写盘

输入：tmp/p4_verdict.json（probe_valid_leave_candidates.exs 的分类结论，
只回填 effective 名单）+ tmp/p4_candidates.json（全量候选，用于去重对照）。

安全协议（P4/P5）：
  1. dry-run 默认；--apply 才写盘
  2. 写盘前把目标 zone 文件复制到 tmp/backup-<时间戳>/
  3. 幂等：同 (condition, message) 已存在于该房 valid_leave 则跳过
  4. 只增不改：新条目插在既有 valid_leave 列表内（或房间块尾部追加新列表），
     不动任何已有行；写后做「插入性子序列」断言 + validate_ucl 问题集对比
  5. 既有裸条目（转换器丢了守卫、只有 direction + message）不删不改——
     它们 condition 为 nil，运行时本来就跳过；新条目才是真正生效的那条

条目书写对齐既有惯例（condition → all_dirs → direction → message）。
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
VERDICT = os.path.join(ROOT, 'tmp', 'p4_verdict.json')
CANDIDATES = os.path.join(ROOT, 'tmp', 'p4_candidates.json')
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

ROOM_RE = re.compile(r'^(\s*)rooms\s+"([^"]+)"\s*\{')
VL_RE = re.compile(r'^(\s*)valid_leave\s*=\s*\[')
ENTRY_COND_RE = re.compile(r'^\s*condition\s*=\s*"(.*)"\s*$')
ENTRY_MSG_RE = re.compile(r'^\s*message\s*=\s*"(.*)"\s*$')
ENTRY_DIR_RE = re.compile(r'^\s*direction\s*=\s*(?:"([^"]*)"|(~))\s*$')


def norm(s):
    """条件/消息归一化（去重对照用）：压空白 + 去 ! 后空格。"""
    return " ".join(s.split()).replace("! ", "!").replace("( ", "(").replace(" )", ")")


def norm_dir(d):
    """方向归一：nil/""/~/"*" 都收敛到 "*"（对齐 loader to_veto_dir 语义）。"""
    if d is None:
        return "*"
    d = d.strip()
    return "*" if d in ("", "~", "*") else d


def find_block_close(lines, start):
    """rooms "x" { 的 start 行 → 配对 } 行号（括号深度计数）。"""
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if i >= start and depth == 0:
            return i
    return -1


def entry_text(cand):
    """生成一条 valid_leave 条目文本（2 空格缩进，对齐既有手写惯例）。"""
    lines = ['{', '  condition = "%s"' % cand['condition']]
    if cand.get('all_dirs'):
        lines.append('  all_dirs = true')
    d = cand['direction']
    lines.append('  direction = %s' % ('~' if d == '~' else '"%s"' % d))
    lines.append('  message = "%s"' % cand['message'])
    lines.append('}')
    return lines


def existing_entries(lines, v_start, v_end):
    """既有 valid_leave 列表里的 (condition, message, direction) 集合（归一化后）。

    方向也要一致才算重复：转换器有时把 `dir=='a'||dir=='b'` 的条件截成单个
    方向（chengdu/wuguan 只留 up），同 cond+msg 但方向更宽的条目是真缺口。
    direction 缺省按 "*"（loader 的 to_veto_dir(nil) 语义）处理。
    """
    out = set()
    cond = None
    msg = None
    for ln in lines[v_start:v_end]:
        m = ENTRY_COND_RE.match(ln)
        if m:
            cond = norm(m.group(1))
        m = ENTRY_MSG_RE.match(ln)
        if m:
            msg = norm(m.group(1))
        m = ENTRY_DIR_RE.match(ln)
        if m:
            d = m.group(1) if m.group(1) is not None else m.group(2)
            out.add((cond, msg, norm_dir(d)))
            cond = msg = None
    # 没有 direction 行的条目（转换器早期产物）：direction 记 "*"
    if cond is not None or msg is not None:
        out.add((cond, msg, '*'))
    return out


def process_zone(path, cands, apply_):
    """把一个区的候选写进对应房间块。返回 (新增数, 跳过已有数, 房间未找到, 新行数)。"""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    orig_len = len(lines)
    written = skipped = missing_room = 0
    # 同一房间可能有多条候选 → 按房间分组处理（插入会移动行号，逐条动态定位）
    by_room = {}
    for c in cands:
        by_room.setdefault(c['room'], []).append(c)

    changed = False
    for room_key in sorted(by_room):
        room_start = None
        for i, ln in enumerate(lines):
            m = ROOM_RE.match(ln)
            if m and m.group(2) == room_key:
                room_start = i
                break
        if room_start is None:
            print('  !! 房间块未找到: %s' % room_key)
            missing_room += len(by_room[room_key])
            continue
        room_end = find_block_close(lines, room_start)
        if room_end < 0:
            print('  !! 房间块未闭合: %s' % room_key)
            missing_room += len(by_room[room_key])
            continue

        # 房间块内已有 valid_leave 列表？
        v_start = None
        for i in range(room_start + 1, room_end):
            if VL_RE.match(lines[i]):
                v_start = i
                break

        for c in by_room[room_key]:
            if v_start is not None:
                # 找列表收尾 ]（房间块内、v_start 之后）
                v_end = None
                for i in range(v_start + 1, room_end):
                    if lines[i].strip() == ']':
                        v_end = i
                        break
                if v_end is None:
                    print('  !! valid_leave 列表未闭合: %s' % room_key)
                    missing_room += 1
                    continue
                have = existing_entries(lines, v_start, v_end)
                if (norm(c['condition']), norm(c['message']),
                        norm_dir(c['direction'])) in have:
                    skipped += 1
                    continue
                # 逗号必须紧跟在上一条目的 } 之后（elias 不接受 } 与 , 之间
                # 有空行 —— chengdu/wuguan 踩过：`}` 空行 `,` 直接 parse 失败）。
                # 从 ] 往前跳过空行，找到上一条目的收尾行。
                ins_at = v_end
                while ins_at - 1 > v_start and not lines[ins_at - 1].strip():
                    ins_at -= 1
                prev = lines[ins_at - 1] if ins_at - 1 >= v_start else ''
                if prev.strip() == ',':
                    # 上一条目已带尾逗号：只插条目本体
                    lines[ins_at:ins_at] = entry_text(c)
                elif VL_RE.match(prev):
                    # 空列表（只有 valid_leave = [ 和 ]）：直接放第一条
                    lines[ins_at:ins_at] = entry_text(c)
                else:
                    lines[ins_at:ins_at] = [','] + entry_text(c)
                written += 1
                changed = True
                print('  + %s: dir=%s  %s' % (room_key, c['direction'],
                                              c['condition'][:60]))
            else:
                # 无既有列表：在房间块收尾 } 前追加完整列表
                new_list = ['valid_leave = ['] + entry_text(c) + [']', '']
                lines[room_end:room_end] = new_list
                written += 1
                changed = True
                print('  + %s（新列表）: dir=%s  %s'
                      % (room_key, c['direction'], c['condition'][:56]))
                room_end += len(new_list)

    if changed and apply_:
        with open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write('\n'.join(lines))
    return written, skipped, missing_room, len(lines) - orig_len


def validate_gate():
    """validate_ucl 输出，按行号归一化后用于写前写后对比（问题集不得增长）。"""
    try:
        out = subprocess.run(
            [sys.executable, os.path.join(ROOT, 'scripts', 'validate_ucl.py')],
            capture_output=True, text=True, timeout=900, cwd=ROOT)
        text = out.stdout + out.stderr
    except Exception as e:  # noqa: BLE001
        return 'VALIDATE_ERROR: %r' % (e,)
    # 行号归一化：`file.ucl:123` → `file.ucl:N`
    return re.sub(r'(\.ucl):\d+', r'\1:N', text)


def subsequence_ok(orig_lines, new_lines):
    """插入性子序列断言：原文件每一行都按原顺序出现在新文件里。"""
    it = iter(new_lines)
    return all(any(l == x for x in it) for l in orig_lines)


def main():
    ap_ok = '--apply' in sys.argv
    with open(VERDICT, encoding='utf-8') as fh:
        verdict = json.load(fh)
    eff = verdict['effective']
    print('effective 候选: %d 条' % len(eff))

    # 按区分组
    by_zone = {}
    for c in eff:
        if c['zone'] in EXCLUDED:
            continue
        by_zone.setdefault(c['zone'], []).append(c)

    # 候选文件对照（防止 verdict 与 candidates 漂移）
    with open(CANDIDATES, encoding='utf-8') as fh:
        all_c = json.load(fh)['candidates']
    known = {(c['zone'], c['room'], c['condition']) for c in all_c}
    for c in eff:
        if (c['zone'], c['room'], c['condition']) not in known:
            print('  !! verdict 条目不在候选表内，中止: %s' % c)
            return 2

    # ---- 1. dry-run：确定哪些文件会被碰 ----
    plan = {}
    for zone in sorted(by_zone):
        path = os.path.join(WORLD, zone + '.ucl')
        if not os.path.exists(path):
            print('  !! zone 文件不存在: %s' % path)
            continue
        print('%s.ucl (%d 条)' % (zone, len(by_zone[zone])))
        w, s, m, added = process_zone(path, by_zone[zone], False)
        plan[path] = (w, s, m, added)
        print('    计划新增 %d / 幂等跳过 %d / 未找到 %d（预插 %d 行）'
              % (w, s, m, added))

    total_w = sum(v[0] for v in plan.values())
    total_s = sum(v[1] for v in plan.values())
    total_m = sum(v[2] for v in plan.values())
    print()
    print('合计: 新增 %d / 跳过 %d / 未找到 %d' % (total_w, total_s, total_m))

    if not ap_ok:
        print('(dry-run，未写入；加 --apply 生效)')
        return 0
    if total_w == 0:
        print('没有可写内容，退出。')
        return 0

    # ---- 2. 写前 validate_ucl 基线 ----
    before = validate_gate()
    print('写前 validate_ucl: %d 行输出' % len(before.splitlines()))

    # ---- 3. 备份被碰的文件（写盘前）----
    ts = time.strftime('%Y%m%d-%H%M%S')
    backup = os.path.join(ROOT, 'tmp', 'backup-p4-' + ts)
    os.makedirs(backup, exist_ok=True)
    orig_lines = {}
    for path in plan:
        shutil.copy2(path, os.path.join(backup, os.path.basename(path)))
        with open(path, encoding='utf-8') as fh:
            orig_lines[path] = fh.read().split('\n')
    print('备份 → %s' % backup)

    # ---- 4. 写盘 ----
    for path in plan:
        w, _s, _m, _a = plan[path]
        if not w:
            continue
        zone = os.path.basename(path)[:-4]
        process_zone(path, by_zone[zone], True)

    # ---- 5. 写后校验 ----
    ok = True
    for path, (w, _s, _m, _a) in plan.items():
        if not w:
            continue
        with open(path, encoding='utf-8') as fh:
            new_lines = fh.read().split('\n')
        if not subsequence_ok(orig_lines[path], new_lines):
            print('  !! 插入性断言失败: %s' % path)
            ok = False
    after = validate_gate()
    print('插入性子序列断言: %s' % ('通过' if ok else '失败'))
    if after == before:
        print('validate_ucl 问题集: 与写前一致（无新增问题）')
    else:
        new_issues = set(after.splitlines()) - set(before.splitlines())
        print('  !! validate_ucl 出现新问题 %d 行:' % len(new_issues))
        for l in list(new_issues)[:10]:
            print('     ' + l)
        ok = False
    print('\n（mix test 由调用方按协议另行执行）')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
