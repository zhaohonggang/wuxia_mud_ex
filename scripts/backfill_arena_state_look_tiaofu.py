# -*- coding: utf-8 -*-
"""
backfill_arena_state_look_tiaofu.py — P5-4n：把 city:leitai 的 `look_tiaofu` 闭包回填为
`arena_state` 动态 item_desc 条目。

背景
----
`d/city/leitai.c` 的 `set("item_desc", ([ "tiaofu" : (: look_tiaofu :) ]))` 在转换器里因闭包被
丢弃（见 P5-4 根因）。`look_tiaofu()` 按房间 `close_by` 对象选择两段文本：

    object ob = query("close_by");
    if (! objectp(ob))
        return "本擂台现在自由开放……（开放说明）";
    return "本擂台现在被" + ob->name(1) + "暂时关闭……（关闭说明）";

Elixir 侧 `Kantele.World.Arena.close_by(room_id)` 返回 `nil`（开放）或 `%{by: 关闭者名}`
（关闭）。新建 handler `Kantele.World.ItemDescHandlers.ArenaState`（已在 item_desc_handlers.ex
注册 city:leitai）读该状态：开放→open_text；关闭→closed_text（其中 `{name}` 占位符被 `by` 替换）。

规则 / 安全（与 P5-4l/m 一致）
-------------------------------
- 偏移区间替换 (start, end, rep)，门禁 G1-G8 不过即中止。
- --apply 前备份到 tmp/backup-arenastate-<时间戳>/；幂等复跑应 0 待改。
- 不改转换器；已带该 keyword 的房间自动跳过。
- 写盘用 newline="" 保留 LF（避免 Windows 文本模式把 \\n 翻成 \\r\\n 被 validate_ucl 拒）。

用法
----
    python scripts/backfill_arena_state_look_tiaofu.py            # dry-run + 门禁
    python scripts/backfill_arena_state_look_tiaofu.py --apply    # 备份后写盘
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
UCL_FILE = os.path.join(ROOT, "data", "world", "city.ucl")
BACKUP_DIR = os.path.join(ROOT, "tmp", "backup-arenastate-%s" % time.strftime("%Y%m%d-%H%M%S"))

RE_FUNC = re.compile(r'string\s+look_tiaofu\s*\([^)]*\)\s*\{(.*?)\n\}', re.S)
RE_RET = re.compile(r'return\s+(.*?);', re.S)
LPC_REL = "d/city/leitai.c"
ZONE = "city"
ROOM_ID = "leitai"
KW = "tiaofu"

BAD_CHARS = set(c for c in map(chr, range(0, 32)) if c not in "\n\t\r")


def decode(s):
    s = s.replace("\\\\", "\x00").replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
    s = s.replace('\\"', '"').replace("\x00", "\\")
    return s


def parse_return(expr):
    """把 `return ".." + ob->name(1) + ".."` 解析为 (str_parts, has_name)。"""
    tokens = []
    i, n = 0, len(expr)
    while i < n:
        c = expr[i]
        if c == '"':
            j = i + 1
            buf = []
            while j < n:
                if expr[j] == '\\':
                    buf.append(expr[j])
                    buf.append(expr[j + 1])
                    j += 2
                    continue
                if expr[j] == '"':
                    break
                buf.append(expr[j])
                j += 1
            tokens.append(("str", "".join(buf)))
            i = j + 1
        elif expr[i:i + 9] == 'ob->name(':
            tokens.append(("name", None))
            k = expr.index(')', i)
            i = k + 1
        else:
            i += 1
    return tokens


def extract_texts(lpc_rel):
    path = os.path.join(CORPUS, lpc_rel)
    txt = io.open(path, "r", encoding="utf-8", errors="ignore").read()
    m = RE_FUNC.search(txt)
    if not m:
        raise RuntimeError("look_tiaofu not found in %s" % lpc_rel)
    body = m.group(1)
    returns = RE_RET.findall(body)
    if len(returns) < 2:
        raise RuntimeError("look_tiaofu has %d return(s), expected 2" % len(returns))

    # 第一段：开放文本（无 ob->name 占位符）。
    open_tokens = parse_return(returns[0])
    open_text = "".join(t for kind, t in open_tokens if kind == "str")

    # 第二段：关闭文本，把 name 占位符插到 ob->name(1) 的位置。
    closed_tokens = parse_return(returns[1])
    parts = []
    for kind, t in closed_tokens:
        if kind == "str":
            parts.append(t)
        else:
            parts.append("{name}")
    closed_text = "".join(parts)

    return decode(open_text).strip(), decode(closed_text).strip()


def encode_ucl_string(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return s


def room_base_indent(text, op, cl):
    """同级（sibling）缩进：优先取 `actions` 块的缩进（该房间 body 主风格为 2 空格），
    找不到再回退到 2 空格。注意 leitai 的 name/description 行是 6 空格异常缩进，
    不能用「首个内容行」判定，否则 item_desc 会跟 actions 错位。"""
    seg = text[op:cl]
    m = re.search(r'^(\s*)actions\s*=\s*\{', seg, re.M)
    if m:
        return m.group(1)
    for line in seg.splitlines():
        stripped = line.strip()
        if stripped and stripped != "{" and not stripped.startswith("rooms"):
            return re.match(r"\s*", line).group(0)
    return "  "


def build_entry(open_text, closed_text, base):
    ind = base
    ind2 = base + "  "
    ind4 = base + "    "
    return (
        "%sitem_desc = {\n"
        "%stiaofu = {\n"
        '%skind = "arena_state"\n'
        '%sopen_text = "%s"\n'
        '%sclosed_text = "%s"\n'
        "%s}\n"
        "%s}\n"
        % (
            ind,
            ind2,
            ind4,
            ind4,
            encode_ucl_string(open_text),
            ind4,
            encode_ucl_string(closed_text),
            ind2,
            ind,
        )
    )


# ---------------------------------------------------------------------------
# UCL 定位 / 插入（复用 P5-4l 的偏移编辑逻辑）
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
    return re.search(r'\b' + re.escape(KW) + r'\s*=\s*\{[^}]*?"arena_state"', seg) is not None


def plan_insert(text, op, cl, entry):
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
        print("  SKIP %s/%s : %s(arena_state) already present" % (ZONE, ROOM_ID, KW))
        return plan
    open_text, closed_text = extract_texts(LPC_REL)
    plan.append({"open": open_text, "closed": closed_text})
    return plan


def gate(plan):
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    for p in plan:
        loc = find_room_block(text0, ROOM_ID)
        if loc is None:
            return False, ["G1 FAIL: room %s/%s not found" % (ZONE, ROOM_ID)]
        op, cl = loc
        if room_has_entry(text0, op, cl):
            return False, ["G2 FAIL: %s/%s already has %s(arena_state)" % (ZONE, ROOM_ID, KW)]
        for label, val in (("open_text", p["open"]), ("closed_text", p["closed"])):
            bad = [c for c in val if c in BAD_CHARS]
            if bad:
                return False, ["G3 FAIL: %s/%s.%s has control char" % (ZONE, ROOM_ID, label)]
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        base = room_base_indent(text0, op, cl)
        edits.extend(plan_insert(text0, op, cl, build_entry(p["open"], p["closed"], base)))
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
        print("dry-run OK: %s/%s  (open %d / closed %d chars)"
              % (ZONE, ROOM_ID, len(p["open"]), len(p["closed"])))
    if not apply_mode:
        return
    os.makedirs(BACKUP_DIR, exist_ok=True)
    shutil.copy2(UCL_FILE, os.path.join(BACKUP_DIR, os.path.basename(UCL_FILE)))
    text0 = io.open(UCL_FILE, "r", encoding="utf-8", newline="").read()
    edits = []
    for p in plan:
        op, cl = find_room_block(text0, ROOM_ID)
        base = room_base_indent(text0, op, cl)
        edits.extend(plan_insert(text0, op, cl, build_entry(p["open"], p["closed"], base)))
    new_text = apply_edits(text0, edits)
    with io.open(UCL_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(new_text)
    print("APPLIED. backup: %s" % BACKUP_DIR)
    plan2 = build_plan()
    print("idempotency re-run pending: %d (expect 0)" % len(plan2))


if __name__ == "__main__":
    main()
