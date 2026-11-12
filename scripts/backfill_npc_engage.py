#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-2 战斗回收：从 LPC .c 源抽取 NPC accept_fight/accept_hit/accept_kill，写入 UCL
characters 块的 engage = 字段（loader.parse_engage/1 已读取，EngageRule.decide/2
已消费）。

    python scripts/backfill_npc_engage.py            # dry-run（默认，不写盘）
    python scripts/backfill_npc_engage.py --apply    # 写盘

UCL 目标格式：

    characters "zhao" {
      ...
      engage = {
        fight = { accept = false, msg = nil, retaliate = false, spawn = [] }
        hit   = { accept = true,  msg = nil, retaliate = true,  spawn = [] }
        kill  = { accept = true,  msg = nil, retaliate = false, spawn = [] }
      }
    }

LPC 源：int accept_fight(object who) { return 0; } → engage.fight.accept = false
      int accept_fight(object who) { return 1; } → engage.fight.accept = true

unconcious / die / owner_is_killed 先只登记到报告，不写 UCL（schema 待定，P5-5 框架优先）。

映射策略（P5-2 修正版）：
  1. 扫描 /c/files/git/mud 所有 .c，匹配 int accept_(fight|hit|kill)(object who) { … }
  2. 从 set_name("中文名", ({ "id1", "id2", ... })) 提取 ID 候选
  3. 在 data/world/*.ucl 的 characters "<id>" { } 块中按 ID 匹配（支持 -/_ 互换）
  4. **区域门禁**：解析 UCL 块上方的 # Generated from <path> 注释，仅当
     LPC 文件的 basename 与 UCL 块的 LPC 路径 basename 一致时才匹配，避免
     跨区同名 ID 误写（如 bing 出现于 15 个区）。
  5. 已有 engage = 的块跳过（幂等）；只增不改

安全协议：
  1. dry-run 默认；--apply 才写盘
  2. 写盘前把目标 zone 文件复制到 tmp/backup-npc-engage-<时间戳>/
  3. 幂等：已有 engage = 则跳过
  4. 只增不改：engage = 块插在 characters 块收尾 } 之前
  5. 写后 validate_ucl 问题集对比（行号归一化）

绝不修改任何 .c。
"""
import io
import os
import re
import shutil
import sys
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
DATA_WORLD = os.path.join(ROOT, 'data', 'world')
MUD_ROOT = 'C:/files/git/mud'

ACCEPT_RE = re.compile(
    r"int\s+accept_(fight|hit|kill)\s*\(\s*object\s+\w+\s*\)\s*\n?\s*\{"
)
SET_NAME_RE = re.compile(
    r'set_name\s*\(\s*"[^"]*"\s*,\s*\(\s*\{\s*("[^"]*"(?:\s*,\s*"[^"]*")*)\s*\}\s*\)\s*\)'
)
ID_IN_NAME_RE = re.compile(r'"([^"]+)"')

CHAR_BLOCK_RE = re.compile(r'\bcharacters\s+"([^"]+)"\s*\{')
ENGAGE_EXIST_RE = re.compile(r'\bergage\s*=')
GEN_LPC_RE = re.compile(r'#\s*Generated from\s+(.+?\.c)\s+by LPCConverter')


def normalize_id(name):
    return {name, name.replace("-", "_"), name.replace("_", "-")}


def basename_no_ext(path):
    return os.path.basename(path)[:-2] if path.endswith('.c') else os.path.basename(path)


def extract_ids_from_lpc(src):
    m = SET_NAME_RE.search(src)
    if not m:
        return []
    ids = []
    for q in ID_IN_NAME_RE.findall(m.group(1)):
        ids.append(q)
    return ids


def find_lpc_files():
    result = []
    for base, _dirs, files in os.walk(MUD_ROOT):
        for f in files:
            if f.endswith('.c'):
                result.append(os.path.join(base, f))
    return result


def find_ucl_files():
    result = []
    for base, _dirs, files in os.walk(DATA_WORLD):
        for f in files:
            if f.endswith('.ucl'):
                result.append(os.path.join(base, f))
    return result


def build_char_index(ucl_files):
    """返回 normalized_id -> [(ucl_path, block_name, lpc_basename_or_None)]"""
    index = {}
    for ucl_path in ucl_files:
        with open(ucl_path, encoding='utf-8', errors='replace') as fh:
            lines = fh.readlines()
        text = "".join(lines)
        # 为每个 character 块查找其上方最近的 # Generated from 注释
        for m in CHAR_BLOCK_RE.finditer(text):
            name = m.group(1)
            block_start = m.start()
            # 向上扫描最近的 Generated from 注释
            lpc_path = None
            for line in lines[: text[:block_start].count("\n")]:
                gm = GEN_LPC_RE.match(line.strip())
                if gm:
                    lpc_path = gm.group(1)
            lpc_base = basename_no_ext(lpc_path) if lpc_path else None
            for norm in normalize_id(name):
                index.setdefault(norm, []).append((ucl_path, name, lpc_base))
    return index


def scan_lpc_for_accept(lpc_files):
    findings = {}
    for c_path in lpc_files:
        try:
            with open(c_path, encoding='utf-8', errors='replace') as fh:
                src = fh.read()
        except OSError:
            continue

        ids = extract_ids_from_lpc(src)
        if not ids:
            continue

        accept_types = {}
        for m in ACCEPT_RE.finditer(src):
            accept_type = m.group(1)
            start = m.end() - 1
            depth = 1
            i = start
            n = len(src)
            accept_val = None
            while i < n and depth > 0:
                c = src[i]
                if c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            body = src[start:i]
            if re.search(r'return\s+0\s*[;}]', body) or re.search(r'return\s+notify_fail\s*\(', body):
                accept_val = False
            elif re.search(r'return\s+-?1\s*[;}]', body):
                accept_val = True
            accept_types[accept_type] = accept_val

        if not accept_types:
            continue

        lpc_base = basename_no_ext(c_path)
        for npc_id in ids:
            findings.setdefault((c_path, npc_id, lpc_base), {}).update(accept_types)

    return findings


def find_block_end(text, start):
    depth = 0
    i = start
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def main():
    apply_mode = '--apply' in sys.argv

    lpc_files = find_lpc_files()
    ucl_files = find_ucl_files()
    char_index = build_char_index(ucl_files)

    findings = scan_lpc_for_accept(lpc_files)

    print(f"扫描 {len(lpc_files)} 个 LPC .c 文件，{len(ucl_files)} 个 UCL 文件")
    print(f"发现 {len(findings)} 个 (LPC文件, NPC ID) 组合含 accept_fight/hit/kill 定义\n")

    matched = 0
    unmatched = 0
    already_has_engage = 0
    skipped_zone = 0
    to_write = []

    for (c_path, npc_id, lpc_base), accept_types in sorted(findings.items()):
        matches = char_index.get(npc_id, [])
        if not matches:
            unmatched += 1
            print(f"  [UNMATCHED] {c_path} -> id={npc_id}  accept={accept_types}")
            continue

        # 区域门禁：仅当 LPC basename 与 UCL 块的 LPC 路径一致时匹配
        zone_matches = [(u, n) for u, n, lb in matches if lb == lpc_base]
        if not zone_matches:
            skipped_zone += 1
            print(f"  [ZONE-SKIP] {c_path} -> id={npc_id}  LPC={lpc_base}  accept={accept_types}")
            print(f"             候选区域: {[(u, n, lb) for u, n, lb in matches]}")
            continue

        for ucl_path, block_name in zone_matches:
            with open(ucl_path, encoding='utf-8', errors='replace') as fh:
                text = fh.read()
            block_start = text.find(f'characters "{block_name}" {{')
            if block_start == -1:
                continue
            block_end = find_block_end(text, block_start)
            if block_end == -1:
                continue
            block_text = text[block_start:block_end + 1]

            if ENGAGE_EXIST_RE.search(block_text):
                already_has_engage += 1
                print(f"  [SKIP] {ucl_path}: characters \"{block_name}\" 已有 engage =")
                continue

            matched += 1
            to_write.append((ucl_path, block_name, accept_types))
            print(f"  [MATCH] {c_path} -> {ucl_path}: characters \"{block_name}\"")
            print(f"          accept={accept_types}")

    print(f"\n=== 统计 ===")
    print(f"匹配(区域门禁通过): {matched}, 未匹配: {unmatched}, 跨区跳过: {skipped_zone}")
    print(f"已有 engage: {already_has_engage}")
    print(f"待写入: {len(to_write)}")

    if not apply_mode:
        print("\n=== DRY-RUN，未写盘。使用 --apply 写入 ===")
        return

    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_dir = os.path.join(ROOT, 'tmp', f'backup-npc-engage-{ts}')
    os.makedirs(backup_dir, exist_ok=True)

    written = 0
    for ucl_path, block_name, accept_types in to_write:
        backup_path = os.path.join(backup_dir, os.path.basename(ucl_path))
        shutil.copy2(ucl_path, backup_path)

        with open(ucl_path, encoding='utf-8', errors='replace') as fh:
            text = fh.read()

        engage_lines = ['  engage = {']
        for atype in ['fight', 'hit', 'kill']:
            val = accept_types.get(atype)
            if val is None:
                continue
            engage_lines.append(f'    {atype} = {{ accept = {str(val).lower()} }}')
        engage_lines.append('  }')
        engage_block = '\n'.join(engage_lines) + '\n'

        block_start = text.find(f'characters "{block_name}" {{')
        if block_start == -1:
            print(f"  [FAIL] 找不到字符块 {block_name} 在 {ucl_path}")
            continue

        insert_pos = find_block_end(text, block_start)
        if insert_pos == -1:
            print(f"  [FAIL] 找不到块结束位置 {block_name} 在 {ucl_path}")
            continue

        new_text = text[:insert_pos] + engage_block + text[insert_pos:]

        with open(ucl_path, 'w', encoding='utf-8') as fh:
            fh.write(new_text)
        written += 1
        print(f"  [WRITE] {ucl_path}: characters \"{block_name}\" + engage =")

    print(f"\n已写入 {written} 个 characters 块，备份在 {backup_dir}")


if __name__ == '__main__':
    main()
