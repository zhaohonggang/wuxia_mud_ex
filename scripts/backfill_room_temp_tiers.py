# -*- coding: utf-8 -*-
"""
backfill_room_temp_tiers.py — P5-4l：把 hengyang:outzigai1 的 `look_bi` 闭包回填为
`room_temp_tiers` 动态 item_desc 条目。

背景
----
outzigai1 的 `set("item_desc", ([ "bi" : (: look_bi :) ]))` 在转换器里因闭包被丢弃
（见 P5-4j 根因）。`look_bi` 按房间 temp 三个互斥标记位选择文本：
  - `marks/破` 已置  -> "石壁已经被打破了。"
  - `marks/推` 已置  -> "石门已经被推开了，却露出一个山洞来。"
  - 都不置          -> 默认描述（石壁有裂缝、透光，似乎有出路）
复用新 handler `Kantele.World.ItemDescHandlers.RoomTempTiers`（已在 item_desc_handlers.ex 注册
hengyang:outzigai1）。

规则 / 安全（与 backfill_player_skill_look_bi.py 一致）
----------------------------------------------------
- 偏移区间替换 (start, end, rep)，按 start 降序套用；门禁 G1-G8 不过即中止。
- --apply 前备份到 tmp/backup-roomtemptiers-<时间戳>/；幂等复跑应 0 待改。
- 不改转换器；已带该 keyword 的房间自动跳过。

用法
----
    python scripts/backfill_room_temp_tiers.py            # dry-run + 门禁
    python scripts/backfill_room_temp_tiers.py --apply    # 备份后写盘
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
CORPUS = r"C:/files/git/mud"
UCL_FILE = os.path.join(ROOT, "data", "world", "hengyang.ucl")
BACKUP_DIR = os.path.join(ROOT, "tmp", "backup-roomtemptiers-%s" % time.strftime("%Y%m%d-%H%M%S"))

RE_COL = re.compile(r'\b(?:WHT|HIW|HIR|HIG|HIY|HIB|HIC|HIM|RED|GRN|YEL|BLU|CYN|MAG|NOR|BOLD)\b')
RE_FUNC = re.compile(r'string\s+look_bi\s*\([^)]*\)\s*\{(.*?)\n\}', re.S)
LPC_REL = "d/hengyang/outzigai1.c"
ZONE = "hengyang"
ROOM_ID = "outzigai1"
KW = "bi"


def decode(s):
    s = s.replace("\\\\", "\x00").replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    s = s.replace('\\"', '"').replace("\x00", "\\")
    return s


def lits(block):
    return re.sub(RE_COL, "", "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', block)))


def extract_texts(lpc_rel):
    path = os.path.join(CORPUS, lpc_rel)
    txt = io.open(path, "r", encoding="utf-8", errors="ignore").read()
    m = RE_FUNC.search(txt)
    if not m:
        raise RuntimeError("look_bi not found in %s" % lpc_rel)
    body = m.group(1)
    po = decode(lits(re.search(r'query_temp\("marks/破"\)\)\s*return\s*(.*?);', body, re.S).group(1))).strip()
    pt = decode(lits(re.search(r'query_temp\("marks/推"\)\)\s*return\s*(.*?);', body, re.S).group(1))).strip()
    df = decode(lits(re.search(r'msg\s*=\s*(.*?);', body, re.S).group(1))).strip()
    return po, pt, df


def encode_ucl_string(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return s


def build_entry(po, pt, df):
    return (
        '  item_desc = {\n'
        '    %s = {\n'
        '      kind = "room_temp_tiers"\n'
        '      tiers = [\n'
        '        { key = "marks/破" text = "%s" },\n'
        '        { key = "marks/推" text = "%s" },\n'
        '      ]\n'
        '      default = "%s"\n'
        '    }\n'
        '  }\n' % (KW, encode_ucl_string(po), encode_ucl_string(pt), encode_ucl_string(df))
    )


# ---------------------------------------------------------------------------
# UCL 定位 / 插入（复用 P5-4k 的偏移编辑逻辑）
# ---------------------------------------------------------------------------

def find_room_block(text, room_id):
    m = re.search(r'rooms\s+"' + re.escape(room_id) + r'"\s*\{', text)
    if not m:
        return None
    op = text.index("{", m.end() - 1)
    cl = R.match_brace(text, op)
    if cl < 0:
        raise RuntimeError("unterminated room %r" % room_id)
    return op, cl


def room_has_entry(text, op, cl):
    seg = text[op:cl]
    return re.search(r'\b' + re.escape(KW) + r'\s*=\s*\{[^}]*room_temp_tiers', seg) is not None


def plan_insert(text, op, cl, entry):
    # outzigai1 当前无 item_desc 块 —— 在房间闭合 } 前新建。
    return [(cl, cl, entry)]


def apply_edits(text, edits):
    edits = sorted(edits, key=lambda e: e[0], reverse=True)
    out = text
    for start, end, rep in edits:
        out = out[:start] + rep + out[end:]
    return out


def build_plan():
    plan = []
    text = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    loc = find_room_block(text, ROOM_ID)
    if loc is None:
        print("  SKIP %s/%s : room block not found" % (ZONE, ROOM_ID))
        return plan
    op, cl = loc
    if room_has_entry(text, op, cl):
        print("  SKIP %s/%s : %s(room_temp_tiers) already present" % (ZONE, ROOM_ID, KW))
        return plan
    po, pt, df = extract_texts(LPC_REL)
    plan.append({"po": po, "pt": pt, "df": df})
    return plan


def gate(plan):
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    for p in plan:
        loc = find_room_block(text0, ROOM_ID)
        if loc is None:
            return False, ["G1 FAIL: room %s/%s not found" % (ZONE, ROOM_ID)]
        op, cl = loc
        if room_has_entry(text0, op, cl):
            return False, ["G2 FAIL: %s/%s already has %s(room_temp_tiers)" % (ZONE, ROOM_ID, KW)]
        for label, val in (("marks/破", p["po"]), ("marks/推", p["pt"]), ("default", p["df"])):
            bad = [c for c in val if ord(c) < 32 and c not in "\n\t"]
            if bad:
                return False, ["G3 FAIL: %s/%s.%s has control char" % (ZONE, ROOM_ID, label)]
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        edits.extend(plan_insert(text0, op, cl, build_entry(p["po"], p["pt"], p["df"])))
    new_text = apply_edits(text0, edits)
    loc = find_room_block(new_text, ROOM_ID)
    op, cl = loc
    if not room_has_entry(new_text, op, cl):
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
        print("dry-run OK: %s/%s  (破 %d / 推 %d / 默认 %d chars)"
              % (ZONE, ROOM_ID, len(p["po"]), len(p["pt"]), len(p["df"])))
    if not apply_mode:
        return
    os.makedirs(BACKUP_DIR, exist_ok=True)
    shutil.copy2(UCL_FILE, os.path.join(BACKUP_DIR, os.path.basename(UCL_FILE)))
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        edits.extend(plan_insert(text0, op, cl, build_entry(p["po"], p["pt"], p["df"])))
    new_text = apply_edits(text0, edits)
    with io.open(UCL_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(new_text)
    print("APPLIED. backup: %s" % BACKUP_DIR)
    plan2 = build_plan()
    print("idempotency re-run pending: %d (expect 0)" % len(plan2))


if __name__ == "__main__":
    main()
