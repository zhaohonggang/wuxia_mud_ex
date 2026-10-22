# -*- coding: utf-8 -*-
"""
backfill_chinese_key_item_desc.py — P5-4o：回填唯一尚缺的中文 key `item_desc` 闭包。

背景
----
P5-4j 扫描曾报「11 个中文 key 闭包因 UCL key 不支持中文而跳过」。但重新全量扫描
`/c/files/git/mud` 发现：真正带中文 key 的 `item_desc` 闭包只有 2 个——
  * `d/shaolin/putiyuan.c`  key="铜镜"  fn=look_jing  （score_tiers，已随 P5-4e/h 回填，且
    已含中文 key `铜镜` + ASCII 别名 `jing`）
  * `d/wudang/nanyangong.c` key="三清坐像" fn=look_xiang（静态文本）

且 `clone_lib.ucl` 早已存在中文 key（如 `铁护腕 = {`），证明 elias/validate_ucl 完全接受中文
key；`item_desc_entry/2` 用 `key == keyword or String.starts_with?` 精确匹配，中文 key 可正常命中。
所以「中文 key 不支持」是过时结论。

`look_xiang` 是纯静态文本（`YEL "..." NOR`，去掉色码即可），且 nanyangong 的 `item_desc`
里 ASCII 别名 `xiang` 早已回填，**只缺中文 key `三清坐像` 本身**。本脚本仅补这个 key。

规则 / 安全（沿用 P5-4 各批次 G1-G8 + 备份 + 幂等）
------------------------------------------------
- 偏移编辑：在 nanyangong 的 `item_desc` 闭合 `}` 前插入 `三清坐像 = "..."`。
- 已含该 key 则跳过（幂等）。
- --apply 前备份到 tmp/backup-chinesekey-<时间戳>/；validate_ucl issue-set 不变；幂等复跑 0 待改。
- 写盘用 newline="" 保留 LF（Windows 文本模式会把 \\n 翻成 \\r\\n 被 validate_ucl 拒）。

用法
----
    python scripts/backfill_chinese_key_item_desc.py            # dry-run + 门禁
    python scripts/backfill_chinese_key_item_desc.py --apply    # 备份后写盘
"""

import io
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reclassify_npc_item_blocks as R      # noqa: E402  (match_brace / validate_ucl / ROOT)
import validate_ucl as V                    # noqa: E402

ROOT = R.ROOT
UCL_FILE = os.path.join(ROOT, "data", "world", "wudang.ucl")
BACKUP_DIR = os.path.join(ROOT, "tmp", "backup-chinesekey-%s" % time.strftime("%Y%m%d-%H%M%S"))

ZONE = "wudang"
ROOM_ID = "nanyangong"
KW = "三清坐像"
# 与既有 `xiang` 条目一致（LPC: YEL "三清坐像纯铜打就……" NOR，去掉色码）。
STATIC_TEXT = "三清坐像纯铜打就，镀以纯金，光照满殿。只是好象三个坐像摆得并不很整齐。"


def encode_ucl_string(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return s


def find_room_block(text, room_id):
    m = re.search(r'rooms\s+"' + re.escape(room_id) + r'"\s*\{', text)
    if not m:
        return None
    op = text.index("{", m.end() - 1)
    cl = R.match_brace(text, op)
    if cl < 0:
        raise RuntimeError("unterminated room %r" % room_id)
    return op, cl


def find_item_desc(text, op, cl):
    """返回房间内 item_desc 块的 (open_brace_idx, close_brace_idx)，没有则 None。"""
    seg = text[op:cl]
    m = re.search(r'item_desc\s*=\s*\{', seg)
    if not m:
        return None
    base = op + m.start()
    ob = text.index("{", base)          # item_desc 的 {
    cb = R.match_brace(text, ob)
    return ob, cb


def room_item_desc_has_key(text, op, cl, key):
    ob, cb = find_item_desc(text, op, cl)
    if ob is None:
        return False
    seg = text[ob:cb]
    # 命中形如  三清坐像 = "..."   或   "三清坐像" = ...
    return re.search(r'(?:"?' + re.escape(key) + r'"?\s*=)', seg) is not None


def plan_insert(text, op, cl, entry):
    ob, cb = find_item_desc(text, op, cl)
    if ob is None:
        raise RuntimeError("%s/%s has no item_desc block" % (ZONE, ROOM_ID))
    # 在 item_desc 闭合 } 前插入（cb 是闭合 } 的索引）
    return [(cb, cb, entry)]


def apply_edits(text, edits):
    edits = sorted(edits, key=lambda e: e[0], reverse=True)
    out = text
    for start, end, rep in edits:
        out = out[:start] + rep + out[end:]
    return out


def build_entry(key, text):
    return ' %s = "%s"\n' % (key, encode_ucl_string(text))


def build_plan():
    plan = []
    text = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    loc = find_room_block(text, ROOM_ID)
    if loc is None:
        print("  SKIP %s/%s : room block not found" % (ZONE, ROOM_ID))
        return plan
    op, cl = loc
    if room_item_desc_has_key(text, op, cl, KW):
        print("  SKIP %s/%s : %s already present" % (ZONE, ROOM_ID, KW))
        return plan
    ob, cb = find_item_desc(text, op, cl)
    if ob is None:
        print("  SKIP %s/%s : no item_desc block" % (ZONE, ROOM_ID))
        return plan
    plan.append({"text": STATIC_TEXT})
    return plan


def gate(plan):
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    for p in plan:
        loc = find_room_block(text0, ROOM_ID)
        if loc is None:
            return False, ["G1 FAIL: room %s/%s not found" % (ZONE, ROOM_ID)]
        op, cl = loc
        if room_item_desc_has_key(text0, op, cl, KW):
            return False, ["G2 FAIL: %s/%s already has %s" % (ZONE, ROOM_ID, KW)]
        bad = [c for c in p["text"] if ord(c) < 32 and c not in "\n\t"]
        if bad:
            return False, ["G3 FAIL: %s/%s text has control char" % (ZONE, ROOM_ID)]
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        edits.extend(plan_insert(text0, op, cl, build_entry(KW, p["text"])))
    new_text = apply_edits(text0, edits)
    loc = find_room_block(new_text, ROOM_ID)
    op, cl = loc
    if not room_item_desc_has_key(new_text, op, cl, KW):
        return False, ["G5 FAIL: %s/%s %s missing after apply" % (ZONE, ROOM_ID, KW)]
    issues0 = set(R.normalize_issue("%s: %s" % (n, d)) for n, d in V._run_checks(text0.encode("utf-8")))
    issues1 = set(R.normalize_issue("%s: %s" % (n, d)) for n, d in V._run_checks(new_text.encode("utf-8")))
    if issues0 != issues1:
        return False, ["G6 FAIL: validate_ucl issue set changed for %s\n before=%s\n after=%s"
                       % (UCL_FILE, sorted(issues0), sorted(issues1))]
    return True, []


def main():
    apply_mode = "--apply" in sys.argv
    plan = build_plan()
    if not plan:
        print("dry-run: 0 pending (nothing to do)")
        return
    ok, msgs = gate(plan)
    if not ok:
        print("GATE FAILED:")
        for m in msgs:
            print("  ", m)
        sys.exit(1)
    for p in plan:
        print("dry-run OK: %s/%s  (%s, %d chars)" % (ZONE, ROOM_ID, KW, len(p["text"])))
    if not apply_mode:
        return
    os.makedirs(BACKUP_DIR, exist_ok=True)
    shutil.copy2(UCL_FILE, os.path.join(BACKUP_DIR, os.path.basename(UCL_FILE)))
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        edits.extend(plan_insert(text0, op, cl, build_entry(KW, p["text"])))
    new_text = apply_edits(text0, edits)
    with io.open(UCL_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(new_text)
    print("APPLIED. backup: %s" % BACKUP_DIR)
    plan2 = build_plan()
    print("idempotency re-run pending: %d (expect 0)" % len(plan2))


if __name__ == "__main__":
    main()
