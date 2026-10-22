#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4x 调查脚本：交叉对照 86 个含 ask_me/ask_me_1/ask_me_2 的 LPC 文件
与 UCL character block，找出：
  1. 完全缺失 character block 的 NPC（需新建 block，如 wudang_zhang/wudu_qiyunao）
  2. 有 character block 但缺 inquiries 的 NPC（需补 inquiries）
  3. 已有 inquiries 的 NPC（已完成）

输出：markdown 报告，按区域/门派分组。
"""
import os
import re
import glob

ROOT = r"C:\files\git\wuxia_mud_ex"
LPC_ROOT = os.path.join(ROOT, "tmp", "conv_sandbox")
UCL_DIR = os.path.join(ROOT, "data", "world")

# ---------------------------------------------------------------------------
# 第一步：扫描所有 UCL 文件，收集 character block 名称 -> 所在文件
# ---------------------------------------------------------------------------
# 匹配 `    characters "name" {` 或 `characters "name" {`（顶级 block）
CHAR_BLOCK_RE = re.compile(r'^(?:\s*)characters\s+"([^"]+)"\s*\{', re.MULTILINE)

ucl_chars = {}  # char_name -> ucl_file
for ucl_path in sorted(glob.glob(os.path.join(UCL_DIR, "*.ucl"))):
    try:
        with open(ucl_path, "r", encoding="utf-8") as f:
            text = f.read()
    except Exception:
        continue
    for m in CHAR_BLOCK_RE.finditer(text):
        name = m.group(1)
        ucl_chars.setdefault(name, []).append(os.path.basename(ucl_path))

print(f"UCL 共找到 {len(ucl_chars)} 个 character block")

# ---------------------------------------------------------------------------
# 第二步：扫描所有 LPC 文件，提取 ask_me/ask_me_1/ask_me_2 用法 + NPC 名称
# ---------------------------------------------------------------------------
# NPC 名称：set_name("名字", ({...}))
SET_NAME_RE = re.compile(r'set_name\s*\(\s*"([^"]+)"')
# inquiry 映射行："关键词" : (: ask_me :)
ASK_INQUIRY_RE = re.compile(r'"([^"]+)"\s*:\s*\(:\s*ask_me(?:\s*_\d+)?\s*(?:,\s*"([^"]+)")?\s*:\)')
# ask_me / ask_me_1 / ask_me_2 函数定义
ASK_ME_DEF_RE = re.compile(r'(?:mixed|string)\s+(ask_me\d*)\s*\(')

lpc_entries = []  # (file, npc_name, ask_type, inquiries[(keyword, item_arg)])

lpc_files = sorted(glob.glob(os.path.join(LPC_ROOT, "**", "*.c"), recursive=True))
for lpc_path in lpc_files:
    try:
        with open(lpc_path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except Exception:
        continue

    # 必须包含 ask_me 系列
    if not re.search(r'ask_me\d*\s*[:(]', text):
        continue

    # 提取 NPC 名称
    name_m = SET_NAME_RE.search(text)
    npc_name = name_m.group(1) if name_m else None

    # 提取 inquiry 映射
    inquiries = ASK_INQUIRY_RE.findall(text)

    # 提取 ask_me 类型
    ask_types = set(ASK_ME_DEF_RE.findall(text))
    if not ask_types:
        # 也可能只有 inquiry 映射没有函数定义（如继承自 F_MASTER）
        ask_types = {"ask_me"}

    rel = os.path.relpath(lpc_path, LPC_ROOT)
    lpc_entries.append({
        "file": rel,
        "npc_name": npc_name,
        "ask_types": ask_types,
        "inquiries": inquiries,
    })

print(f"LPC 共找到 {len(lpc_entries)} 个含 ask_me 的文件")

# ---------------------------------------------------------------------------
# 第三步：交叉对照
# ---------------------------------------------------------------------------
missing_block = []   # LPC 有 ask_me 但 UCL 没 character block
has_block_no_inq = []  # UCL 有 character block 但无 inquiries
has_inq = []         # UCL 已有 inquiries

for entry in lpc_entries:
    npc_name = entry["npc_name"]
    if not npc_name:
        continue
    # UCL character id 通常是 snake_case，从 NPC 名称或文件名推断
    # 先按 exact match，再按文件名推断
    ucl_files = ucl_chars.get(npc_name, [])
    if not ucl_files:
        # 尝试从文件名推断 character id
        stem = os.path.splitext(os.path.basename(entry["file"]))[0]
        # 常见映射：qiyunao.c -> wudu_qiyunao, zhang.c -> ...
        ucl_files = ucl_chars.get(stem, [])
    if not ucl_files:
        missing_block.append(entry)
    else:
        # 检查是否有 inquiries
        has_inquiries = False
        for ucl_file in ucl_files:
            ucl_path = os.path.join(UCL_DIR, ucl_file)
            try:
                with open(ucl_path, "r", encoding="utf-8") as f:
                    utext = f.read()
            except Exception:
                continue
            # 找到该 character block，检查是否包含 inquiries =
            cb_re = re.compile(
                r'characters\s+"' + re.escape(npc_name) + r'"\s*\{(?:\n|.){0,5000}?\}',
                re.MULTILINE
            )
            cb_m = cb_re.search(utext)
            if cb_m and re.search(r'inquiries\s*=\s*\{', cb_m.group(0)):
                has_inquiries = True
                break
        if has_inquiries:
            has_inq.append(entry)
        else:
            has_block_no_inq.append(entry)

# ---------------------------------------------------------------------------
# 输出报告
# ---------------------------------------------------------------------------
print("\n" + "=" * 70)
print("1. 完全缺失 character block 的 NPC（需新建 block）")
print("=" * 70)
for e in missing_block:
    inq_str = ", ".join(f"{k}->{i or '(无参)'}" for k, i in e["inquiries"]) if e["inquiries"] else "(无 inquiry 映射)"
    print(f"  [{e['file']}] NPC={e['npc_name']} ask_types={e['ask_types']} inquiries=[{inq_str}]")

print("\n" + "=" * 70)
print("2. 有 character block 但缺 inquiries 的 NPC（需补 inquiries）")
print("=" * 70)
for e in has_block_no_inq:
    inq_str = ", ".join(f"{k}->{i or '(无参)'}" for k, i in e["inquiries"]) if e["inquiries"] else "(无 inquiry 映射)"
    print(f"  [{e['file']}] NPC={e['npc_name']} ask_types={e['ask_types']} inquiries=[{inq_str}]")

print("\n" + "=" * 70)
print("3. 已有 inquiries 的 NPC（已完成）")
print("=" * 70)
for e in has_inq:
    inq_str = ", ".join(f"{k}->{i or '(无参)'}" for k, i in e["inquiries"]) if e["inquiries"] else "(无 inquiry 映射)"
    print(f"  [{e['file']}] NPC={e['npc_name']} ask_types={e['ask_types']} inquiries=[{inq_str}]")

print(f"\n总计：缺 block={len(missing_block)}，缺 inquiries={len(has_block_no_inq)}，已完成={len(has_inq)}")
