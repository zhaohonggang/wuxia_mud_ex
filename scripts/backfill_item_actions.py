#!/usr/bin/env python
"""第十二批：backfill item-side `add_action` verbs into `items` blocks.

LPC semantics
-------------
LPC `add_action(<handler_fn>, <verb>)` 注册对象私有动词。转换器只为 NPC 的
`characters` 块输出了 `init.add_actions`（存 verb），**物品块从未输出**——
`inherit/misc/_qin.c` 的 `play_qin` 等 add_action 全部静默丢失：
`play muqin` / `read shanshang` 在原世界可用，在 Kantele 世界无人应答。

本脚本把物品侧的 add_action 回填成 UCL **顶层**字段：

    actions = [{ verb = "play" handler = "play_qin" }]
    read_text = "……"                      # 仅 do_read 书册

`verb` 是玩家输入的词；`handler` 是 LPC handler 函数名（add_action 第一个
参数）。消费端：`Kantele.World.Item.Meta.actions`（loader.ex `parse_item/4`
读取）→ `Kantele.World.ItemActionDispatcher` → `ItemActionHandlers`
（handler 名 → Elixir 模块注册表）。loader 侧已先行落地（空 actions = 无动作，
对未回填物品零行为变化，P7）。

哪些块被写
----------
两类，均**只增不改**既有行：

1. 乐器（`play`，24 块）：LPC `inherit MI_QIN/MI_XIAO/MI_ZHENG` 且 init() 里
   `add_action("play_*", "play")` 的对象。琴→tanqin-jifa、箫→chuixiao-jifa、
   筝→guzheng-jifa（差异只在这些 skill 的 play() 文本，handler 侧分派）。
   注：`d/hengyang/npc/obj/tanmuqin.c` 有 add_action 但 UCL 无对应 items 块
   （只有转换器误判的 characters孪生块），不在范围。
2. 书册（`read`，4 块）：`add_action("do_read", "read")` 且 do_read 是纯
   notify_fail 长文案的对象。文案经 LPC 反转义（\\n→换行）后按数据管线惯例
   把换行折成空格（同 `_sanitize_ucl_sval`），写进顶层 `read_text`。
   `d/wudu/obj/tongpai.c` 的动词是 `see`（非 read），不在范围。

另外为缺 aliases 的 `city:shan_book` 补一行 `aliases`（LPC set_name 的 id 表，
`read shanshang` 的匹配依据；三本 hengyang 书册已有等价 aliases，跳过）。

值处理
------
- `actions`：UCL 行内表 `[{ verb = "..." handler = "..." }]`（elias 解析为
  `[%{verb: ..., handler: ...}]`，已实测）。
- `read_text`：`"..."`，字符串内 `"` → `'`、`[`/`]` → `(`/`)`、`;` → 空格
  （elias 词法限制，同转换器 sanitize 约定）、首尾 strip。
- aliases：`["id1", "id2"]`，6 空缩进（与同块其它 aliases 行对齐）。

安全（同 B3/B5b/B6/B8 协议）
--------------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：内存算完 + 过门禁（insertion-only + validate_ucl 完整 issue 集合
  比对、行号归一化），**全过**才备份、才写盘
* 备份写盘 **之前** 完成
* 幂等：已携带 `actions =` 的块跳过（二次 dry-run 应为 0）
* 自校验：每块的 verb/handler 必须与 LPC 源一致，aliases 已存在时必须已覆盖
  LPC id 表（否则中止而不是静默改行）
"""
import argparse
import datetime
import difflib
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

CORPUS = r"C:\files\git\mud"
WORLD = os.path.join(ROOT, "data", "world")
TMP = os.path.join(ROOT, "tmp")

# (zone, key, lpc path relative to CORPUS, kind)
# kind: "play" | "read"
TARGETS = [
    # ---- 乐器（play）----
    ("baituo", "tiezheng", "d/baituo/obj/tiezheng.c", "play"),
    ("baituo", "zheng", "d/baituo/obj/zheng.c", "play"),
    ("changan", "muqin", "d/changan/npc/obj/muqin.c", "play"),
    ("clone_lib", "tieqin", "clone/lonely/tieqin.c", "play"),
    ("clone_lib", "yaoqin", "clone/lonely/yaoqin.c", "play"),
    ("hengyang", "honghuqin", "d/hengyang/yueqi/honghuqin.c", "play"),
    ("hengyang", "jiaoyeqin", "d/hengyang/yueqi/jiaoyeqin.c", "play"),
    ("hengyang", "jiuxiaoqin", "d/hengyang/yueqi/jiuxiaoqin.c", "play"),
    ("hengyang", "qin_jimo", "d/hengyang/yueqi/qin-jimo.c", "play"),
    ("hengyang", "qin_jueyin", "d/hengyang/yueqi/qin-jueyin.c", "play"),
    ("hengyang", "qin_konggu", "d/hengyang/yueqi/qin-konggu.c", "play"),
    ("hengyang", "qin_tianlai", "d/hengyang/yueqi/qin-tianlai.c", "play"),
    ("hengyang", "shixuanqin_zhanguo", "d/hengyang/yueqi/shixuanqin-zhanguo.c", "play"),
    ("hengyang", "tanhuqin", "d/hengyang/yueqi/tanhuqin.c", "play"),
    ("hengyang", "zhongnishi", "d/hengyang/yueqi/zhongnishi.c", "play"),
    ("hengyang", "huqin", "d/hengyang/npc/obj/huqin.c", "play"),
    ("hengyang", "zhuxiao", "d/hengyang/npc/obj/zhuxiao.c", "play"),
    ("hengyang", "zhuxiao_liuquan", "d/hengyang/yueqi/zhuxiao-liuquan.c", "play"),
    ("hengyang", "zhuxiao_qingyin", "d/hengyang/yueqi/zhuxiao-qingyin.c", "play"),
    ("hengyang", "zhuxiao_shuiyun", "d/hengyang/yueqi/zhuxiao-shuiyun.c", "play"),
    ("hengyang", "zhuxiao_youlan", "d/hengyang/yueqi/zhuxiao-youlan.c", "play"),
    ("kunlun", "jwqin", "d/kunlun/obj/jwqin.c", "play"),
    ("meizhuang", "qin", "d/meizhuang/obj/qin.c", "play"),
    ("taohua", "zhuxiao", "d/taohua/obj/zhuxiao.c", "play"),
    # ---- 书册（read）----
    ("city", "shan_book", "d/city/npc/shanzi/shan-book.c", "read"),
    ("hengyang", "huxian_book", "d/hengyang/yueqi/huxian-book.c", "read"),
    ("hengyang", "yuepu_book", "d/hengyang/yueqi/yuepu-book.c", "read"),
    ("hengyang", "yueqi_book", "d/hengyang/yueqi/yueqi-book.c", "read"),
]

ADD_ACTION = re.compile(r'add_action\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"')
STR_LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
NAME_LINE = re.compile(r'^(\s*)name\s*=\s*"')
ALIASES_LINE = re.compile(r'^\s*aliases\s*=\s*\[')
META_OPEN = re.compile(r'^\s*meta\s*=\s*\{\s*$')

# 预期动词表：LPC 源声明的 verb/handler 必须落在这里，否则脚本中止（防手滑扩范围）
EXPECTED = {
    "play": "play",
    "read": "read",
}


def norm(path):
    return path.replace("\\", "/").lower()


def skeleton_delta(line):
    """Net brace count for one line, ignoring comments and string bodies."""
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if not in_str and ch == "#":
            break
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
            out.append(" ")
        else:
            if ch == '"':
                in_str = True
                out.append(" ")
            else:
                out.append(ch)
        i += 1
    s = "".join(out)
    return s.count("{") - s.count("}")


def iter_blocks(lines):
    """Yield (kind, key, open_idx, close_idx) per top-level block."""
    depth = 0
    pending = None
    for i, line in enumerate(lines):
        if depth == 0:
            stripped = line.strip()
            m = re.match(r'^(items|characters|rooms)\s+"([^"]+)"\s*\{\s*$', stripped)
            if m:
                pending = (m.group(1), m.group(2), i)
        nxt = depth + skeleton_delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            kind, key, start = pending
            yield kind, key, start, i
            pending = None
        depth = nxt


def unescape_lpc(s):
    out = []
    i = 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
            if nxt in mapping:
                out.append(mapping[nxt])
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def extract_balanced(text, open_idx):
    depth = 0
    i = open_idx
    in_str = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return text[open_idx + 1:i]
        i += 1
    return None


def sanitize_ucl_sval(s):
    """elias-lexable, newline-flattened UCL string value (converter convention)."""
    s = s.replace('"', "'")
    s = s.replace("[", "(")
    s = s.replace("]", ")")
    s = s.replace(";", " ")
    s = s.replace("\n", " ")
    s = s.replace("\r", " ")
    s = s.replace("\\", "/")
    return re.sub(r"\s+", " ", s).strip()


def parse_lpc(rel):
    path = os.path.join(CORPUS, rel.replace("/", os.sep))
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    am = ADD_ACTION.search(text)
    if not am:
        return None
    handler, verb = am.group(1), am.group(2)

    ids = []
    read_text = None
    if handler == "do_read":
        m = re.search(r"set_name\s*\(", text)
        if m:
            args = extract_balanced(text, m.end() - 1)
            if args is not None:
                g = re.search(r"\(\s*\{(.*?)\}", args, re.S)
                if g:
                    ids = [unescape_lpc(x) for x in STR_LIT.findall(g.group(1))]
        idx = text.find("notify_fail")
        while idx != -1:
            paren = text.find("(", idx)
            inner = extract_balanced(text, paren) if paren != -1 else None
            if inner is not None:
                parts = STR_LIT.findall(inner)
                if parts:
                    read_text = "".join(unescape_lpc(p) for p in parts)
                    break
            idx = text.find("notify_fail", idx + 1)
        if read_text is None:
            return None
    return {"handler": handler, "verb": verb, "ids": ids, "read_text": read_text}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    args = ap.parse_args()

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    parsed = {}
    for zone, key, rel, kind in TARGETS:
        info = parse_lpc(rel)
        if info is None:
            print("!! %s:%s cannot parse add_action/do_read from %s" % (zone, key, rel))
            return 2
        if info["verb"] != EXPECTED[kind]:
            print("!! %s:%s verb %r != expected %r" % (zone, key, info["verb"], EXPECTED[kind]))
            return 2
        parsed[(zone, key)] = info
    print("LPC sources parsed: %d targets" % len(parsed))

    planned = []
    stats = {"files": 0, "blocks_written": 0, "blocks_skipped": 0,
             "alias_lines": 0, "read_texts": 0, "inserted_lines": 0}

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        zone = fn[:-4]
        targets = [t for t in TARGETS if t[0] == zone]
        if not targets:
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            orig = fh.read()
        lines = orig.split("\n")

        # collect block spans for this file's targets
        spans = {}
        for kind, key, start, close in iter_blocks(lines):
            if kind == "items" and (zone, key) in parsed:
                if key in spans:
                    print("!! %s has duplicate items block %r" % (fn, key))
                    return 2
                spans[key] = (start, close)

        for zone_, key, rel, tkind in targets:
            if key not in spans:
                print("!! %s:%s items block not found in %s" % (zone, key, fn))
                return 2
        for key in spans:
            if not any(t[1] == key for t in targets):
                print("!! %s:%s spans but is not a target" % (zone, key))
                return 2

        insertions = []  # (line_idx, [lines])
        for zone_, key, rel, tkind in targets:
            info = parsed[(zone, key)]
            start, close = spans[key]
            body = "\n".join(lines[start + 1:close])

            if re.search(r"^\s*actions\s*=", body, re.M):
                stats["blocks_skipped"] += 1
                continue

            block_lines = ["  actions = [{ verb = \"%s\" handler = \"%s\" }]"
                           % (info["verb"], info["handler"])]
            if tkind == "read" and info["read_text"]:
                block_lines.append("")
                block_lines.append("  read_text = \"%s\"" % sanitize_ucl_sval(info["read_text"]))
                stats["read_texts"] += 1

            # insert before `meta = {` when present, else before block close
            insert_at = close
            for j in range(start + 1, close):
                if META_OPEN.match(lines[j]):
                    insert_at = j
                    break
            if insert_at > start + 1 and lines[insert_at - 1].strip() != "":
                block_lines = [""] + block_lines
            insertions.append((insert_at, block_lines))
            stats["blocks_written"] += 1

            # aliases backfill for read items missing them
            if tkind == "read" and info["ids"]:
                has_aliases = any(ALIASES_LINE.match(x) for x in lines[start + 1:close])
                if not has_aliases:
                    arr = ", ".join('"%s"' % i for i in info["ids"])
                    name_idx = None
                    for j in range(start + 1, close):
                        if NAME_LINE.match(lines[j]):
                            name_idx = j
                            break
                    if name_idx is None:
                        print("!! %s:%s has no name line for aliases insert" % (zone, key))
                        return 2
                    insertions.append((name_idx + 1,
                                       ["      aliases = [%s]" % arr]))
                    stats["alias_lines"] += 1
                else:
                    # 已存在时必须已覆盖 LPC id 表（只增不改，缺项即中止）
                    for want in info["ids"]:
                        if ('"%s"' % want) not in body:
                            print("!! %s:%s aliases missing %r; refusing to modify"
                                  % (zone, key, want))
                            return 2

        if not insertions:
            continue

        new_lines = list(lines)
        for at, block_lines in sorted(insertions, key=lambda x: -x[0]):
            for line_text in reversed(block_lines):
                new_lines.insert(at, line_text)
        new = "\n".join(new_lines)

        # gate: no new validation issues (line numbers normalized)
        if _vucl is not None:
            regressions = sorted(
                _norm_issues(_vucl._run_checks(new.encode("utf-8")))
                - _norm_issues(_vucl._run_checks(orig.encode("utf-8")))
            )
            if regressions:
                print("  !! %s self-gate blocked: %s" % (fn, regressions[:3]))
                return 2

        ok, why = _is_insertion_only(orig, new)
        if not ok:
            print("  !! %s is not insertion-only (%s) -- aborting" % (fn, why))
            return 2

        delta = len(new.split("\n")) - len(orig.split("\n"))
        stats["files"] += 1
        stats["inserted_lines"] += delta
        planned.append((path, new))
        print("  %-18s +%-4d lines" % (fn, delta))

    import json
    print(json.dumps(stats, ensure_ascii=False))

    if not args.apply:
        print("dry-run only; re-run with --apply to write")
        return 0
    if not planned:
        print("nothing to write")
        return 0

    # Phase 2: backup BEFORE the first write.
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = os.path.join(TMP, "backup-%s" % stamp)
    os.makedirs(backup, exist_ok=True)
    for path, _ in planned:
        rel = os.path.relpath(path, WORLD)
        dst = os.path.join(backup, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)
    print("backed up %d files to %s" % (len(planned), backup))

    for path, new in planned:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    print("wrote %d files (+%d lines)" % (len(planned), stats["inserted_lines"]))
    return 0


def _norm_issues(issues):
    return {(n, re.sub(r"line \d+", "line N", m or "")) for n, m in issues}


def _is_insertion_only(orig_text, new_text):
    a = orig_text.split("\n")
    b = new_text.split("\n")
    if len(b) <= len(a):
        return False, "line count did not grow"
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, _i2, _j1, _j2 in sm.get_opcodes():
        if tag in ("delete", "replace"):
            return False, "%s at orig line %d" % (tag, i1 + 1)
    return True, ""


if __name__ == "__main__":
    sys.exit(main())
