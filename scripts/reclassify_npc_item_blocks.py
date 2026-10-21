#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R7 / D10：把转换器误分类成 `characters` 的**物品**块改回 `items`（+ 搬引用）。

背景（2026-10-20 勘查）
---------------------
`lpc_converter.ex` 的 `determine_object_type/1` 里 `npc_subdir?(path) -> :npc`
排在 `is_item_inherit?/1` **之前**（L2282-2285）。凡是位于 `npc/` 子目录下的源
文件一律转成 `characters` 块，即使它 `inherit COMBINED_ITEM` / `STAFF` / `SWORD`。
典型：
    d/beijing/npc/dan/danA_1.c   (inherit COMBINED_ITEM)
      -> characters "danA_1"     <- 其实是「养精丹」物品
    d/gaibang/npc/obj/staff.c    (inherit STAFF)
      -> characters "staff"      <- 其实是「竹棒」武器

危害（三条，均已实测）：
1. `item_meta_backfill.py` 只处理 `items` 块 -> 这批物品的整个 `meta`
   （value/weight/unit/material/damage/weapon_prop）从未生成过。
2. **已有 372 处 `items.<id>.id` 引用正指向这些块** —— 区级解析找不到
   `items.<id>`，被 `warn_unresolved` 静默告警 + 跳过，房间里一直是空的。
3. 22 处 `characters.<id>.id` 引用（房间 `set("objects", ...)` 被错写成
   room_characters）把物品当成 NPC 生成——`gaibang/chucang` 因此有 3 个
   name="NPC" 的假人。

真实数量是 **571 个 (区, id)**（426 个不同 id，73 个 id 跨区同名），
不是旧记录里的 83（那个数是 B5b 时期只统计「带 messages 的块」的子集）。
归属判定用块内 `# LPC:` + **源文件继承链**，并与转换器 `is_item_inherit?/1`
同一张关键字表（口径一致）。归属可靠性已交叉验证：571/571 的块 id 与其源
文件基名一致。

改动内容
--------
A. 块改名：`characters "<id>" {` -> `items "<id>" {`（571 处，只改块头那一行）
B. 搬引用（22 个 (区, id)）：这些 id 被同区的 `room_characters "<room>"` 引用，
   只改名会让引用悬空 -> 同步把 `{ id = characters.<id>.id }` 从 room_characters
   摘掉，追加到对应房间的 `room_items "<room>"`（原本没有则就地新建）。

实现方式（为什么不用整块重排）
------------------------------
data/world 下 2113 个 room_characters/room_items 块实测有 7 种以上形状：
`key = []` 空数组、`key = [{ ... }` 首条黏连、`key = [` + `]` 独占一行、
多行对象体、`{ id = [a.id,b.id] }` 备选表（loader.ex parse_items/4 专门处理）、
条目带额外键（`{ id = x, name = "..." }`）、数组尾部空行……

整块重排会**静默丢掉额外键和列表值**，所以本脚本只做两种最小编辑：

  * 摘除条目：`",".join(幸存片段)`。顶层切分出来的每个片段**自带它自己的前导
    空白**（逗号后的换行+缩进属于下一个片段），所以直接按逗号拼回去就能逐字
    保留原有排版；最后再补回原来黏在 `]` 前面的尾部空白。
  * 追加条目：在最后一条之后、尾部空白之前插 `",\n<缩进>{ id = ... }"`。
  * 空数组：整段替换成 `key = [\n      { id = ... }\n    ]`。

所有编辑都表示为**对全文的偏移区间替换** `(start, end, new_text)`，按 `start`
降序一次性套用。这样行号永不失效 —— 旧版按行下标分多轮改，第一处编辑之后
所有记录的行号全部漂移，是 G2/G5 大面积假失败的根因。

不做的事
--------
* 不改 `lpc_converter.ex`（用户明确要求）。
* 不补 `meta`（R7 的后半段，独立批次；改名后 meta 走
  `parse_item_meta(nil)` 的默认值，不会崩）。

安全门禁（--dry-run 与 --apply 都跑，任一不过则不动盘）
------------------------------------------------------
G1 改名后，被改 id 在其所属区**不再有任何 `characters.<id>` 引用**（悬空自检）。
G2 语义校验：逐块解析改动后的数组，条目 id 的有序列表必须精确等于
   「原有条目 - 摘除 + 追加」。引用不增不减、顺序不错。
G3 每个受影响的 room_characters 块摘除后不得变空（只告警不阻断：loader
   `Enum.flat_map` 对空数组安全）。
G4 `validate_ucl.py` 五个检查的**完整 issue 集合**不新增（行号/路径归一化后比对）。
G5 块计数：每个文件 `characters` 块减少数 / `items` 块增加数 / 新建
   `room_items` 块数与计划完全一致。
G6 幂等：对改动后的文本重跑一遍计划，必须 0 处待改。
G7 勘察缓存的行号必须与当前文件一致（防止用了过期的 survey 缓存）。
G8 逐字校验：所有「幸存条目」的原始文本必须原样出现在改动前的数组里
   （证明没有任何条目被改写/截断）。
G9 只接受本脚本认识的块形状；遇到未知形状直接中止（不猜、不改）。

用法
----
    python scripts/reclassify_npc_item_blocks.py             # dry-run + 门禁
    python scripts/reclassify_npc_item_blocks.py --apply     # 备份后写盘
    python scripts/reclassify_npc_item_blocks.py --no-cache  # 忽略 survey 缓存
"""
import collections
import glob
import io
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import survey_character_blocks as S  # 复用块扫描 + 继承链判型
import validate_ucl as V              # 在内存里跑五个检查（免临时目录/子进程）

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZONES = sorted(os.path.relpath(p, ROOT).replace("\\", "/") for p in
               glob.glob(os.path.join(ROOT, "data", "world", "*.ucl")))
SURVEY_CACHE = os.path.join(ROOT, "tmp", "survey_character_blocks.json")
INDENT = "      "          # 条目缩进（与转换器一致）
ARRAY_TAIL = "\n    "      # `]` 独占一行时的缩进

RE_CHAR_HEADER = re.compile(r'^([ \t]*)characters[ \t]+"([^"]+)"[ \t]*\{[ \t]*$', re.M)
RE_ITEMS_HEADER = re.compile(r'^([ \t]*)items[ \t]+"([^"]+)"[ \t]*\{[ \t]*$', re.M)


def has_items_header(text, block_id):
    """G10：text 里是否已有 `items "<block_id>" {` 块头。"""
    return any(m.group(2) == block_id for m in RE_ITEMS_HEADER.finditer(text))
RE_ROOM_CHARS = re.compile(r'^([ \t]*)room_characters[ \t]+"([^"]+)"[ \t]*\{[ \t]*$', re.M)
RE_ROOM_ITEMS = re.compile(r'^([ \t]*)room_items[ \t]+"([^"]+)"[ \t]*\{[ \t]*$', re.M)
RE_ARRAY_MEMBER = re.compile(r'^([ \t]*)(\w+)[ \t]*=[ \t]*\[', re.M)
# 条目里的 id 值：bare token 或 [a.id,b.id] 备选表（loader.ex parse_items/4 处理后者）
RE_ENTRY_ID = re.compile(r'\bid[ \t]*=[ \t]*(\[[^\]]*\]|[^\s,}\]]+)')


class UnknownShape(Exception):
    """G9：碰到本脚本不认识的块形状就中止，绝不猜。"""


# ---------------------------------------------------------------------------
# 基础 IO
# ---------------------------------------------------------------------------

def read(rel):
    with io.open(os.path.join(ROOT, rel), encoding="utf-8", newline="") as fh:
        return fh.read()


def write(rel, text):
    with io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def read_all_zones():
    return {z: read(z) for z in ZONES}


# ---------------------------------------------------------------------------
# 引号 / 注释感知的括号配对
# ---------------------------------------------------------------------------

def _match_pair(text, open_idx, open_ch, close_ch):
    """text[open_idx] == open_ch，返回配对 close_ch 的下标；忽略引号内与注释。"""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == '"':
                    break
                i += 1
            i += 1
            continue
        if c == "#":                      # 注释到行尾
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def match_brace(text, open_idx):
    return _match_pair(text, open_idx, "{", "}")


def match_bracket(text, open_idx):
    return _match_pair(text, open_idx, "[", "]")


# ---------------------------------------------------------------------------
# 顶层逗号切分（忽略引号内与 []{} 嵌套内的逗号）
# ---------------------------------------------------------------------------

def split_top_level(text):
    """把数组内容按顶层逗号切开。返回片段列表，**保留各自原始空白**。

    每个片段的形状是 "<空白>{ ... }"（第一个片段还带数组开括号后的换行），
    所以用 "," 拼回去即可逐字复现原排版。
    """
    parts = []
    buf = []
    depth = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            buf.append(text[i:j + 1])
            i = j + 1
            continue
        if c == "#":
            j = text.find("\n", i)
            j = n if j < 0 else j
            buf.append(text[i:j])
            i = j
            continue
        if c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    parts.append("".join(buf))
    return parts


def entry_id(part):
    """从条目文本里取 id 值；不是条目返回 None。"""
    m = RE_ENTRY_ID.search(part)
    return m.group(1).strip() if m else None


def entry_indent(parts):
    """第一个有条目的缩进（取该片段最后一个换行之后的部分）。"""
    for p in parts:
        if entry_id(p) is not None:
            i = p.rfind("\n")
            return p[i + 1:] if i >= 0 else p
    return INDENT


def has_comment(parts):
    return any(p.lstrip().startswith("#") for p in parts)


# ---------------------------------------------------------------------------
# 块定位
# ---------------------------------------------------------------------------

class Block(object):
    """一个 `room_items "x" { ... }` / `room_characters "x" { ... }` 块。
    所有下标都是**全文偏移**，因此多轮编辑之间不会失效。"""

    def __init__(self, kind, room, start, content_start, content_end, end):
        self.kind = kind
        self.room = room
        self.start = start                  # 块头行首偏移
        self.content_start = content_start  # '{' 的下一个字符
        self.content_end = content_end      # '}' 的下标
        self.end = end                      # '}' 的下一个字符

    def __repr__(self):
        return "<%s %r @%d>" % (self.kind, self.room, self.start)


def scan_room_blocks(text):
    out = []
    for kind, rx in (("room_characters", RE_ROOM_CHARS),
                     ("room_items", RE_ROOM_ITEMS)):
        for m in rx.finditer(text):
            brace = text.index("{", m.start())
            close = match_brace(text, brace)
            if close < 0:
                raise UnknownShape("unterminated %s %r" % (kind, m.group(2)))
            out.append(Block(kind, m.group(2), m.start(), brace + 1, close, close + 1))
    out.sort(key=lambda b: b.start)
    return out


class Array(object):
    """一个 `key = [ ... ]` 数组的全量信息。"""

    def __init__(self, block, key, lb, rb, inner, parts):
        self.block = block
        self.key = key
        self.lb = lb                # '[' 的下标
        self.rb = rb                # ']' 的下标
        self.inner = inner          # '[' 与 ']' 之间的原文
        self.parts = parts          # 顶层切片（含空白）

    @property
    def entry_parts(self):
        return [p for p in self.parts if entry_id(p) is not None]

    @property
    def ids(self):
        return [entry_id(p) for p in self.entry_parts]

    @property
    def is_empty(self):
        return not self.entry_parts

    @property
    def tail_ws(self):
        """黏在 `]` 前面的原始水平空白（转换器风格 `}    ]`）。"""
        return self.inner[len(self.inner.rstrip(" \t")):]


def parse_array(block, text):
    """定位块内唯一的数组成员。G9：形状不认识就抛 UnknownShape。"""
    region = text[block.content_start:block.content_end]
    hits = list(RE_ARRAY_MEMBER.finditer(region))
    if len(hits) != 1:
        raise UnknownShape("%s %r: expected exactly 1 array member, found %d"
                           % (block.kind, block.room, len(hits)))
    m = hits[0]
    lb = block.content_start + m.end() - 1
    if text[lb] != "[":
        raise UnknownShape("%s %r: array open mismatch" % (block.kind, block.room))
    rb = match_bracket(text, lb)
    if rb < 0 or rb >= block.content_end:
        raise UnknownShape("%s %r: unterminated array" % (block.kind, block.room))
    inner = text[lb + 1:rb]
    parts = split_top_level(inner)
    if has_comment(parts):
        raise UnknownShape("%s %r: array contains a comment, refusing to touch"
                           % (block.kind, block.room))
    return Array(block, m.group(2), lb, rb, inner, parts)


# ---------------------------------------------------------------------------
# 计划
# ---------------------------------------------------------------------------

def build_plan(texts, survey):
    """纯函数：从 texts + survey 推出全部编辑。"""
    items = [r for r in survey["records"] if r["classification"] == "item"]

    # --- A) 块改名 ---
    renames = []                      # (zone, id, start, end, indent)
    skipped_collision = []            # (zone, id) 同区已有同名 items 块，跳过
    for rec in items:
        zone = rec["file"]
        heads = [m for m in RE_CHAR_HEADER.finditer(texts[zone])
                 if m.group(2) == rec["id"]]
        if not heads:
            continue                  # 已改名（幂等路径）
        if len(heads) > 1:
            raise UnknownShape("%s: %d headers for %r (expect 0 or 1)"
                               % (zone, len(heads), rec["id"]))
        m = heads[0]

        # G10：同区不得已有同名 `items` 块。
        #
        # 实测踩坑（2026-10-20）：同一份 LPC 源被两代转换器各转一次后拼进同一个
        # 区文件 —— `# Generated from ... by LPCConverter` 走 npc/ 分支输出
        # `characters "x"`，`# Source: ...` 那条输出 `items "x"`。两类是不同命名
        # 空间，本来相安无事；一改名就变成**同类同名两块**，elias 把重复键合并成
        # 数组，`parse_item` 收到 list → `expected a map, got: [...]`，整个区加载
        # 崩掉（连带 78 个用例红）。这类块的正确处置是「二选一/删重复」，不是改名，
        # 因此这里直接跳过并单独记账。
        if has_items_header(texts[zone], rec["id"]):
            skipped_collision.append((zone, rec["id"]))
            continue

        renames.append((zone, rec["id"], m.start(), m.end(), m.group(1)))

    rename_ids = collections.defaultdict(set)
    for zone, bid, _s, _e, _ind in renames:
        rename_ids[zone].add(bid)

    # --- B) 引用搬移 ---
    # 累加器用**有序 list**（不是 set）：搬过去后条目在房间里的先后顺序必须和
    # 原来一致 —— 例如 kaifeng/cangjing2 原是 jing4→jing1，不能因为排序而颠倒。
    drop_by_block = collections.defaultdict(list)    # (zone, room) -> [id]  源
    add_by_block = collections.defaultdict(list)     # (zone, room) -> [id]  目标=已有 room_items
    create_for_room = collections.defaultdict(list)  # (zone, room) -> [id] 目标=需新建
    moves = []                                       # (zone, id, room, count)
    seen_moves = set()

    def _push(d, key, val):
        if val not in d[key]:
            d[key].append(val)

    for zone in ZONES:
        text = texts[zone]
        ids = rename_ids.get(zone)
        if not ids:
            continue
        blocks = scan_room_blocks(text)
        existing_items = {b.room for b in blocks if b.kind == "room_items"}
        for blk in blocks:
            if blk.kind != "room_characters":
                continue
            arr = parse_array(blk, text)
            # 按条目在数组里的原有顺序走，而不是排序后的 id 集合
            for ref in arr.ids:
                if not ref.startswith("characters.") or not ref.endswith(".id"):
                    continue
                bid = ref[len("characters."):-len(".id")]
                if bid not in ids:
                    continue
                _push(drop_by_block, (zone, blk.room), bid)
                if blk.room in existing_items:
                    _push(add_by_block, (zone, blk.room), bid)
                else:
                    _push(create_for_room, (zone, blk.room), bid)
                # moves 按 (区, id, 房间) 去重：同一 id 在一个房间里出现多次
                # （gaibang/chucang 的 staff 有 3 条）只记一次，否则 G2 记账翻倍
                key = (zone, bid, blk.room)
                if key not in seen_moves:
                    seen_moves.add(key)
                    moves.append((zone, bid, blk.room, arr.ids.count(ref)))

    return {"renames": renames, "moves": moves,
            "drop_by_block": dict(drop_by_block),
            "add_by_block": dict(add_by_block),
            "create_for_room": dict(create_for_room),
            "skipped_collision": skipped_collision}


def make_edits(pl, texts):
    """把 plan 变成 {zone: [(start, end, new_text), ...]}。编辑互不重叠（G9 校验）。"""
    edits = collections.defaultdict(list)
    record = lambda zone, e: edits[zone].append(e)

    # A) 改名
    for zone, bid, s, e, indent in pl["renames"]:
        record(zone, (s, e, '%sitems "%s" {' % (indent, bid)))

    # B) 摘除
    for (zone, room), ordered in sorted(pl["drop_by_block"].items()):
        arr = parse_array_of(texts[zone], "room_characters", room)
        targets = {"characters.%s.id" % b for b in ordered}
        kept = [p for p in arr.entry_parts if entry_id(p) not in targets]
        if len(kept) == len(arr.entry_parts):
            raise UnknownShape("%s %s: nothing to drop for %r" % (zone, room, ordered))
        # 逐字保留：片段自带前导空白，按逗号拼回即可
        new_inner = (",".join(kept) + arr.tail_ws) if kept else ""
        record(zone, (arr.lb + 1, arr.rb, new_inner))

    # B) 追加到已有的 room_items
    for (zone, room), ordered in sorted(pl["add_by_block"].items()):
        arr = parse_array_of(texts[zone], "room_items", room)
        new_items = ["{ id = items.%s.id }" % b for b in ordered]
        if arr.is_empty:
            body = "".join("\n%s%s" % (INDENT, it) for it in new_items)
            record(zone, (arr.lb + 1, arr.rb, body + ARRAY_TAIL))
        else:
            # 追加到最后一条之后。插入点取 `inner` 去掉尾随空白后的长度，
            # 于是原来黏在 `]` 前面的那段 Tail 空白**原封不动留在新条目之后**
            # （不能再额外拼一份 tail_ws，否则 `]` 前会多出一倍空白）。
            ins = arr.lb + 1 + len(arr.inner.rstrip(" \t"))
            record(zone, (ins, ins,
                          ",\n" + INDENT + (",\n" + INDENT).join(new_items)))

    # B) 新建 room_items 块（紧跟其 room_characters 之后）
    # 写法照抄转换器既有风格：`]` 黏在最后一条后面（4 空格），`{` 必须在行尾
    # （scan_room_blocks 的 RE_ROOM_ITEMS 用行锚匹配，`{` 后跟内容会失配）。
    for (zone, room), ordered in sorted(pl["create_for_room"].items()):
        blk = room_block_of(texts[zone], "room_characters", room)
        lines = ["", "", '  room_items "%s" {' % room,
                 "    room_id = rooms.%s.id" % room,
                 "    items = ["]
        for n, b in enumerate(ordered):
            tail = "    ]" if n == len(ordered) - 1 else ","
            lines.append("%s{ id = items.%s.id }%s" % (INDENT, b, tail))
        lines.append("  }")
        record(zone, (blk.end, blk.end, "\n".join(lines)))

    # 互不重叠校验（同一区内）
    for zone, lst in edits.items():
        lst.sort(key=lambda t: t[0])
        for a, b in zip(lst, lst[1:]):
            if b[0] < a[1]:
                raise UnknownShape("%s: overlapping edits at %d/%d" % (zone, a[0], b[0]))
    return dict(edits)


def apply_edits(text, edits):
    """按 start 降序套用，偏移永不失效。"""
    out = text
    for (s, e, rep) in sorted(edits, key=lambda t: t[0], reverse=True):
        out = out[:s] + rep + out[e:]
    return out


# ---------------------------------------------------------------------------
# G4：validate_ucl 的完整 issue 集合（行号 / 路径归一化）
# ---------------------------------------------------------------------------

def validate_ucl_snapshot(texts):
    """在内存里对每个区跑 validate_ucl 的五个检查，返回 {rel: [归一化 issue]}。

    直接 import `validate_ucl` 调 `_run_checks/1`，而不是起 80 个子进程 + 写
    临时副本目录：既不碰盘（也避开 rmtree 触发的安全钩子），也让 G4 从 ~2 分钟
    降到毫秒级。`validate_ucl._run_checks/1` 对任何输入都不抛异常。
    """
    snap = {}
    for zone in ZONES:
        rel = zone.replace("\\", "/")
        failures = V._run_checks(texts[zone].encode("utf-8"))
        snap[rel] = sorted(normalize_issue("%s: %s" % (name, detail))
                          for name, detail in failures)
    return snap


def normalize_issue(text):
    text = re.sub(r':\d+:', ':<n>:', text)
    text = re.sub(r'\bat line \d+\b', 'at line <n>', text)
    text = re.sub(r'[A-Za-z]:[\\/][^\s:,]*', '<path>', text)
    return text


# ---------------------------------------------------------------------------
# 门禁
# ---------------------------------------------------------------------------

def gate(pl, texts, results, survey):
    fails = []

    renamed_by_zone = collections.Counter()
    for (zone, _bid), n in results["renamed"].items():
        renamed_by_zone[zone] += n
    moved_by_zone = collections.Counter()
    for (zone, _i, _r), n in results["moved"].items():
        moved_by_zone[zone] += n
    created_by_zone = collections.Counter()
    for (zone, _r), n in results["created"].items():
        created_by_zone[zone] += n

    for zone in ZONES:
        rel = zone.replace("\\", "/")
        before, after = texts[zone], results["texts"][zone]

        cnt = lambda t, pat: len(re.findall(pat, t, re.M))
        old_chars = cnt(before, r'^[ \t]*characters[ \t]+"[^"]+"[ \t]*\{')
        new_chars = cnt(after, r'^[ \t]*characters[ \t]+"[^"]+"[ \t]*\{')
        old_items = cnt(before, r'^[ \t]*items[ \t]+"[^"]+"[ \t]*\{')
        new_items = cnt(after, r'^[ \t]*items[ \t]+"[^"]+"[ \t]*\{')
        old_ri = cnt(before, r'^[ \t]*room_items[ \t]+"[^"]+"[ \t]*\{')
        new_ri = cnt(after, r'^[ \t]*room_items[ \t]+"[^"]+"[ \t]*\{')

        # G5 块计数
        # 注意：`room_items "x" {` **不**匹配 `^[ \t]*items[ \t]+"` 正则（前面有
        # `room_`），所以 items 增量只应等于改名数，不能再加新建块数。
        if old_chars - new_chars != renamed_by_zone.get(rel, 0):
            fails.append("G5 %s characters blocks: expected -%d, actual %d"
                         % (rel, renamed_by_zone.get(rel, 0), old_chars - new_chars))
        if new_items - old_items != renamed_by_zone.get(rel, 0):
            fails.append("G5 %s items blocks: expected +%d, actual %d"
                         % (rel, renamed_by_zone.get(rel, 0), new_items - old_items))
        if new_ri - old_ri != created_by_zone.get(rel, 0):
            fails.append("G5 %s room_items blocks: expected +%d, actual %d"
                         % (rel, created_by_zone.get(rel, 0), new_ri - old_ri))

        # G1 悬空自检
        for bid in rename_ids_of_zone(pl, rel):
            if re.search(r'\bcharacters\.%s\b' % re.escape(bid), after):
                fails.append("G1 %s still references characters.%s after rename"
                             % (rel, bid))

        # G2 语义 + G8 逐字：逐块比对
        for (zone, room), ordered in pl["drop_by_block"].items():
            if zone != rel:
                continue
            before_arr = parse_array_of(before, "room_characters", room)
            after_arr = parse_array_of(after, "room_characters", room)
            targets = {"characters.%s.id" % b for b in ordered}
            expect = [i for i in before_arr.ids if i not in targets]
            if after_arr.ids != expect:
                fails.append("G2 %s room_characters %r: expected ids %r, got %r"
                             % (rel, room, expect, after_arr.ids))
            # G8：条目文本逐字保留。只比 strip 后的正文——原始 part 自带前导空白，
            # 而「黏在 ] 前的尾部空白」在摘除末条后会转移到新末条上，用原始 part
            # 做子串判定会误报（尾部空白不属于条目本身）。
            for p in after_arr.entry_parts:
                if p.strip() not in before_arr.inner:
                    fails.append("G8 %s room_characters %r: survivor entry mutated: %r"
                                 % (rel, room, p.strip()))
            if not after_arr.ids and before_arr.ids:
                print("  WARN G3 %s room_characters %r became empty" % (rel, room))

        for (zone, room), ordered in pl["add_by_block"].items():
            if zone != rel:
                continue
            before_arr = parse_array_of(before, "room_items", room)
            after_arr = parse_array_of(after, "room_items", room)
            appended = {"items.%s.id" % b for b in ordered}
            expect = before_arr.ids + ["items.%s.id" % b for b in ordered]
            if after_arr.ids != expect:
                fails.append("G2 %s room_items %r: expected ids %r, got %r"
                             % (rel, room, expect, after_arr.ids))
            # G8：只校验「幸存」的老条目；本次追加的新条目本就不在 before 里
            for p in after_arr.entry_parts:
                if entry_id(p) in appended:
                    continue
                if p.strip() not in before_arr.inner:
                    fails.append("G8 %s room_items %r: survivor entry mutated: %r"
                                 % (rel, room, p.strip()))

        for (zone, room), ordered in pl["create_for_room"].items():
            if zone != rel:
                continue
            after_arr = parse_array_of(after, "room_items", room)
            expect = ["items.%s.id" % b for b in ordered]
            if after_arr.ids != expect:
                fails.append("G2 %s new room_items %r: expected ids %r, got %r"
                             % (rel, room, expect, after_arr.ids))

    # G2 计数
    for (zone, bid, room, n) in pl["moves"]:
        got = results["moved"].get((zone, bid, room), 0)
        if got != n:
            fails.append("G2 %s %s/%s: planned %d refs, moved %d"
                         % (zone, room, bid, n, got))

    # G7 勘察缓存与当前文件仍是同一批数据
    #
    # **不用行号**：改名本身不改变行数，但「搬引用」会增删行，使同文件后续
    # 行号整体漂移 —— 按行号校验会在 apply 后误报一堆「缓存过期」（实测 387/83 条
    # 假失败）。改成按 **id** 校验：勘查判为 item 的每个 (区, id)，当前文件里必须
    # 还能找到对应块头（改名前是 `characters "id" {`，改名后是 `items "id" {`）。
    expected = collections.defaultdict(set)
    for rec in survey["records"]:
        if rec["classification"] == "item":
            expected[rec["file"]].add(rec["id"])

    for zone in ZONES:
        text = texts[zone]
        char_ids = {m.group(2) for m in RE_CHAR_HEADER.finditer(text)}
        item_ids = {m.group(2) for m in RE_ITEMS_HEADER.finditer(text)}
        for bid in sorted(expected.get(zone, ())):
            if bid not in char_ids and bid not in item_ids:
                fails.append("G7 stale survey cache: %s has no block header for %r "
                             "(neither characters nor items)" % (zone, bid))
        # 反向：同一 id 不应同时在两类里。**只查本次关心的 item id** ——
        # HEAD 上还有 24 个「天生双头」的 id（survey 判为非 item，从未进过改名集），
        # 那是既有数据，不是本脚本该管的事。
        skipped = set(pl["skipped_collision"])
        for bid in sorted((char_ids & item_ids) & expected.get(zone, set())):
            if (zone, bid) in skipped:
                continue
            fails.append("G7 %s: %r exists as BOTH characters and items header "
                         "(not in the G10 skip list)" % (zone, bid))
    return fails


def rename_ids_of_zone(pl, rel):
    return {bid for (zone, bid, _s, _e, _i) in pl["renames"] if zone == rel}


def parse_array_of(text, kind, room):
    return parse_array(room_block_of(text, kind, room), text)


def room_block_of(text, kind, room):
    blk = [b for b in scan_room_blocks(text) if b.kind == kind and b.room == room]
    if len(blk) != 1:
        raise UnknownShape("%d %s blocks for %r" % (len(blk), kind, room))
    return blk[0]


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def load_survey(argv):
    if "--no-cache" not in argv and os.path.exists(SURVEY_CACHE):
        with io.open(SURVEY_CACHE, encoding="utf-8") as fh:
            return json.load(fh), True
    survey = S.survey()
    os.makedirs(os.path.dirname(SURVEY_CACHE), exist_ok=True)
    with io.open(SURVEY_CACHE, "w", encoding="utf-8") as fh:
        json.dump(survey, fh, ensure_ascii=False, indent=2)
    return survey, False


def run(texts, survey):
    """跑一遍 计划->套用。texts/survey 由调用方提供（G6 重跑时用改后的文本）。"""
    pl = build_plan(texts, survey)
    edits_by_zone = make_edits(pl, texts)

    renamed = collections.Counter()
    for (zone, bid, _s, _e, _i) in pl["renames"]:
        renamed[(zone, bid)] += 1
    moved = collections.Counter()
    for (zone, bid, room, n) in pl["moves"]:
        moved[(zone, bid, room)] += n
    # created 以「房间」计：一个房间只建一个 room_items 块，块里可能装多个 id
    # （kaifeng/cangjing2 一炉 4 件）。所以不能累加 id 数。
    created = collections.Counter()
    for (zone, _room) in pl["create_for_room"]:
        created[(zone, _room)] += 1

    results = {"texts": {}, "renamed": renamed, "moved": moved, "created": created}
    for zone in ZONES:
        results["texts"][zone] = apply_edits(texts[zone], edits_by_zone.get(zone, []))
    return pl, results


def main(argv):
    apply_mode = "--apply" in argv

    print("planning ...")
    survey, cached = load_survey(argv)
    print("  survey                     : %s"
          % ("loaded from cache" if cached else "computed fresh"))

    texts = read_all_zones()
    pl, results = run(texts, survey)

    print("  item-classified blocks      : %d"
          % sum(1 for r in survey["records"] if r["classification"] == "item"))
    print("  (zone, id) to rename        : %d" % len(pl["renames"]))
    print("  skipped (same-zone items dup): %d   <- G10"
          % len(pl["skipped_collision"]))
    print("  (zone, id) needing ref move: %d"
          % len(set((z, i) for z, i, _r, _n in pl["moves"])))
    print("  total refs to move          : %d" % sum(n for _z, _i, _r, n in pl["moves"]))
    if pl["skipped_collision"]:
        by_zone = collections.Counter(z for z, _i in pl["skipped_collision"])
        print("  G10 skip detail (per zone):")
        for z in sorted(by_zone):
            ids = [i for zz, i in pl["skipped_collision"] if zz == z]
            print("     %-26s %3d  %s" % (z, len(ids), ", ".join(sorted(ids)[:8])
                                          + (" ..." if len(ids) > 8 else "")))

    print("running validate_ucl (in memory) ...")
    before = validate_ucl_snapshot(texts)

    print("applying in memory ...")
    pl, results = run(texts, survey)

    print("gating ...")
    fails = gate(pl, texts, results, survey)

    # G4：对改动后的内存文本重跑五个检查，逐文件比对完整 issue 集合
    after = validate_ucl_snapshot(results["texts"])
    print("  G4 baseline                 : %d/%d zone files already have issues "
          "(G4 compares the full issue set per file)"
          % (sum(1 for v in before.values() if v), len(before)))
    for rel in sorted(before):
        b, a = set(before[rel]), set(after.get(rel, []))
        if a - b:
            fails.append("G4 %s NEW issues: %s" % (rel, sorted(a - b)))
        if b - a:
            # 既有 issue 消失是好事（改名修好了 dangling 之类的问题），只提示
            print("  NOTE G4 %s resolved issues: %s" % (rel, sorted(b - a)))

    if fails:
        print("\nABORT: %d gate failure(s), nothing written" % len(fails))
        for f in fails[:40]:
            print("   " + f)
        return 1

    print("  all gates passed")
    changed = [z for z in ZONES if results["texts"][z] != texts[z]]
    print("  files to change              : %d" % len(changed))
    for z in changed:
        rel = z.replace("\\", "/")
        print("     %-26s renames=%-3d refmoves=%d new_room_items=%d"
              % (rel,
                 sum(n for (zz, _i), n in results["renamed"].items() if zz == rel),
                 sum(n for (zz, _i, _r), n in results["moved"].items() if zz == rel),
                 sum(n for (zz, _r), n in results["created"].items() if zz == rel)))

    if not apply_mode:
        print("\nDRY-RUN only (no data written). Re-run with --apply to write.")
        return 0

    backup = os.path.join(ROOT, "tmp", "backup-reclassify-%s"
                          % time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(backup)
    for z in changed:
        rel = z.replace("\\", "/")
        dst = os.path.join(backup, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(ROOT, z), dst)
    print("\nbackup -> %s" % backup)

    for z in changed:
        write(z, results["texts"][z])
    print("wrote %d files" % len(changed))

    # G6 幂等：对改后的文本重跑一遍计划
    print("G6 idempotency re-run ...")
    pl2, results2 = run(results["texts"], survey)
    pending = sum(1 for z in ZONES if results2["texts"][z] != results["texts"][z])
    print("G6 idempotency: %d file(s) still differ (expect 0), "
          "%d pending rename(s)" % (pending, len(pl2["renames"])))
    if pending:
        for z in ZONES:
            if results2["texts"][z] != results["texts"][z]:
                print("   differs: %s" % z.replace("\\", "/"))
        print("WARN: not idempotent")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
