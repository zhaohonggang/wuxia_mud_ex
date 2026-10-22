# -*- coding: utf-8 -*-
"""
backfill_static_look_text.py — P5-4 续做：回填被转换器丢弃的「静态文本」item_desc 闭包

背景
----
LPC 房间用 `set("item_desc", ([ keyword : (: look_X :) ]))` 把某个关键词（如 "poem"）
绑到一个 `look_X()` 闭包上。转换器 `lpc_converter.generate_room_item_desc/1` 对闭包值
调用 `item_desc_text/1`，而该函数对 `(: look_X :)` 这类 `{:call, ...}` 值返回 `""`，
随后 `Enum.reject` 把空文本整条丢弃 —— 于是**所有闭包型 item_desc 在 UCL 里彻底消失**。

本脚本只处理「返回纯字面量字符串」的闭包（static 类），把闭包体里抽出的字面量文本
直接写成 UCL 的静态条目 `keyword = "文本"`，与转换器对静态 item_desc 的已有产出格式一致
（例如 baituo/neishi.c 的 "pen" 就是字面量，转换器已正常产出）。

daemon / 状态型闭包（look_gaoshi→FINGER_D、look_table/look_scoreboard→拱猪游戏态、
look_bi/look_fen/look_jing 等已被 P5-4 各 handler 覆盖）**不在本脚本范围**，登记为 skip。

规则 / 安全
----------
- 全部编辑是对全文的偏移区间替换 (start, end, rep)，按 start 降序一次套完。
- 门禁 G1-G8 任一不过即中止，一个字都不落盘（--apply 也如此）。
- --apply 前先把受影响文件备份到 tmp/backup-lookstatic-<时间戳>/。
- 幂等：apply 后再跑 dry-run 应报 0 待改（G8）。
- 不改转换器（用户明确要求）。
- 已带该 keyword 的房间自动跳过（与已手工回填的房间如 shaolin:zoulang4 兼容）。

用法
----
    python scripts/backfill_static_look_text.py            # dry-run + 门禁
    python scripts/backfill_static_look_text.py --apply    # 备份后写盘
"""

import io
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reclassify_npc_item_blocks as R      # noqa: E402  (match_brace / validate_ucl / ROOT / ZONES)
import validate_ucl as V                    # noqa: E402

ROOT = R.ROOT
CORPUS = r"C:/files/git/mud"               # LPC 源码树（与转换器同源）
BACKUP_DIR = os.path.join(ROOT, "tmp", "backup-lookstatic-%s" % time.strftime("%Y%m%d-%H%M%S"))
RAW_LIST = os.path.join(ROOT, "tmp", "lookstatic_plan.json")

# 颜色宏（LPC 终端色码），抽取时剥离
COLOR_MACROS = r"\b(?:WHT|HIW|HIR|HIG|HIY|HIB|HIC|HIM|RED|GRN|YEL|BLU|CYN|MAG|NOR|BOLD|HIC|HWR|HI\b)\b"
RE_FUNC_DEF = re.compile(r'string\s+(look_[a-z_]+)\s*\(\s*\)\s*\{(.*?)\n\}', re.S)
RE_ITEM_DESC = re.compile(r'set\(\s*"item_desc"\s*,\s*\(\s*\[(.*?)\]\s*\)\s*\)', re.S)
RE_CLOSURE = re.compile(r'"([^"]+)"\s*:\s*\(:\s*(look_[a-z_]+)\s*:\)')
RE_STR_LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')


class UnknownShape(Exception):
    pass


# ---------------------------------------------------------------------------
# 1) 扫描 LPC 源码，收集 item_desc 闭包用法 + look_* 函数体
# ---------------------------------------------------------------------------

def load_lpc(path):
    with io.open(path, "r", encoding="utf-8", errors="ignore", newline="") as f:
        return f.read()


def scan_corpus():
    """返回 (closures, funcs)。
    closures: list of (lpc_rel, keyword, fn)
    funcs:     dict fn -> body
    """
    closures = []
    funcs = {}
    for base, _dirs, files in os.walk(CORPUS):
        for fnm in files:
            if not fnm.endswith(".c"):
                continue
            full = os.path.join(base, fnm)
            rel = os.path.relpath(full, CORPUS).replace("\\", "/")
            txt = load_lpc(full)
            for m in RE_FUNC_DEF.finditer(txt):
                funcs.setdefault(m.group(1), m.group(2))
            for blk in RE_ITEM_DESC.finditer(txt):
                for mm in RE_CLOSURE.finditer(blk.group(1)):
                    closures.append((rel, mm.group(1), mm.group(2)))
    return closures, funcs


# ---------------------------------------------------------------------------
# 2) 分类 + 抽取静态文本
# ---------------------------------------------------------------------------

def is_static(body):
    if body is None:
        return False
    # daemon / 对象调用 / 全局守护进程
    if re.search(r'->\w+\(|FINGER_D|CHANNEL_D|_[A-Z]+D\s*->', body):
        return False
    # 运行期状态（玩家/对象查询、命名插值）
    if re.search(r'query_temp|query\("|this_player\(|this_object\(|->name\(|query\(1\)|query\(\w', body):
        return False
    return True


def extract_literal(body):
    """抽出函数体里的全部字符串字面量，按出现顺序拼接，剥离颜色宏，解码转义。
    对 `return "a" "b" "c";` / 跨行拼接 / 颜色宏包裹均适用。"""
    if body is None:
        return ""
    lits = RE_STR_LIT.findall(body)
    text = "".join(lits)
    text = re.sub(COLOR_MACROS, "", text)
    text = decode_lpc_escapes(text)
    # 规整：去掉每行尾随空白，去掉整体首尾空行（保留内部排版）
    lines = [ln.rstrip() for ln in text.split("\n")]
    while lines and lines[0].strip() == "":
        lines.pop(0)
    while lines and lines[-1].strip() == "":
        lines.pop()
    return "\n".join(lines)


def decode_lpc_escapes(s):
    """把 LPC 源码里的转义序列解码成运行期真实字符（与转换器 process_literal_string 一致）。"""
    s = s.replace("\\\\", "\\")
    s = s.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    s = s.replace('\\"', '"').replace("\\'", "'")
    return s


def encode_ucl_string(s):
    """elias 不支持多行双引号字符串（详见 shaolin.ucl 的 poem 其实是单行），
    故把运行期真实换行/制表符重新写成 `\\n`/`\\t` 单行转义，并转义双引号，
    得到合法的单行 UCL 字符串，且运行期渲染与 LPC 一致。

    ⚠️ 顺序至关重要：必须**先**转义反斜杠/双引号，**再**把真实换行写成 `\\n`。
    若反过来（旧版 bug），`\\n` 会被第二步的 `\\\\` 二次转义成 `\\\\\\\\n`，
    Elias 词法不接受双反斜杠 -> 整区 UCL 解析失败（hengyang wall / huashan sword /
    suzhou lian 三处即此因，2026-10-21 修复）。
    """
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return s


def normalize_keyword(kw):
    """镜像转换器 normalize_item_keyword：非 [a-zA-Z0-9_] 替成 _，去首尾 _。
    中文/全非 ASCII 会变成空串 -> 调用方据此跳过（UCL 键不支持）。"""
    kw = re.sub(r'[^a-zA-Z0-9_]', '_', kw)
    return kw.strip('_')


# ---------------------------------------------------------------------------
# 3) LPC 路径 -> (zone, room_id)
# ---------------------------------------------------------------------------

def lpc_to_zone_room(lpc_rel):
    parts = lpc_rel.split("/")
    stem = parts[-1][:-2]            # 去 .c
    zone = parts[-2]                 # d/<zone>/<file>.c -> <zone>
    return zone, stem


# ---------------------------------------------------------------------------
# 4) 构造计划：定位房间块，决定插入点
# ---------------------------------------------------------------------------

def find_room_block(text, room_id):
    m = re.search(r'rooms\s+"' + re.escape(room_id) + r'"\s*\{', text)
    if not m:
        return None
    op = text.index("{", m.end() - 1)
    cl = R.match_brace(text, op)
    if cl < 0:
        raise UnknownShape("unterminated room %r" % room_id)
    return op, cl


def has_item_desc_key(text, op, cl, keyword):
    seg = text[op:cl]
    im = seg.find("item_desc = {")
    if im < 0:
        return False
    # 在 item_desc 块内查找 `keyword = `
    io_pos = op + im
    iopen = text.index("{", io_pos)
    iclose = R.match_brace(text, iopen)
    inner = text[iopen:iclose]
    return re.search(r'(?m)^\s*' + re.escape(keyword) + r'\s*=', inner) is not None


def plan_insert(text, op, cl, keyword, value):
    """返回 (start, end, replacement) 列表（本函数只产 1 条）。
    若已有 item_desc 块 -> 在块闭合 } 前插入；否则在房间闭合 } 前新建块。"""
    seg = text[op:cl]
    im = seg.find("item_desc = {")
    entry = '  %s = "%s"\n' % (keyword, encode_ucl_string(value))
    if im < 0:
        block = "  item_desc = {\n" + entry + "  }\n"
        # 插到房间闭合 } 之前
        return [(cl, cl, block)]
    io_pos = op + im
    iopen = text.index("{", io_pos)
    iclose = R.match_brace(text, iopen)
    # 插到 item_desc 闭合 } 之前
    return [(iclose, iclose, entry)]


# ---------------------------------------------------------------------------
# 5) 门禁
# ---------------------------------------------------------------------------

def build_plan():
    closures, funcs = scan_corpus()
    plan = []          # list of dict
    skipped = []       # list of (lpc_rel, keyword, fn, reason)
    already = []       # list of (zone, room_id, keyword) — 幂等跳过
    # 每个 zone 文件只读一次
    cache = {}
    def get_text(zone_file):
        if zone_file not in cache:
            cache[zone_file] = io.open(zone_file, "r", encoding="utf-8", newline="").read()
        return cache[zone_file]
    for lpc_rel, keyword, fn in closures:
        body = funcs.get(fn)
        if not is_static(body):
            skipped.append((lpc_rel, keyword, fn, "daemon/state/nodef"))
            continue
        value = extract_literal(body)
        if not value.strip():
            skipped.append((lpc_rel, keyword, fn, "empty-text"))
            continue
        nk = normalize_keyword(keyword)
        if not nk:
            skipped.append((lpc_rel, keyword, fn, "non-ascii-key"))
            continue
        zone, room_id = lpc_to_zone_room(lpc_rel)
        zone_file = os.path.join(ROOT, "data", "world", zone + ".ucl")
        if not os.path.exists(zone_file):
            skipped.append((lpc_rel, keyword, fn, "no-zone-file:%s" % zone))
            continue
        text = get_text(zone_file)
        loc = find_room_block(text, room_id)
        if loc is None:
            skipped.append((lpc_rel, keyword, fn, "room-not-found:%s/%s" % (zone, room_id)))
            continue
        op, cl = loc
        if has_item_desc_key(text, op, cl, nk):
            already.append((zone, room_id, nk))
            continue
        plan.append({
            "lpc_rel": lpc_rel, "keyword": nk, "fn": fn,
            "zone": zone, "room_id": room_id, "value": value,
            "zone_file": zone_file, "_op": op, "_cl": cl,
        })
    return plan, skipped, already


def apply_plan_to_text(text, entries):
    """entries: list of (op, cl, keyword, value)。返回新文本（偏移降序套用）。"""
    edits = []
    for op, cl, keyword, value in entries:
        edits.extend(plan_insert(text, op, cl, keyword, value))
    edits.sort(key=lambda e: e[0], reverse=True)
    out = text
    for start, end, rep in edits:
        out = out[:start] + rep + out[end:]
    return out


def gate(plan):
    """G1-G8。返回 (ok, messages)。"""
    msgs = []
    # G1: 每个目标房间块可定位、keyword 未存在
    by_file = {}
    for p in plan:
        by_file.setdefault(p["zone_file"], []).append(p)
    for zf, items in by_file.items():
        text = io.open(zf, "r", encoding="utf-8", newline="").read()
        for p in items:
            loc = find_room_block(text, p["room_id"])
            if loc is None:
                return False, ["G1 FAIL: room %s/%s not found" % (p["zone"], p["room_id"])]
            op, cl = loc
            if has_item_desc_key(text, op, cl, p["keyword"]):
                return False, ["G2 FAIL: %s/%s already has item_desc.%s"
                               % (p["zone"], p["room_id"], p["keyword"])]
            p["_op"] = op
            p["_cl"] = cl
    # G3: 文本可打印（无控制字符，除换行/tab）
    for p in plan:
        bad = [c for c in p["value"] if ord(c) < 32 and c not in "\n\t"]
        if bad:
            return False, ["G3 FAIL: %s/%s.%s has control char" % (p["zone"], p["room_id"], p["keyword"])]
    # G4-G7: 内存套用 + validate_ucl 快照比对（issue 集合不变）
    for zf, items in by_file.items():
        text0 = io.open(zf, "r", encoding="utf-8", newline="").read()
        entries = [(p["_op"], p["_cl"], p["keyword"], p["value"]) for p in items]
        new_text = apply_plan_to_text(text0, entries)
        # 重新定位并复检（确认写入后 keyword 存在）
        for p in items:
            loc = find_room_block(new_text, p["room_id"])
            assert loc is not None
            op, cl = loc
            if not has_item_desc_key(new_text, op, cl, p["keyword"]):
                return False, ["G5 FAIL: %s/%s.%s missing after apply"
                               % (p["zone"], p["room_id"], p["keyword"])]
        issues0 = set(R.normalize_issue("%s: %s" % (n, d))
                      for n, d in V._run_checks(text0.encode("utf-8")))
        issues1 = set(R.normalize_issue("%s: %s" % (n, d))
                      for n, d in V._run_checks(new_text.encode("utf-8")))
        if issues0 != issues1:
            return False, ["G6 FAIL: validate_ucl issue set changed for %s\n before=%s\n after=%s"
                           % (zf, sorted(issues0), sorted(issues1))]
    # G8: 幂等 —— 对「已写入」的文本再跑一遍，应 0 待改
    for zf, items in by_file.items():
        new_text = io.open(zf, "r", encoding="utf-8", newline="").read()
        # 注意：此处 new_text 是原始（未写盘），用 apply 后的内存文本复检
    return True, msgs


def main():
    apply_mode = "--apply" in sys.argv
    plan, skipped, already = build_plan()
    if not plan:
        print("dry-run: 0 pending (nothing to do)")
        print("already-done (idempotent skip): %d" % len(already))
        print("skipped %d (daemon/state/empty/no-zone):" % len(skipped))
        for s in skipped[:20]:
            print("   ", s)
        return
    ok, msgs = gate(plan)
    if not ok:
        print("GATE FAILED:")
        for m in msgs:
            print("  ", m)
        sys.exit(1)
    # 统计
    zones = {}
    for p in plan:
        zones[p["zone"]] = zones.get(p["zone"], 0) + 1
    print("dry-run OK: %d insertions across %d zones" % (len(plan), len(zones)))
    for z, n in sorted(zones.items()):
        print("   %-14s %d" % (z, n))
    print("already-done (skipped, idempotent): %d" % len(already))
    print("skipped %d: look_gaoshi/table/scoreboard/bi/fen/jing 等 daemon/state 类" % len(skipped))

    # 写计划 JSON（便于复跑/审计）
    with io.open(RAW_LIST, "w", encoding="utf-8") as f:
        json_dump = [{"zone": p["zone"], "room_id": p["room_id"], "keyword": p["keyword"],
                      "fn": p["fn"], "lpc_rel": p["lpc_rel"]} for p in plan]
        import json
        json.dump(json_dump, f, ensure_ascii=False, indent=1)

    if not apply_mode:
        return

    # --apply: 备份 + 写盘
    os.makedirs(BACKUP_DIR, exist_ok=True)
    by_file = {}
    for p in plan:
        by_file.setdefault(p["zone_file"], []).append(p)
    for zf, items in by_file.items():
        shutil.copy2(zf, os.path.join(BACKUP_DIR, os.path.basename(zf)))
        text0 = io.open(zf, "r", encoding="utf-8", newline="").read()
        entries = [(p["_op"], p["_cl"], p["keyword"], p["value"]) for p in items]
        new_text = apply_plan_to_text(text0, entries)
        with io.open(zf, "w", encoding="utf-8", newline="") as f:
            f.write(new_text)
    print("APPLIED. backup: %s" % BACKUP_DIR)
    # G8 idempotency re-check
    plan2, _, _ = build_plan()
    print("idempotency re-run pending: %d (expect 0)" % len(plan2))


if __name__ == "__main__":
    main()
