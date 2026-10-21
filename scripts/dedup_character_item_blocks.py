# -*- coding: utf-8 -*-
"""
dedup_character_item_blocks.py — R7a

删掉「同区已有同名 items 块」的 197 个重复 `characters` 块，并把 characters 侧独有的键
合并进 items 块。

背景
----
同一份 LPC 源被两代转换器各转一次后拼进同一个区文件：
  `# Generated from ... by LPCConverter` 走 npc/ 分支输出 `characters "x"`
  `# Source: ...`                     输出 `items "x"`
两块本是不同命名空间（loader 分开解析），相安无事。R7 已把没有同名 items 块的 374 个
`characters` 块改名成 items；剩下这 197 个因为「一改名就成了同类同名两块」而被 G10 拦下。

处置（用户拍板：选项①）
  1. 删除 `characters "<id>" { ... }` 整块，连同它上方只管辖它的
     `# Generated from ... by LPCConverter` + `# Zone: ...` 头和紧随的空行。
  2. 把 characters 侧独有、且 items 块**能表达**的键原样合并进 items 块：
       aliases（181 组）——`parse_item` 读它，这是本次的主要收益
       init（5 组）——items 块读不到它（惰性），但全区已有 7 个 items 块带着 init，
                     原样搬过去可保数据不丢
     其余键（name/description）经逐组比对：items 侧完整（characters 侧有 6 个
     `"NPC"` 占位名、38 个空描述、若干截断/去空白变体），一律以 items 侧为准。
  3. 引用搬迁：全树只有 1 处 `characters.<id>.id`（dali `room_characters "chufang"`
     里的 puercha），改成 `items.<id>.id` 并从 room_characters 搬到 room_items。

与 R7 的关系
------------
本脚本复用 `reclassify_npc_item_blocks` 的全部底层件（括号配对、顶层逗号切分、
块扫描、数组解析、偏移编辑、内存 validate_ucl），但**计划完全独立**，不改转换器。

安全
----
  - 所有编辑都是对全文的偏移区间替换，按 start 降序一次套完，行号永不失效。
  - 门禁 G1-G10 任一不过就中止，一个字都不落盘（--apply 也如此）。
  - --apply 前先把受影响文件备份到 tmp/backup-dedup-<时间戳>/。
  - 幂等：apply 后再跑一次 dry-run 应报 0 目标（G10）。
"""

import collections
import io
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reclassify_npc_item_blocks as R      # noqa: E402
import survey_character_blocks as S         # noqa: E402
import validate_ucl as V                    # noqa: E402

ROOT = R.ROOT
ZONES = R.ZONES

# 只合并这两个键：aliases 是目标收益；init 是「惰性但可无损保留」的历史数据。
MERGE_KEYS = ("aliases", "init")

RE_HDR = re.compile(r'^[ \t]*# (?:Generated from|Source:)', re.M)
RE_KEY_LINE = re.compile(r'^([ \t]*)([A-Za-z_][A-Za-z0-9_]*)[ \t]*=', re.M)


class UnknownShape(R.UnknownShape):
    pass


# ---------------------------------------------------------------------------
# 定位
# ---------------------------------------------------------------------------

def block_span(text, open_idx):
    """open_idx 指向 '{'，返回配对 '}' 的下标；-1 表示没配上。"""
    return R.match_brace(text, open_idx)


def find_pairs(texts, survey):
    """返回 [(zone, id)]：同区里 characters 与 items 同名块并存，且勘察判为物品。"""
    want = collections.defaultdict(set)
    for rec in survey["records"]:
        if rec["classification"] == "item":
            want[os.path.basename(rec["file"])].add(rec["id"])

    pairs = []
    for zone in ZONES:
        text = texts[zone]
        name = os.path.basename(zone)
        chars = set(m.group(2) for m in R.RE_CHAR_HEADER.finditer(text))
        items = set(m.group(2) for m in R.RE_ITEMS_HEADER.finditer(text))
        for bid in sorted(want.get(name, ())):
            if bid in chars and bid in items:
                pairs.append((zone, bid))
    return pairs


def locate(text, header_rx, block_id):
    """返回该 id 在 text 里唯一的块头 match；0 个或多于 1 个都抛。"""
    hits = [m for m in header_rx.finditer(text) if m.group(2) == block_id]
    if not hits:
        raise UnknownShape("no header for %r" % block_id)
    if len(hits) > 1:
        raise UnknownShape("%d headers for %r (expect 1)" % (len(hits), block_id))
    return hits[0]


def header_line_start(text, block_start):
    """块头上方紧邻的 `# Generated from ...` 注释行的起始偏移。

    只接受「块头正上方（中间只有空行）就是 Generated/Source 头」的形态，
    并要求那个头到下一个头之间只管辖 1 个块（否则删头会把别人的出处也删掉）。
    """
    heads = sorted(m.start() for m in RE_HDR.finditer(text))
    hidx = max([h for h in heads if h < block_start], default=-1)
    if hidx < 0:
        raise UnknownShape("no source header above offset %d" % block_start)

    nxt = min([h for h in heads if h > hidx], default=len(text))
    region = text[hidx:nxt]
    n_blocks = len(re.findall(r'^[ \t]*(?:items|characters|rooms|npc)[ \t]+"',
                              region, re.M))
    if n_blocks != 1:
        raise UnknownShape("header at %d governs %d blocks (expect 1)"
                           % (hidx, n_blocks))
    return hidx


def top_keys(body):
    """块体的顶层键名（块体以 '{' 之后的那一行剩余内容开头）。"""
    out = []
    depth = 0
    for line in body.split("\n")[1:]:
        m = RE_KEY_LINE.match(line)
        if m and depth == 0:
            out.append(m.group(2))
        depth += line.count("{") - line.count("}")
    return out


def key_value_span(body, key):
    """顶层 `key = <值>` 所占文本的 [start, end)；值可跨行（对象/数组）。

    引号感知：用 reclassify 的 _match_pair 配括号，避免把字符串里的 `{` 当层级。
    """
    depth = 0
    # 块体以 '{' 之后那一行的剩余内容开头，先跳过它，pos 才是首行的真实偏移
    pos = len(body.split("\n")[0]) + 1
    for line in body.split("\n")[1:]:
        m = RE_KEY_LINE.match(line)
        if m and depth == 0 and m.group(2) == key:
            rest = body[pos:]
            eq = rest.index("=")
            j = eq + 1
            while j < len(rest) and rest[j] in " \t":
                j += 1
            if j < len(rest) and rest[j] in "{[":
                close = R._match_pair(rest, j, rest[j],
                                      "}" if rest[j] == "{" else "]")
                if close < 0:
                    raise UnknownShape("unterminated %r value" % key)
                end = close + 1
            else:
                nl = rest.find("\n")
                end = len(rest) if nl < 0 else nl
            return (pos, pos + end)
        depth += line.count("{") - line.count("}")
        pos += len(line) + 1
    raise UnknownShape("no top-level key %r in body" % key)


# ---------------------------------------------------------------------------
# 计划
# ---------------------------------------------------------------------------

def build_plan(texts, survey):
    pairs = find_pairs(texts, survey)

    deletes = []        # (zone, id, start, end)
    merges = []         # (zone, id, [(key, 行文本), ...])
    ref_moves = []      # (zone, id, room)
    notes = collections.Counter()

    for zone, bid in pairs:
        text = texts[zone]
        cm = locate(text, R.RE_CHAR_HEADER, bid)
        im = locate(text, R.RE_ITEMS_HEADER, bid)

        c_open = text.index("{", cm.start())
        c_close = block_span(text, c_open)
        if c_close < 0:
            raise UnknownShape("%s: unterminated characters %r" % (zone, bid))

        hstart = header_line_start(text, cm.start())

        # --- 删除区间：注释头 -> 块尾（含换行），并吃掉紧随的一个空行 ---
        nl = text.find("\n", c_close + 1)
        b = len(text) if nl < 0 else nl + 1
        a = hstart
        if a > 0 and text[a - 1] == "\n" and b < len(text) and text[b] == "\n":
            b += 1
        deletes.append((zone, bid, a, b))

        # --- 合并 characters 侧独有的键 ---
        c_body = text[c_open + 1:c_close]
        i_open = text.index("{", im.start())
        i_close = block_span(text, i_open)
        if i_close < 0:
            raise UnknownShape("%s: unterminated items %r" % (zone, bid))
        i_body = text[i_open + 1:i_close]

        c_keys = set(top_keys(c_body))
        i_keys = set(top_keys(i_body))
        merged = []
        for key in MERGE_KEYS:
            if key not in c_keys:
                continue
            if key in i_keys:
                notes["merge skip: %s already in items" % key] += 1
                continue
            s, e = key_value_span(c_body, key)
            merged.append((key, c_body[s:e]))
            notes["merge: %s" % key] += 1
        if merged:
            merges.append((zone, bid, merged))

        # --- 引用搬迁 ---
        for m in re.finditer(r'\bcharacters\.%s\b' % re.escape(bid), text):
            if a <= m.start() < b:            # 落在被删区间里的不算
                continue
            blk = _owning_room_block(text, m.start())
            if blk is None:
                raise UnknownShape("%s: %r referenced outside any room block"
                                   % (zone, bid))
            ref_moves.append((zone, bid, blk.room))

    return {"pairs": pairs, "deletes": deletes, "merges": merges,
            "ref_moves": ref_moves, "notes": notes}


def _owning_room_block(text, offset):
    for blk in R.scan_room_blocks(text):
        if blk.start <= offset < blk.end:
            return blk
    return None


# ---------------------------------------------------------------------------
# 编辑
# ---------------------------------------------------------------------------

def make_edits(pl, texts):
    edits = {}

    def record(zone, e):
        edits.setdefault(zone, []).append(e)

    for zone, bid, a, b in pl["deletes"]:
        record(zone, (a, b, ""))

    for zone, bid, merged in pl["merges"]:
        text = texts[zone]
        im = locate(text, R.RE_ITEMS_HEADER, bid)
        i_open = text.index("{", im.start())
        i_close = block_span(text, i_open)
        i_body = text[i_open + 1:i_close]
        # 锚在 name 行之后（没有 name 就抛，绝不猜位置）
        try:
            ns, ne = key_value_span(i_body, "name")
        except UnknownShape:
            raise UnknownShape("%s: items %r has no name line to anchor after"
                               % (zone, bid))
        ins = i_open + 1 + ne + 1
        if ins > i_close + 1:
            raise UnknownShape("%s: items %r: insertion point past block end"
                               % (zone, bid))
        # 用 items 块自己 name 行的前导空白，保证与既有键风格一致。
        # 注意不能拿「行首偏移」去取缩进 —— 行首处的 text[start:offset] 恒为空。
        name_line = i_body[ns:].split("\n")[0]
        indent = name_line[:len(name_line) - len(name_line.lstrip(" \t"))]
        body = "".join("%s%s\n" % (indent, t.lstrip()) for _k, t in merged)
        record(zone, (ins, ins, body))

    for zone, bid, room in pl["ref_moves"]:
        text = texts[zone]
        src = R.room_block_of(text, "room_characters", room)
        dst = R.room_block_of(text, "room_items", room)
        s_arr = R.parse_array(src, text)
        d_arr = R.parse_array(dst, text)
        target = "characters.%s.id" % bid
        kept = [p for p in s_arr.entry_parts if R.entry_id(p) != target]
        if len(kept) == len(s_arr.entry_parts):
            raise UnknownShape("%s %s: %r not in room_characters" % (zone, room, bid))
        new_inner = ",".join(kept) + s_arr.tail_ws if kept else ""
        record(zone, (s_arr.lb + 1, s_arr.rb, new_inner))

        new_entry = "{ id = items.%s.id }" % bid
        if d_arr.is_empty:
            record(zone, (d_arr.lb + 1, d_arr.rb,
                          "\n%s%s" % (R.INDENT, new_entry) + R.ARRAY_TAIL))
        else:
            # 追加到最后一条之后。插入点取 inner 去掉尾随空白后的长度，于是原来
            # 黏在 `]` 前面的那段 tail 空白**原封不动留在新条目之后** —— 不能再
            # 额外拼一份 tail_ws，否则 `]` 前会多出一倍空白（实测 4 空格变 8）。
            ins = d_arr.lb + 1 + len(d_arr.inner.rstrip(" \t"))
            record(zone, (ins, ins, ",\n" + R.INDENT + new_entry))

    for zone in edits:
        edits[zone].sort(key=lambda t: t[0])
        for x, y in zip(edits[zone], edits[zone][1:]):
            if y[0] < x[1]:
                raise UnknownShape("%s: overlapping edits at %d/%d"
                                   % (zone, x[0], y[0]))
    return edits


# ---------------------------------------------------------------------------
# 门禁
# ---------------------------------------------------------------------------

def gate(pl, texts, results, survey):
    fails = []
    warns = []

    n_pairs = len(pl["pairs"])
    if len(pl["deletes"]) != n_pairs:
        fails.append("G1 plans %d deletes for %d pairs"
                     % (len(pl["deletes"]), n_pairs))

    # G2：删干净了、items 还在
    for zone, bid in pl["pairs"]:
        after = results["texts"][zone]
        if any(m.group(2) == bid for m in R.RE_CHAR_HEADER.finditer(after)):
            fails.append("G2 %s: characters %r still present" % (zone, bid))
        if not any(m.group(2) == bid for m in R.RE_ITEMS_HEADER.finditer(after)):
            fails.append("G2 %s: items %r missing" % (zone, bid))

    # G3：块计数
    for zone in ZONES:
        before, after = texts[zone], results["texts"][zone]
        exp = sum(1 for z, _b in pl["pairs"] if z == zone)
        nc = (len(R.RE_CHAR_HEADER.findall(before))
              - len(R.RE_CHAR_HEADER.findall(after)))
        ni = (len(R.RE_ITEMS_HEADER.findall(after))
              - len(R.RE_ITEMS_HEADER.findall(before)))
        if nc != exp:
            fails.append("G3 %s characters blocks: expected -%d, actual %d"
                         % (zone, exp, nc))
        if ni != 0:
            fails.append("G3 %s items blocks: expected +0, actual %d" % (zone, ni))

    # G4：不再有重复块（同区、同类、同 id 两块）
    for zone in ZONES:
        after = results["texts"][zone]
        seen = collections.Counter(m.group(2) for m in R.RE_ITEMS_HEADER.finditer(after))
        for bid, n in seen.items():
            if n > 1:
                fails.append("G4 %s: %d items blocks named %r" % (zone, n, bid))

    # G5：合并的键恰好一个、文本等于「name 行缩进 + 去缩进原文」
    for zone, bid, merged in pl["merges"]:
        after = results["texts"][zone]
        im = locate(after, R.RE_ITEMS_HEADER, bid)
        i_open = after.index("{", im.start())
        i_close = block_span(after, i_open)
        body = after[i_open + 1:i_close]
        present = [k for k in top_keys(body) if k in dict(merged)]
        if sorted(present) != sorted(k for k, _t in merged):
            fails.append("G5 %s items %r: merged keys %r, expected %r"
                         % (zone, bid, present, [k for k, _t in merged]))
        for key, src in merged:
            try:
                s, e = key_value_span(body, key)
            except UnknownShape:
                fails.append("G5 %s items %r: no %s after merge" % (zone, bid, key))
                continue
            got = body[s:e]
            # 期望文本 = name 行的前导空白 + 去掉缩进后的原文
            ns2, _ne = key_value_span(body, "name")
            nl = body[ns2:].split("\n")[0]
            ind = nl[:len(nl) - len(nl.lstrip(" \t"))]
            want = ind + src.lstrip()
            if got != want:
                fails.append("G5 %s items %r: %s text mismatched\n     want %r\n     got  %r"
                             % (zone, bid, key, want, got))

    # G6：被删块所在的区，事后不得再引用它。
    # 只查**同区**：`characters.<id>` 按区解析，别的区有同名块与本区无关
    # （实测 lingxiao 自己有 characters "yan"，引用落到本区块，与 kunming 删除无关）。
    by_zone = collections.defaultdict(list)
    for zone, bid in pl["pairs"]:
        by_zone[zone].append(bid)
    for zone, bids in by_zone.items():
        for bid in bids:
            if re.search(r'\bcharacters\.%s\b' % re.escape(bid),
                         results["texts"][zone]):
                fails.append("G6 %s still references characters.%s after deletion"
                             % (zone, bid))

    # G7：搬过去的引用确实落在 room_items 里，源侧幸存条目逐字保留
    for zone, bid, room in pl["ref_moves"]:
        before, after = texts[zone], results["texts"][zone]
        s_before = R.parse_array(R.room_block_of(before, "room_characters", room),
                                 before)
        s_after = R.parse_array(R.room_block_of(after, "room_characters", room), after)
        for p in s_after.entry_parts:
            if p.strip() not in s_before.inner:
                fails.append("G7 %s room_characters %r: survivor mutated: %r"
                             % (zone, room, p.strip()))
        d_after = R.parse_array(R.room_block_of(after, "room_items", room), after)
        if not any(R.entry_id(p) == "items.%s.id" % bid for p in d_after.entry_parts):
            fails.append("G7 %s room_items %r: items.%s.id not landed" % (zone, room, bid))

    # G8：validate_ucl 五个检查，不允许出现新问题
    before = R.validate_ucl_snapshot(texts)
    after = R.validate_ucl_snapshot(results["texts"])
    for rel in sorted(before):
        b, a = set(before[rel]), set(after.get(rel, []))
        if a - b:
            fails.append("G8 %s NEW issues: %s" % (rel, sorted(a - b)))
        if b - a:
            warns.append("G8 %s resolved issues: %s" % (rel, sorted(b - a)))

    # G9：勘察缓存仍与当前文件对得上（**按 id，不按行号** —— 搬引用会增删行，
    # 行号必漂，实测 83 条假失败；reclassify 的 G7 早已为此改成 id 校验）。
    # 后置条件：survey 判为 item 的 id，事后不得再「同类同名两块」并存。
    expected = collections.defaultdict(set)
    for rec in survey["records"]:
        if rec["classification"] == "item":
            expected[rec["file"]].add(rec["id"])

    dual_before = dual_after = 0
    for zone in ZONES:
        for text, which in ((texts[zone], "before"),
                            (results["texts"][zone], "after")):
            char_ids = {m.group(2) for m in R.RE_CHAR_HEADER.finditer(text)}
            item_ids = {m.group(2) for m in R.RE_ITEMS_HEADER.finditer(text)}
            for bid in sorted(expected.get(zone, ())):
                if bid not in char_ids and bid not in item_ids:
                    if which == "before":
                        fails.append("G9 stale survey cache: %s has no block header "
                                     "for %r" % (zone, bid))
            both = (char_ids & item_ids) & expected.get(zone, set())
            if which == "before":
                dual_before += len(both)
            else:
                dual_after += len(both)
                for bid in sorted(both):
                    fails.append("G9 %s: %r still exists as BOTH characters and items "
                                 "header after dedup" % (zone, bid))
    print("  G9 dual-header pairs: before %d, after %d" % (dual_before, dual_after))
    if dual_after != 0:
        print("  WARN G9: %d dual-header pairs remain" % dual_after)
    return fails, warns


# ---------------------------------------------------------------------------
# 驱动
# ---------------------------------------------------------------------------

def run(texts, survey):
    pl = build_plan(texts, survey)
    edits = make_edits(pl, texts)
    out = {z: R.apply_edits(texts[z], edits.get(z, [])) for z in ZONES}
    return pl, {"texts": out}


def load_survey(argv):
    cache = R.SURVEY_CACHE
    if "--fresh" not in argv and os.path.exists(cache):
        with io.open(cache, encoding="utf-8") as fh:
            return json.load(fh)
    survey = S.survey()
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    with io.open(cache, "w", encoding="utf-8") as fh:
        json.dump(survey, fh, ensure_ascii=False)
    return survey


def main(argv):
    apply_mode = "--apply" in argv

    survey = load_survey(argv)
    texts = R.read_all_zones()

    print("planning ...")
    pl, results = run(texts, survey)
    print("  target pairs                 : %d" % len(pl["pairs"]))
    print("  blocks to delete             : %d" % len(pl["deletes"]))
    for k, v in sorted(pl["notes"].items()):
        print("    %-34s %d" % (k, v))
    print("  blocks gaining merged keys   : %d" % len(pl["merges"]))
    print("  references to move            : %d" % len(pl["ref_moves"]))
    for zone, bid, room in pl["ref_moves"]:
        print("    %s: characters.%s -> items.%s (room %r)"
              % (os.path.basename(zone), bid, bid, room))

    print("gating ...")
    fails, warns = gate(pl, texts, results, survey)
    for w in warns[:10]:
        print("  NOTE %s" % w)
    if len(warns) > 10:
        print("  NOTE ... and %d more resolved issues" % (len(warns) - 10))
    if fails:
        print("  %d gate failure(s):" % len(fails))
        for f in fails[:40]:
            print("    FAIL %s" % f)
        if len(fails) > 40:
            print("    ... and %d more" % (len(fails) - 40))
        print("ABORT: %d gate failure(s), nothing written" % len(fails))
        return 1
    print("  all gates passed")

    changed = [z for z in ZONES if results["texts"][z] != texts[z]]
    print("  files to change              : %d" % len(changed))

    # G10 幂等
    print("G10 idempotency re-run ...")
    pl2, res2 = run(results["texts"], survey)
    pending = sum(1 for z in ZONES if res2["texts"][z] != results["texts"][z])
    print("G10 idempotency: %d file(s) still differ (expect 0)" % pending)
    if pending:
        for z in ZONES:
            if res2["texts"][z] != results["texts"][z]:
                print("   differs: %s" % z)
        print("ABORT: not idempotent, nothing written")
        return 1

    if not apply_mode:
        print("DRY-RUN OK (no file written; pass --apply to write)")
        return 0

    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = os.path.join(ROOT, "tmp", "backup-dedup-%s" % stamp)
    for z in changed:
        dst = os.path.join(backup, z)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with io.open(dst, "w", encoding="utf-8", newline="") as fh:
            fh.write(texts[z])
    print("  backup -> %s" % os.path.relpath(backup, ROOT).replace("\\", "/"))
    for z in changed:
        R.write(z, results["texts"][z])
    print("  wrote %d file(s)" % len(changed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
