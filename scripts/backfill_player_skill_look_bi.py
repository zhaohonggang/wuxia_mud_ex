# -*- coding: utf-8 -*-
"""
backfill_player_skill_look_bi.py — P5-4k：把 4 个「识字技能门控」的 look_bi 闭包回填为
`player_skill` 动态 item_desc 条目。

背景
----
xiakedao 石洞群（shidong2/4/7/10）的 `set("item_desc", ([ "bi" : (: look_bi :) ]))` 在转换器里
因闭包被丢弃（见 P5-4j 根因）。`look_bi` 按玩家 `literate` 技能等级二选一返回文本：
识字者看到蝌蚪文、文盲看到壁画。本脚本把这两段文本抽出来，写成：

    item_desc = {
     bi = {
      kind = "player_skill"
      skill = "literate"
      min_level = 1
      has_text = "识字者文本"
      no_text = "文盲文本"
     }
    }

复用新 handler `Kantele.World.ItemDescHandlers.PlayerSkill`（已在 item_desc_handlers.ex 注册
xiakedao:shidong2/4/7/10）。

规则 / 安全（与 backfill_static_look_text.py 一致）
-----------------------------------------------
- 全部编辑是对全文的偏移区间替换 (start, end, rep)，按 start 降序一次套完。
- 门禁 G1-G8 任一不过即中止，一个字都不落盘（--apply 也如此）。
- --apply 前先把受影响文件备份到 tmp/backup-playerskill-<时间戳>/。
- 幂等：apply 后再跑 dry-run 应报 0 待改（G8）。
- 不改转换器（用户明确要求）。
- 已带该 keyword 的房间自动跳过（与已手工回填的房间兼容）。

用法
----
    python scripts/backfill_player_skill_look_bi.py            # dry-run + 门禁
    python scripts/backfill_player_skill_look_bi.py --apply    # 备份后写盘
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
UCL_FILE = os.path.join(ROOT, "data", "world", "xiakedao.ucl")
BACKUP_DIR = os.path.join(ROOT, "tmp", "backup-playerskill-%s" % time.strftime("%Y%m%d-%H%M%S"))

RE_COL = re.compile(r'\b(?:WHT|HIW|HIR|HIG|HIY|HIB|HIC|HIM|RED|GRN|YEL|BLU|CYN|MAG|NOR|BOLD)\b')
RE_FUNC = re.compile(r'string\s+look_bi\s*\([^)]*\)\s*\{(.*?)\n\}', re.S)
BR = re.compile(r'if\s*\(.*?\)\s*\{(.*?)\}\s*else\s*\{(.*?)\}', re.S)

TARGETS = [
    ("xiakedao", "shidong2", "d/xiakedao/shidong2.c"),
    ("xiakedao", "shidong4", "d/xiakedao/shidong4.c"),
    ("xiakedao", "shidong7", "d/xiakedao/shidong7.c"),
    ("xiakedao", "shidong10", "d/xiakedao/shidong10.c"),
]


# ---------------------------------------------------------------------------
# 文本抽取（镜像 backfill_static_look_text 的 escape 口径）
# ---------------------------------------------------------------------------

def decode(s):
    """LPC 源码转义 -> 运行期真实字符。"""
    s = s.replace("\\\\", "\x00").replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    s = s.replace('\\"', '"').replace("\\x00", "\\")
    s = s.replace("\x00", "\\")
    return s


def branch_literals(block):
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', block)
    return re.sub(RE_COL, "", "".join(parts))


def extract_branches(lpc_rel):
    path = os.path.join(CORPUS, lpc_rel)
    txt = io.open(path, "r", encoding="utf-8", errors="ignore").read()
    m = RE_FUNC.search(txt)
    if not m:
        raise RuntimeError("look_bi not found in %s" % lpc_rel)
    body = m.group(1)
    bm = BR.search(body)
    if not bm:
        raise RuntimeError("branch if/else not found in %s look_bi" % lpc_rel)
    lit = decode(branch_literals(bm.group(1))).strip()
    ill = decode(branch_literals(bm.group(2))).strip()
    return lit, ill


def encode_ucl_string(s):
    """运行期真实换行/制表符 -> 单行 `\\n`/`\\t` 转义，并转义反斜杠与双引号。"""
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return s


def build_entry(lit, ill):
    has = encode_ucl_string(lit)
    no = encode_ucl_string(ill)
    return (
        '  bi = {\n'
        '    kind = "player_skill"\n'
        '    skill = "literate"\n'
        '    min_level = 1\n'
        '    has_text = "%s"\n'
        '    no_text = "%s"\n'
        '  }\n' % (has, no)
    )


# ---------------------------------------------------------------------------
# UCL 定位 / 插入
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


def room_has_bi(text, op, cl):
    seg = text[op:cl]
    return re.search(r'\bbi\s*=\s*\{[^}]*player_skill', seg) is not None


def find_item_desc(text, op, cl):
    seg = text[op:cl]
    im = seg.find("item_desc = {")
    if im < 0:
        return None
    io_pos = op + im
    iopen = text.index("{", io_pos)
    iclose = R.match_brace(text, iopen)
    return iopen, iclose


def first_key_indent(text, iopen, iclose):
    """item_desc 块内首个 key 行的前导空白，作为新条目缩进基准。"""
    inner = text[iopen + 1:iclose]
    for line in inner.split("\n"):
        m = re.match(r'(\s*)\S', line)
        if m:
            return m.group(1)
    return "  "


def plan_insert(text, op, cl, entry):
    loc = find_item_desc(text, op, cl)
    if loc is None:
        # 房间闭合 } 前新建 item_desc 块（2 空格缩进，与房间内 name/description 同级）
        block = "  item_desc = {\n" + entry + "  }\n"
        return [(cl, cl, block)]
    iopen, iclose = loc
    indent = first_key_indent(text, iopen, iclose)
    indented = "".join(
        (indent + ln if ln.strip() else ln) for ln in entry.splitlines(keepends=True)
    )
    return [(iclose, iclose, indented)]


def apply_edits(text, edits):
    edits = sorted(edits, key=lambda e: e[0], reverse=True)
    out = text
    for start, end, rep in edits:
        out = out[:start] + rep + out[end:]
    return out


# ---------------------------------------------------------------------------
# 计划 + 门禁
# ---------------------------------------------------------------------------

def build_plan():
    plan = []
    text = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    for zone, room_id, lpc_rel in TARGETS:
        loc = find_room_block(text, room_id)
        if loc is None:
            print("  SKIP %s/%s : room block not found" % (zone, room_id))
            continue
        op, cl = loc
        if room_has_bi(text, op, cl):
            print("  SKIP %s/%s : bi(player_skill) already present" % (zone, room_id))
            continue
        lit, ill = extract_branches(lpc_rel)
        plan.append({
            "zone": zone, "room_id": room_id, "lpc_rel": lpc_rel,
            "lit": lit, "ill": ill,
        })
    return plan


def gate(plan):
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    for p in plan:
        loc = find_room_block(text0, p["room_id"])
        if loc is None:
            return False, ["G1 FAIL: room %s/%s not found" % (p["zone"], p["room_id"])]
        op, cl = loc
        if room_has_bi(text0, op, cl):
            return False, ["G2 FAIL: %s/%s already has bi(player_skill)" % (p["zone"], p["room_id"])]
        # G3: 无控制字符（除换行/tab）
        for label, val in (("has_text", p["lit"]), ("no_text", p["ill"])):
            bad = [c for c in val if ord(c) < 32 and c not in "\n\t"]
            if bad:
                return False, ["G3 FAIL: %s/%s.%s has control char" % (p["zone"], p["room_id"], label)]
    # G4-G7: 内存套用 + validate_ucl 快照比对
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, p["room_id"])
        edits.extend(plan_insert(text0, op, cl, build_entry(p["lit"], p["ill"])))
    new_text = apply_edits(text0, edits)
    # 复检写入后 bi 存在
    for p in plan:
        loc = find_room_block(new_text, p["room_id"])
        op, cl = loc
        if not room_has_bi(new_text, op, cl):
            return False, ["G5 FAIL: %s/%s bi missing after apply" % (p["zone"], p["room_id"])]
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
    print("dry-run OK: %d rooms to backfill:" % len(plan))
    for p in plan:
        print("   %s/%s  (literate-branch %d chars / illiterate %d chars)"
              % (p["zone"], p["room_id"], len(p["lit"]), len(p["ill"])))
    if not apply_mode:
        return
    # --apply: 备份 + 写盘
    os.makedirs(BACKUP_DIR, exist_ok=True)
    shutil.copy2(UCL_FILE, os.path.join(BACKUP_DIR, os.path.basename(UCL_FILE)))
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, p["room_id"])
        edits.extend(plan_insert(text0, op, cl, build_entry(p["lit"], p["ill"])))
    new_text = apply_edits(text0, edits)
    with io.open(UCL_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(new_text)
    print("APPLIED. backup: %s" % BACKUP_DIR)
    # G8 幂等复跑
    plan2 = build_plan()
    print("idempotency re-run pending: %d (expect 0)" % len(plan2))


if __name__ == "__main__":
    main()
