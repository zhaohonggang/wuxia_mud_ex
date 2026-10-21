# -*- coding: utf-8 -*-
"""
backfill_r7b_item_meta.py — R7b 后半段：给 R7/R7a/R7b 动过的 374 个 items 块补 `meta`

为什么还需要这一步
------------------
R7/R7a 把 571 个被误分类成 `characters` 的物品块搬成了 `items`，R7b 又给其中
374 个补了 `verbs`。但 `meta`（value / weight / unit / material / damage /
skill_type / armor / food / book）一直是空的 —— 后果直接可见：买卖无价、武器无伤、
食物不可食、`unit` 缺失。

为什么不在转换器里修
--------------------
已经定位到根因就在 `lpc_converter.ex` 的 `build_item_meta/2`（L3314）：

    Enum.each([:value, :weight, :unit, :material], fn key ->
      if val = Map.get(sets, key), do: meta = Map.put(meta, key, val)
    end)

这里用**原子**:value/:weight/:unit/:material 去查表，而 `sets` 的键是
`parse_set_calls/1` 从正则捕获组拿到的**字符串**（实测：
`%{"unit" => {:string, "件"}, "value" => {:int, 100}}`）→ `Map.get(sets, :unit)`
恒为 nil → **value/weight/unit/material 从未被任何转换器产物写过**。
（同函数其余键 "damage"/"skill_type"/"armor"/... 用的都是字符串，所以那些能出来。）

按用户的既定规则**不改转换器**，所以沿用项目里既有的补偿工具
`scripts/item_meta_backfill.py` + `scripts/lpc_item.py`（那套提取规则本来就是
为「补转换器漏掉的 set_weight/init_*/base_*/food_supply」而写的，不是新规则）。

实测 `item_meta_backfill.py --dry-run` 在**当前**数据上会填 **374** 个块，
与 `tmp/r7b_targets.json` 逐条相同（已断言）。但它本身没有门禁、没有备份
（docstring 里承诺的「两阶段 + 备份」在代码里并未实现），所以本脚本：

  1. **只面向这 374 个目标**（不是「全库所有缺 meta 的块」）—— 范围可审计；
  2. 复用 `lpc_item.extract` + `item_meta_backfill.meta_lines` 的产出，
     但插入改成**对全文的偏移替换**（按 start 降序一次套完），与
     reclassify / dedup / backfill_item_verbs_meta 同一套编辑模型；
  3. 补上 G1-G10 门禁 + `--apply` 前自动备份，任一不过不动盘。

安全
----
  * 所有编辑都是 (start, end, rep) 偏移替换，按 start 降序一次套完，行号永不失效。
  * 门禁任一不过就中止，一个字都不落盘（--apply 也如此）。
  * --apply 前先把受影响文件备份到 tmp/backup-meta-<时间戳>/。
  * 幂等：apply 后再跑一次 dry-run 应报 0 处待改（G10）。

用法
----
    python scripts/backfill_r7b_item_meta.py             # dry-run + 门禁
    python scripts/backfill_r7b_item_meta.py --apply     # 备份后写盘
"""

import collections
import io
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reclassify_npc_item_blocks as R      # noqa: E402  （块扫描/括号/编辑/内存 validate_ucl）
import dedup_character_item_blocks as D     # noqa: E402  （RE_KEY_LINE，顶层键正则）
import item_meta_backfill as M              # noqa: E402  （lpc_item 提取 + meta_lines 排版）
import lpc_item                             # noqa: E402
import validate_ucl as V                    # noqa: E402

ROOT = R.ROOT
ZONES = R.ZONES
TARGETS_JSON = os.path.join(ROOT, "tmp", "r7b_targets.json")

# 目标文件用 basename（tmp/r7b_targets.json），脚本内部用 ZONES 的全相对路径
ZONE_BY_BASE = {os.path.basename(z).replace("\\", "/"): z for z in ZONES}

# 本脚本允许写入的 meta 子键（= item_meta_backfill.meta_lines 能产出的全部键）
META_KEYS = ("damage", "skill_type", "value", "weight", "unit", "material",
             "armor", "armor_type", "food", "book")


class UnknownShape(R.UnknownShape):
    pass


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------

def load_json(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return json.load(f)


def read_text(path):
    """LPC 源：先按 UTF-8，失败再按 GBK（与 lpc_item 的 utf-8 口径兼容）。"""
    with io.open(path, "rb") as f:
        raw = f.read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("gbk", "replace")


# ---------------------------------------------------------------------------
# 计划
# ---------------------------------------------------------------------------

def locate_block(text, bid):
    """返回 (open_idx, close_idx) —— `items "<bid>" {` 的外层括号对。"""
    for m in R.RE_ITEMS_HEADER.finditer(text):
        if m.group(2) != bid:
            continue
        op = text.index("{", m.end() - 1)
        cl = R.match_brace(text, op)
        if cl < 0:
            raise UnknownShape("unterminated items %r" % bid)
        return op, cl
    raise UnknownShape("no items %r block" % bid)


def source_of(text, open_idx, bid):
    """块上方 5 行内最近的 `# Generated from <path> by LPCConverter`。

    与 item_meta_backfill 同一口径（它只回看 5 行），但用全文偏移实现。
    """
    ls = text.rfind("\n", 0, open_idx) + 1
    for _ in range(5):
        m = re.match(r'^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$',
                     text[ls:text.find("\n", ls)])
        if m:
            return m.group(1)
        if ls == 0:
            break
        ls = text.rfind("\n", 0, ls - 1) + 1
    raise UnknownShape("items %r: no `# Generated from` header within 5 lines" % bid)


def meta_fragment(src_path, indent):
    """抽取 + 产出待插入的 meta 文本（首元素是空行，见 meta_lines）。"""
    if not os.path.isfile(src_path):
        raise UnknownShape("source not found: %s" % src_path)
    text = read_text(src_path)
    d = lpc_item.extract(src_path)
    good, why = lpc_item.is_item_like(
        d, lpc_item.strip_comments(text))
    if not good:
        raise UnknownShape("%s: not item-like (%s)" % (src_path, why))
    lines = M.meta_lines(d, indent)
    if not lines:
        raise UnknownShape("%s: no meta fields extracted" % src_path)
    return "\n".join(lines) + "\n", d


def meta_top_keys(frag):
    """meta = { ... } 直属键（depth==1）。

    book = { ... } 里的子键（depth>=2，如 difficulty/exp_required/skill）
    不纳入，避免被误判为顶层 meta 键而触发 G2/G8b 的 unknown-keys 校验。

    与 backfill_item_verbs_meta.fragment_keys 同一套 {/} 深度计数，但
    捕获阈值改为 depth==1（因为 frag 的首行本身就是 `meta = {`）。
    """
    out = []
    depth = 0
    for line in frag.split("\n"):
        m = D.RE_KEY_LINE.match(line)
        if m and depth == 1:
            out.append(m.group(2))
        depth += line.count("{") - line.count("}")
    if depth != 0:
        raise UnknownShape("meta fragment braces unbalanced (depth %d): %r"
                           % (depth, frag[:60]))
    return out


def build_plan(texts, targets, strict=True):
    plan = []          # (zone_full_path, id, start, end, frag, fields)
    notes = collections.Counter()

    for t in targets:
        zone = ZONE_BY_BASE[t["zone"]]
        bid = t["id"]
        text = texts[zone]

        op, cl = locate_block(text, bid)
        body = text[op + 1:cl]
        ls = text.rfind("\n", 0, op) + 1
        m = re.match(r'^([ \t]*)', text[ls:text.find("\n", ls)])
        indent = len(m.group(1)) + 2

        # G2 前置：目标块不得已带 meta
        if re.search(r'^[ \t]*meta[ \t]*=', body, re.M):
            if not strict:
                notes["already done"] += 1
                continue
            raise UnknownShape("%s: items %r already has meta" % (zone, bid))

        src = source_of(text, op, bid)
        local = src.replace("/", os.sep)
        frag, d = meta_fragment(local, indent)

        got = set(meta_top_keys(frag))
        unknown = got - set(META_KEYS)
        if unknown:
            raise UnknownShape("%s/%s: unexpected meta keys %r" % (zone, bid, sorted(unknown)))
        if len(re.findall(r'^[ \t]*meta[ \t]*=', frag, re.M)) != 1:
            raise UnknownShape("%s/%s: fragment must contain exactly one meta header"
                               % (zone, bid))
        notes["keys: " + ",".join(sorted(got))] += 1

        # 插入点：块闭合 `}` 行的行首（frag 自带前导空行）
        line_start = text.rfind("\n", 0, cl) + 1
        if text[line_start:cl + 1].strip() != "}":
            raise UnknownShape("%s/%s: close brace not alone on its line"
                               % (zone, bid))
        plan.append((zone, bid, line_start, line_start, frag,
                     {k: d.get(k) for k in sorted(got)}))

    return plan, notes


def make_edits(plan):
    edits = collections.defaultdict(list)
    for zone, bid, s, e, frag, _f in plan:
        edits[zone].append((s, e, frag))
    for zone, lst in edits.items():
        lst.sort(key=lambda t: t[0])
        for (a, _ea, _ra), (b, _eb, _rb) in zip(lst, lst[1:]):
            if a >= b:
                raise UnknownShape("%s: overlapping inserts at %d/%d" % (zone, a, b))
    return edits


# ---------------------------------------------------------------------------
# 门禁
# ---------------------------------------------------------------------------

def normalize_issue(text):
    text = re.sub(r':\d+:', ':<n>:', text)
    text = re.sub(r'\bat line \d+\b', 'at line <n>', text)
    text = re.sub(r'\(line \d+\)', '(line <n>)', text)
    text = re.sub(r'[A-Za-z]:[\\/][^\s:,]*', '<path>', text)
    return text


def snapshot(texts):
    snap = {}
    for zone in ZONES:
        rel = zone.replace("\\", "/")
        snap[rel] = sorted(normalize_issue("%s: %s" % (name, detail))
                           for name, detail in
                           V._run_checks(texts[zone].encode("utf-8")))
    return snap


def gate(plan, texts, results, targets):
    fails, warns = [], []
    by_zone = collections.defaultdict(list)
    for zone, bid, _s, _e, _f, _d in plan:
        by_zone[zone].append(bid)

    # G1：目标集合必须与 r7b_targets.json 完全一致（一个不多、一个不漏）
    want = {(ZONE_BY_BASE[t["zone"]], t["id"]) for t in targets}
    got = {(z, b) for z, b, _s, _e, _f, _d in plan}
    if got != want:
        fails.append("G1 plan covers %d targets, expected %d (missing %r, extra %r)"
                     % (len(got), len(want), sorted(want - got)[:5], sorted(got - want)[:5]))

    for zone in ZONES:
        rel = zone.replace("\\", "/")
        before, after = texts[zone], results["texts"][zone]

        # G6：块计数一个都不能少/多
        cnt = lambda t, pat: len(re.findall(pat, t, re.M))
        for kind in ("items", "characters", "rooms"):
            o = cnt(before, r'^[ \t]*%s[ \t]+"[^"]+"[ \t]*\{' % kind)
            n = cnt(after, r'^[ \t]*%s[ \t]+"[^"]+"[ \t]*\{' % kind)
            if o != n:
                fails.append("G6 %s %s blocks: before %d, after %d" % (rel, kind, o, n))

        for bid in by_zone.get(zone, ()):
            entry = [p for p in plan if p[0] == zone and p[1] == bid][0]
            _z, _b, _s, _e, frag, fields = entry

            op_b, cl_b = locate_block(before, bid)
            op_a, cl_a = locate_block(after, bid)
            body_b = before[op_b + 1:cl_b]
            body_a = after[op_a + 1:cl_a]

            # G4：改后块里只能有一个 meta，且位置正确
            n_meta = len(re.findall(r'^[ \t]*meta[ \t]*=', body_a, re.M))
            if n_meta != 1:
                fails.append("G4 %s %r: %d meta keys after apply" % (rel, bid, n_meta))

            # G9：不得出现重复顶层键
            keys = re.findall(r'^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=', body_a, re.M)
            for k, c in collections.Counter(keys).items():
                if c > 1:
                    fails.append("G9 %s %r: duplicate key %r x%d" % (rel, bid, k, c))

            # G7：原有键与它们的值逐字保留
            old_keys = re.findall(r'^([ \t]*)([A-Za-z_][A-Za-z0-9_]*)[ \t]*=', body_b, re.M)
            for ind, k in old_keys:
                # 取 before 里该键那一行（值可能跨行，这里只比键所在行的存在性）
                if not re.search(r'^%s%s[ \t]*=' % (re.escape(ind), re.escape(k)), body_a, re.M):
                    fails.append("G7 %s %r: key %r lost" % (rel, bid, k))

            # G8：插入片段逐字出现在块体里
            if frag not in body_a:
                fails.append("G8 %s %r: meta fragment not present verbatim" % (rel, bid))

            # G8b：meta 里的键集合 == 本次抽取到的键集合
            want_keys = sorted(set(meta_top_keys(frag)))
            mstart = body_a.find("meta = {")
            mend = R.match_brace(body_a, body_a.index("{", mstart))
            got_keys = sorted(set(meta_top_keys(body_a[mstart:mend + 1])))
            if got_keys != want_keys:
                fails.append("G8 %s %r: meta keys %r, expected %r"
                             % (rel, bid, got_keys, want_keys))
            # G8c：非空字段数一致
            if not fields:
                fails.append("G8 %s %r: no fields extracted" % (rel, bid))

    # G5：validate_ucl 完整 issue 集合不新增
    snap_b, snap_a = snapshot(texts), snapshot(results["texts"])
    for rel in sorted(snap_a):
        new = [i for i in snap_a[rel] if i not in snap_b.get(rel, [])]
        gone = [i for i in snap_b.get(rel, []) if i not in snap_a[rel]]
        if new:
            fails.append("G5 %s: %d new validate_ucl issue(s): %r"
                         % (rel, len(new), new[:3]))
        if gone:
            warns.append("G5 %s: %d issue(s) disappeared: %r" % (rel, len(gone), gone[:3]))

    return fails, warns


# ---------------------------------------------------------------------------
# 运行
# ---------------------------------------------------------------------------

def run(texts, targets, strict=True):
    plan, notes = build_plan(texts, targets, strict=strict)
    edits = make_edits(plan)

    print("plan: %d insertions across %d zone(s)" %
          (len(plan), len({p[0] for p in plan})))
    for k in sorted(notes):
        print("  %-58s %d" % (k, notes[k]))

    if not plan:
        print("gate: nothing to do")
        return plan, None

    results = {"texts": {z: R.apply_edits(texts[z], edits.get(z, [])) for z in ZONES}}

    fails, warns = gate(plan, texts, results, targets)
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

    targets = load_json(TARGETS_JSON)
    texts = R.read_all_zones()

    print("targets: %d (from %s)" % (len(targets), os.path.basename(TARGETS_JSON)))
    out = run(texts, targets, strict=True)
    if out is None:
        return 1
    plan, results = out

    again, _ = run(results["texts"], targets, strict=False)
    if again:
        print("G10 FAIL: re-run on result still has %d insertions" % len(again))
        return 1
    print("G10 idempotent: re-run on result has 0 insertions")

    if not apply_it:
        print("\n(dry-run — pass --apply to write)")
        return 0

    stamp = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-meta-%s" % stamp)
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
