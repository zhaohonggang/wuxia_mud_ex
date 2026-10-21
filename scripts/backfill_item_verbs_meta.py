# -*- coding: utf-8 -*-
"""
backfill_item_verbs_meta.py — R7b / D10 收尾

给 R7 改名/合并后仍然「没有 verbs」的 374 个 items 块补上转换器自己会生成的
`verbs = [...]`（91 个块还带 `messages = {...}`），让它们成为可 get/drop 的真物品。

为什么必须走转换器
------------------
R7/R7a 只搬了块（characters -> items），`verbs` 是 `infer_verbs/2` 按
inherit + set(wield_msg/wear_msg) 推出来的，`meta` 是 `build_item_meta/2`
从 create 里的 set(...) 收的。在 Python 里重抄一套规则 = 第二份真相，必然漂移。

所以本脚本**不自己推规则**：
  1. 先把 mud 源码树的 .c/.h 镜像到 tmp/conv_sandbox，路径里所有 `npc`
     目录组件改名 `npc_`（只为绕开 determine_object_type 里
     `npc_subdir?` 早于 `is_item_inherit?` 的排序 bug；目录层次不变，
     相对 inherit 解析不受影响）。
  2. 在容器里跑 tmp/probe_conv_fragments.exs，对每个目标调
     LPCConverter.convert_file/2，产出 tmp/r7b_raw.json。
  3. 本脚本从那份 JSON 里**逐字**抽出转换器块体的 `verbs = [` 起往后那一截，
     插回 data/world 的 items 块末尾顶层键之后。

不改转换器（用户明确要求）。

数据口径
--------
374 个目标 = tmp/r7b_targets.json（由 items 块缺 verbs 反查得到）。
其中：
  * 363 个转换器正常产出 items 块（带 verbs，91 个还带 messages）；
  * 11 个（beijing 的 dan*）源文件 `inherit COMBINED_ITEM;` 整行被注释掉，
    转换器判 :generic、产出空串。这 11 个已逐个人工核过：无 inherit、
    无 wield_msg/wear_msg —— 正好落在 infer_verbs 的兜底分支
    `base = ["get","drop"]`。脚本只对这 11 个用兜底值，且用
    G3 强制校验「源里确实没有 inherit / wield_msg / wear_msg」。
  * 全 374 个目标当前都只有 name/aliases/description(+init)，没有任何一个
    已带 verbs/meta/messages（G2 前置校验），因此不存在键冲突。

格式
----
插入片段**逐字采用转换器的排版**（verbs 缩进 2 空格）。data/world 里现有
1605 个带 verbs 的 items 块中 1588 个就是这个形状（`# Source:` 分支的产物），
保持一致。

安全
----
  - 所有编辑都是对全文的偏移区间替换 (start, end, rep)，按 start 降序一次套完。
  - 门禁 G1-G10 任一不过就中止，一个字都不落盘（--apply 也如此）。
  - --apply 前先把受影响文件备份到 tmp/backup-verbs-<时间戳>/。
  - 幂等：apply 后再跑一次 dry-run 应报 0 目标（G10）。

用法
----
    python scripts/backfill_item_verbs_meta.py            # dry-run + 门禁
    python scripts/backfill_item_verbs_meta.py --apply    # 备份后写盘
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
import reclassify_npc_item_blocks as R      # noqa: E402
import dedup_character_item_blocks as D     # noqa: E402  (top_keys / key_value_span)
import validate_ucl as V                    # noqa: E402

ROOT = R.ROOT
ZONES = R.ZONES
TARGETS_JSON = os.path.join(ROOT, "tmp", "r7b_targets.json")
RAW_JSON = os.path.join(ROOT, "tmp", "r7b_raw.json")
SANDBOX = os.path.join(ROOT, "tmp", "conv_sandbox")

RE_KEY_LINE = D.RE_KEY_LINE
# 允许本脚本写入的键（转换器产物 + 兜底 verbs）
FRAGMENT_KEYS = ("verbs", "meta", "messages")

# 目标文件用 basename（tmp/r7b_targets.json），脚本内部用 ZONES 的全相对路径
ZONE_BY_BASE = {os.path.basename(z).replace("\\", "/"): z for z in ZONES}


class UnknownShape(R.UnknownShape):
    pass


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------

def load_json(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return json.load(f)


def load_targets():
    return load_json(TARGETS_JSON)


def load_raw():
    return {(r["zone"], r["id"]): r for r in load_json(RAW_JSON)}


# ---------------------------------------------------------------------------
# 从转换器产出里抽片段
# ---------------------------------------------------------------------------

def conv_block_body(ucl, bid):
    """转换器产出的整文件文本里，定位 `items "<bid>" {` 并返回块体（去掉外层括号）。"""
    for m in R.RE_ITEMS_HEADER.finditer(ucl):
        if m.group(2) != bid:
            continue
        op = ucl.index("{", m.end() - 1)
        cl = R.match_brace(ucl, op)
        if cl < 0:
            raise UnknownShape("converter output: unterminated items %r" % bid)
        return ucl[op + 1:cl]
    raise UnknownShape("converter output: no items %r block" % bid)


def extract_fragment(ucl, bid):
    """从转换器块体里逐字取 `verbs = [` 起的那一截（到 `]`/`}` 收尾，含换行）。"""
    body = conv_block_body(ucl, bid)
    vi = body.find("\n  verbs")
    if vi < 0:
        raise UnknownShape("converter output: %s/%s has no verbs" % (bid, bid))
    frag = body[vi + 1:].rstrip()
    if not re.match(r'^[ \t]*verbs[ \t]*=[ \t]*\[', frag):
        raise UnknownShape("converter output: %s/%s verbs fragment looks wrong: %r"
                           % (bid, bid, frag[:40]))
    return frag + "\n"


def fallback_fragment():
    """转换器兜底分支的逐字排版：base = ["get","drop"]。"""
    return '  verbs = [\n    "get",\n    "drop"\n  ]\n'


def translate_placeholders(frag):
    """把 `messages` 里的 LPC 占位符 $N/$n 换成转换器别处统一使用的 {npc}/{name}。

    转换器自己在三处（lpc_converter.ex 1347 / 1416 / 1772）都做了这两个替换，
    只有 `generate_item_ucl` 的 messages 分支漏了（直接 escape_set_string 输出）。
    这里补的是**同一套替换**，不是新规则：
      * 运行时 `wield_command.equip_feedback/4` 只替换 `{name}`、`{npc}` 留给
        VisionView 按接收者渲染 —— raw `$N` 会原样广播给玩家；
      * data/world 现有 250 个带 messages 的 items 块里 249 个用的就是
        `{npc}`/`{name}`（只有 wudu.ucl 的 ganggou 一个漏网）。
    `verbs` 数组里只有 get/drop/wield/... 裸词，不可能含 `$`，所以只动
    `messages` 及之后的部分。
    """
    i = frag.find("\n  messages")
    if i < 0:
        return frag
    head, tail = frag[:i], frag[i:]
    if "$N" in head or "$n" in head:
        raise UnknownShape("unexpected $ placeholder outside messages: %r" % head[-80:])
    return head + tail.replace("$N", "{npc}").replace("$n", "{name}")


def fragment_keys(frag):
    """片段的**顶层**键名（verbs / meta / messages）。

    不能用 re.findall —— `messages = { wield = ..., unwield = ... }` 里的
    wield/unwield 也会匹配 `^  key =`。按 `{`/`}` 深度只取 0 层的。
    """
    out = []
    depth = 0
    for line in frag.split("\n"):
        m = RE_KEY_LINE.match(line)
        if m and depth == 0:
            out.append(m.group(2))
        depth += line.count("{") - line.count("}")
    if depth != 0:
        raise UnknownShape("fragment braces unbalanced (depth %d): %r"
                           % (depth, frag[:60]))
    return out


# ---------------------------------------------------------------------------
# 兜底分支的前置证明：源里确实没有 inherit / wield_msg / wear_msg
# ---------------------------------------------------------------------------

def sandbox_source_text(rel):
    path = os.path.join(SANDBOX, rel)
    with io.open(path, "rb") as f:
        raw = f.read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("gbk", "replace")


def strip_lpc_comments(text):
    return re.sub(r'//[^\n]*', '', text)


# ---------------------------------------------------------------------------
# 计划
# ---------------------------------------------------------------------------

def build_plan(texts, targets, raw, strict=True):
    """strict=False 时（G10 幂等重跑）把「已经带 verbs/meta/messages」的块
    记为 already-done 跳过，而不是抛异常 —— 这样才能报出「0 处待改」。"""
    plan = []          # (zone_full_path, id, insert_offset, fragment, source)
    notes = collections.Counter()

    for t in targets:
        zone = ZONE_BY_BASE[t["zone"]]
        bid = t["id"]
        text = texts[zone]

        m = None
        for cand in R.RE_ITEMS_HEADER.finditer(text):
            if cand.group(2) == bid:
                m = cand
                break
        if m is None:
            raise UnknownShape("%s: no items %r block to backfill" % (zone, bid))

        op = text.index("{", m.end() - 1)
        cl = R.match_brace(text, op)
        if cl < 0:
            raise UnknownShape("%s: unterminated items %r" % (zone, bid))
        body = text[op + 1:cl]
        keys = D.top_keys(body)

        # G2 前置：目标块不得已带本脚本要写的键
        present = [k for k in FRAGMENT_KEYS if k in keys]
        if present:
            if not strict:
                notes["already done"] += 1
                continue
            raise UnknownShape("%s: items %r already has %r" % (zone, bid, present))

        rec = raw.get((t["zone"], bid))
        conv = (rec or {}).get("ucl") or ""
        if conv.strip():
            frag = translate_placeholders(extract_fragment(conv, bid))
            source = "converter"
        else:
            # 兜底：只接受「转换器确实产出空 + 源无 inherit/wield_msg/wear_msg」
            src = strip_lpc_comments(sandbox_source_text(t["rel"]))
            inh = re.findall(r'^\s*inherit\s+[^;]*;', src, re.M)
            wield = re.search(r'set\("wield_msg"', src)
            wear = re.search(r'set\("wear_msg"', src)
            if inh or wield or wear:
                raise UnknownShape(
                    "%s/%s: converter produced nothing but source has "
                    "inherit=%r wield_msg=%r wear_msg=%r — refusing fallback"
                    % (zone, bid, inh, bool(wield), bool(wear)))
            frag = fallback_fragment()
            source = "fallback"
            notes["fallback verbs"] += 1

        fkeys = set(fragment_keys(frag))
        if not fkeys or not fkeys <= set(FRAGMENT_KEYS):
            raise UnknownShape("%s/%s: fragment keys %r not allowed"
                               % (zone, bid, sorted(fkeys)))
        # G9：插入后不得残留 raw LPC 占位符（运行时只认 {npc}/{name}）
        if "$N" in frag or "$n" in frag:
            raise UnknownShape("%s/%s: fragment still has raw $ placeholder"
                               % (zone, bid))
        notes["fragment: " + ",".join(sorted(fkeys))] += 1
        notes["source: " + source] += 1

        # 插入点：最后一个顶层键所在行的行尾之后
        last_key = keys[-1]
        s, e = D.key_value_span(body, last_key)
        nl = body.find("\n", e)
        ins = (len(body) if nl < 0 else nl + 1) + op + 1
        plan.append((zone, bid, ins, frag, source))

    return plan, notes


def make_edits(plan):
    """-> {zone: [(s,e,rep)]}；每处都是纯插入 (ins, ins, frag)。"""
    edits = collections.defaultdict(list)
    for zone, bid, ins, frag, _src in plan:
        edits[zone].append((ins, ins, frag))

    for zone, lst in edits.items():
        lst.sort(key=lambda t: t[0])
        for (a, _ea, _ra), (b, _eb, _rb) in zip(lst, lst[1:]):
            if a >= b:
                raise UnknownShape("%s: overlapping inserts at %d/%d" % (zone, a, b))
    return edits


# ---------------------------------------------------------------------------
# 门禁
# ---------------------------------------------------------------------------

def snapshot(texts):
    """在内存里对每个区跑 validate_ucl，返回 {rel: [归一化 issue]}。

    与 R.validate_ucl_snapshot 的区别只在归一化多做了 `(line N)` → `(line <n>)`
    （见 G4b 注释）。
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
    text = re.sub(r'\(line \d+\)', '(line <n>)', text)
    text = re.sub(r'[A-Za-z]:[\\/][^\s:,]*', '<path>', text)
    return text


def gate(plan, texts, results, targets, raw):
    fails = []
    warns = []

    by_zone = collections.defaultdict(list)
    for zone, bid, _i, _f, _s in plan:
        by_zone[zone].append(bid)
    for zone in ZONES:
        rel = zone.replace("\\", "/")
        before, after = texts[zone], results["texts"][zone]

        # G5 块计数：一个块都不能少/多
        cnt = lambda t, pat: len(re.findall(pat, t, re.M))
        for kind in ("items", "characters", "rooms"):
            o = cnt(before, r'^[ \t]*%s[ \t]+"[^"]+"[ \t]*\{' % kind)
            n = cnt(after, r'^[ \t]*%s[ \t]+"[^"]+"[ \t]*\{' % kind)
            if o != n:
                fails.append("G5 %s %s blocks: before %d, after %d" % (rel, kind, o, n))

        expect_ids = sorted(by_zone.get(zone, ()))
        got_ids = sorted(m.group(2) for m in R.RE_ITEMS_HEADER.finditer(after))
        for bid in expect_ids:
            if bid not in got_ids:
                fails.append("G5 %s: items %r disappeared" % (rel, bid))

        # G4 validate_ucl：放到循环外做全量比对（见 G4b）

        # G6 逐块核对：verbs / messages 都落进去了，且与计划一致
        for bid in expect_ids:
            entry = [p for p in plan if p[0] == zone and p[1] == bid][0]
            _z, _b, _ins, frag, _src = entry

            def find_block(text, bid):
                for cand in R.RE_ITEMS_HEADER.finditer(text):
                    if cand.group(2) == bid:
                        op = text.index("{", cand.end() - 1)
                        cl = R.match_brace(text, op)
                        if cl < 0:
                            raise UnknownShape("%s: unterminated items %r"
                                               % (rel, bid))
                        return text[op + 1:cl]
                return None

            body_after = find_block(after, bid)
            body_before = find_block(before, bid)
            if body_after is None or body_before is None:
                fails.append("G6 %s %r: block missing after apply" % (rel, bid))
                continue
            keys_after = D.top_keys(body_after)
            keys_before = D.top_keys(body_before)

            # G8 键集合 = 原来的键 + 片段里的键（保序去重）
            want = list(keys_before)
            for k in fragment_keys(frag):
                if k not in want:
                    want.append(k)
            if keys_after != want:
                fails.append("G6 %s %r: keys %r, expected %r"
                             % (rel, bid, keys_after, want))
            # G8b：插入片段逐字出现在块体里
            if frag not in body_after:
                fails.append("G8 %s %r: fragment not present verbatim" % (rel, bid))

    # G6 计数
    if len(plan) != len(targets):
        fails.append("G6 plan covers %d targets, expected %d" % (len(plan), len(targets)))

    # G4b validate_ucl 全量比对（归一化后不新增）
    #
    # 归一化比 R.normalize_issue 多一条 `(line N)`：validate_ucl 的语法类 issue
    # 把行号写成 `... (line 4069)`，而本次插入会让同文件后续行号整体下移，
    # 不归一行号就会把「只是挪了位置的老问题」误判成新增。
    snap_before = snapshot(texts)
    snap_after = snapshot(results["texts"])
    for rel in sorted(snap_after):
        new = [i for i in snap_after[rel] if i not in snap_before.get(rel, [])]
        if new:
            fails.append("G4 %s: %d new validate_ucl issue(s): %r"
                         % (rel, len(new), new[:3]))
        gone = [i for i in snap_before.get(rel, []) if i not in snap_after[rel]]
        if gone:
            warns.append("G4 %s: %d issue(s) disappeared: %r"
                         % (rel, len(gone), gone[:3]))

    return fails, warns

# ---------------------------------------------------------------------------
# 运行
# ---------------------------------------------------------------------------

def run(texts, targets, raw, strict=True):
    plan, notes = build_plan(texts, targets, raw, strict=strict)
    edits = make_edits(plan)

    print("plan: %d insertions across %d zone(s)" %
          (len(plan), len({p[0] for p in plan})))
    for k in sorted(notes):
        print("  %-34s %d" % (k, notes[k]))

    if not plan:
        print("gate: nothing to do")
        return plan, None

    results = {
        "texts": {},
        "edits": edits,
    }
    for zone in ZONES:
        before = texts[zone]
        after = R.apply_edits(before, edits.get(zone, []))
        if before != after:
            results["texts"][zone] = after
        else:
            results["texts"][zone] = before

    fails, warns = gate(plan, texts, results, targets, raw)
    for w in warns:
        print("  WARN %s" % w)
    if fails:
        print("\nGATE FAILED (%d) — nothing written:" % len(fails))
        for f in fails[:40]:
            print("  " + f)
        return None

    print("\ngate: all checks passed")
    return plan, results


def main(argv):
    apply_it = "--apply" in argv

    targets = load_targets()
    raw = load_raw()
    texts = R.read_all_zones()

    print("targets: %d (from %s)" % (len(targets), os.path.basename(TARGETS_JSON)))
    out = run(texts, targets, raw, strict=True)
    if out is None:
        return 1
    plan, results = out

    # G10 幂等：对改动后的文本重跑，必须 0 处待改
    again_plan, _again = run(results["texts"], targets, raw, strict=False)
    if again_plan:
        print("G10 FAIL: re-run on result still has %d insertions" % len(again_plan))
        return 1
    print("G10 idempotent: re-run on result has 0 insertions")

    if not apply_it:
        print("\n(dry-run — pass --apply to write)")
        return 0

    stamp = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-verbs-%s" % stamp)
    os.makedirs(bdir)
    touched = sorted({p[0] for p in plan})
    for zone in touched:
        shutil.copy2(os.path.join(ROOT, zone),
                     os.path.join(bdir, os.path.basename(zone)))
    print("\nbackup: %s (%d files)" % (bdir, len(touched)))

    for zone in touched:
        R.write(zone, results["texts"][zone])
    print("written: %d file(s)" % len(touched))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
