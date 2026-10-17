#!/usr/bin/env python
"""B10: backfill LPC `set("armor_prop/<sub>"/"weapon_prop/<sub>", N)` slash keys
into `items` blocks' `meta` block, as nested maps.

背景（2026-10-16 实测，见 scripts/survey_b10_props.py → tmp/b10_survey.json）
--------------------------------------------------------------------------
转换器只读**整体式** `set("armor_prop", ([...]))`（lpc_converter.ex L3327-3328），
而 LPC 语料全部使用**斜杠路径式** `set("armor_prop/armor", 1)`（全库 646+17 处），
整体式 0 处 → 这些子键**从未被转换**，.ucl 里只有 liuxi.ucl 3 个手写测试块。

子键三分（648 个源文件持有）：
- whitelisted（532 文件 / 126 个 items 块）：armor dodge defense attack
  unarmed_damage —— 已在 `Combat.applies_keys()` 内，写入即经既有链路生效
  （Feature/Equip.wear_state 同语义：LPC feature/equip.c L38-47 穿戴时把
  armor_prop 全部子键累加进 apply 表）。
- non_whitelisted（96 文件 / 28 个 items 块）：personality per armor_vs_force
  warm —— 需先扩 `Combat.applies_keys()`（B10b 代码侧），否则 sanitize_prop
  丢弃。LPC 侧语义：personality=人格魅力（enchased.c 镶嵌属性）、
  per=容貌（attribute.c）、warm=保暖（natured.c 影响 con）、
  armor_vs_force=内力攻击伤害减免（inherit/skill/force.c L79）。
- skill_manual（20 文件 / 5 个 items 块）：finger hand strike cuff claw unarmed
  —— 技能加成，走 Fighter.skills 通道，引擎 v0 不支持 → **本脚本不写**，
  只计数上报（写了也会被 sanitize_prop 丢弃）。

块选择
------
只写 `items` 块（loader 的 parse_item_meta 只从 items 块读 meta）。
`characters` 块里的物品（D10：转换器把 npc/obj 下继承武器/护甲宏的文件误判成
NPC）跳过并计数 —— 与 B3/B5b/B8/B9 一致，见进度文档 R7。

值处理
------
- 跳过 `//` 行注释里的 set()（B9 同款 strip_line_comment）。
- 同一文件同键多处取**首个**激活值（样本已验证同值；B9 同口径）。
- 块内已存在的 `armor_prop = {` / `weapon_prop = {` 子块：**只缺的子键插入**
  （P4 只增不改，不动已有行）；已存在的同名子键跳过。
- 无 prop 键的块：在 meta 块闭合前插入整块
  `<indent+2>armor_prop = {` / `<indent+4>armor = 8` ... / `<indent+2>}`。
  liuxi.ucl 既有手写块即此格式（换行分隔、无逗号，实测可解析）。

安全（同 B8/B9 协议）
--------------------
* dry-run 默认，`--apply` 写盘
* 两阶段：所有区内存算完 + 过门禁（insertion-only + validate_ucl 完整 issue
  集合比对、行号归一化），**全过**才备份、才写盘
* 备份在写盘**之前**
* 幂等：已携带目标子键的块跳过（二次 dry-run 应为 0）
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

WHITELISTED = {"armor", "dodge", "defense", "attack", "unarmed_damage"}
NON_WL = {"personality", "per", "armor_vs_force", "warm"}
# skill_manual（finger/hand/strike/cuff/claw/unarmed）：不在 SUBSETS 内，
# 任何模式下都不写（引擎 v0 不支持，写了会被 sanitize_prop 丢弃）。
SKILL_MANUAL = {"finger", "hand", "strike", "cuff", "claw", "unarmed"}

SUBSETS = {
    "whitelisted": WHITELISTED,
    "non_whitelisted": NON_WL,
    "both": WHITELISTED | NON_WL,
}

GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^(\s*)(items|characters)\s+"([^"]+)"\s*\{\s*$')

# meta = { ... } 行（块嵌套层级决定缩进：顶层 items 2 空格 / 房间内 items 6 空格）
META_OPEN = re.compile(r'^(\s*)meta\s*=\s*\{\s*$')

# set("armor_prop/<sub>", N)（按行去注释后匹配）
SET_RE = re.compile(
    r'set\(\s*"(armor_prop|weapon_prop)/([a-z_0-9]+)"\s*,\s*(-?\d+)\s*\)')


def norm(path):
    return path.replace("\\", "/").lower()


def strip_line_comment(line):
    """去掉 LPC 行内 `//` 注释（保留字符串内 //；简单策略足够）。"""
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "/" and i + 1 < len(line) and line[i + 1] == "/":
                return line[:i]
        i += 1
    return line


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
    """Yield (kind, key, source, open_idx, close_idx).

    Source attribution: block-internal `# LPC: <path>` wins over the nearest
    `# Generated from` header.
    """
    depth = 0
    pending = None
    header = None
    for i, line in enumerate(lines):
        m = GEN.match(line.strip())
        if m and depth == 0:
            header = norm(m.group(1))
        if depth == 0:
            om = OPEN.match(line)
            if om:
                pending = (om.group(2), om.group(3), header, i)
        nxt = depth + skeleton_delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            kind, key, src, start = pending
            resolved = src
            for j in range(start + 1, i):
                lm = LPC.match(lines[j].strip())
                if lm and resolved in (None, header):
                    resolved = norm(lm.group(1))
            yield kind, key, resolved, start, i
            pending = None
        depth = nxt


def find_meta(lines, start, close):
    """Find `meta = { ... }` sub-block inside items block. Returns (open, close)
    or (None, None) if absent."""
    i = start + 1
    while i < close:
        m = META_OPEN.match(lines[i])
        if m:
            indent = len(m.group(1))
            depth = 1
            j = i + 1
            while j < close:
                depth += skeleton_delta(lines[j])
                if depth == 0:
                    return i, j, indent
                j += 1
            return i, j - 1, indent
        i += 1
    return None, None, None


def find_prop_map(lines, meta_open, meta_close, base):
    """Find existing `<base> = { ... }` sub-map inside meta block.
    Returns (open, close) or (None, None)."""
    pat = re.compile(r'^\s*%s\s*=\s*\{\s*$' % re.escape(base))
    i = meta_open + 1
    while i < meta_close:
        if pat.match(lines[i]):
            depth = 1
            j = i + 1
            while j < meta_close:
                depth += skeleton_delta(lines[j])
                if depth == 0:
                    return i, j
                j += 1
            return i, j - 1
        i += 1
    return None, None


def collect_sources():
    """Return dict source_path -> {(base, sub): value}. 每个物理文件一次。"""
    abs_src = {}
    rel_src = {}
    for root, _dirs, files in os.walk(CORPUS):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            rel = os.path.relpath(path, CORPUS)
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    src = fh.read()
            except OSError:
                continue
            vals = {}
            for line in src.split("\n"):
                clean = strip_line_comment(line)
                for m in SET_RE.finditer(clean):
                    base, sub, v = m.group(1), m.group(2), int(m.group(3))
                    vals.setdefault((base, sub), v)  # 同键多处取首个激活值
            if vals:
                abs_src[norm(path)] = vals
                rel_src.setdefault(norm(rel), vals)
    # 合并查找表（abs 优先于 rel）；统计只用 abs_src
    sources = dict(abs_src)
    for k, v in rel_src.items():
        sources.setdefault(k, v)
    return sources, abs_src


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write files (default: dry-run)")
    ap.add_argument("--subsets", choices=sorted(SUBSETS), default="both",
                    help="which subkey groups to write (default: both)")
    args = ap.parse_args()
    want = SUBSETS[args.subsets]

    try:
        import validate_ucl as _vucl
    except Exception:
        _vucl = None

    sources, abs_src = collect_sources()

    # 源文件计数（按分类）
    stat = {}
    skill_hits = {}
    for vals in abs_src.values():
        for (base, sub), _v in vals.items():
            if sub in want:
                stat[sub] = stat.get(sub, 0) + 1
            elif sub in SKILL_MANUAL:
                skill_hits[sub] = skill_hits.get(sub, 0) + 1
    print("source files by written subkey: %s" % stat)
    print("skill_manual skipped (not written): %s" % skill_hits)

    planned = []
    stats = {
        "zones": 0, "blocks_written": 0, "blocks_skipped_idempotent": 0,
        "blocks_no_meta": 0, "sub_inserted": 0, "map_created": 0,
        "blocks_characters_skipped": 0, "inserted_lines": 0,
    }
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            orig = fh.read()
        lines = orig.split("\n")

        # (meta_close or prop_close) -> [lines] 按 base 聚合
        insertions = []  # (insert_idx, [lines])  —— insert_idx 前插入
        for kind, key, src, start, close in iter_blocks(lines):
            if src not in sources:
                continue
            if kind != "items":
                stats["blocks_characters_skipped"] += 1
                continue
            vals = {k: v for k, v in sources[src].items() if k[1] in want}
            if not vals:
                continue
            meta_open, meta_close, m_indent = find_meta(lines, start, close)
            if meta_open is None:
                stats["blocks_no_meta"] += 1
                continue

            wrote_any = False
            for base in ("armor_prop", "weapon_prop"):
                subs = sorted(sub for (b, sub) in vals if b == base)
                if not subs:
                    continue
                prop_open, prop_close = find_prop_map(lines, meta_open, meta_close, base)
                if prop_open is None:
                    # 整块插入到 meta 闭合前
                    pad = " " * (m_indent + 2)
                    body = ["%s%s = {" % (pad, base)]
                    body += ["%s%s = %d" % (" " * (m_indent + 4), s, vals[(base, s)])
                             for s in subs]
                    body.append("%s}" % pad)
                    insertions.append((meta_close, body))
                    wrote_any = True
                    stats["map_created"] += 1
                    stats["sub_inserted"] += len(subs)
                else:
                    # 并入既有 map：只缺的子键，插到 map 闭合前
                    existing = {}
                    pat = re.compile(r'^\s*([a-z_0-9]+)\s*=\s*-?\d+\s*$')
                    for ln in lines[prop_open + 1:prop_close]:
                        mm = pat.match(ln)
                        if mm:
                            existing[mm.group(1)] = True
                    missing = [s for s in subs if s not in existing]
                    if not missing:
                        continue
                    pad = " " * (m_indent + 4)
                    body = ["%s%s = %d" % (pad, s, vals[(base, s)]) for s in missing]
                    insertions.append((prop_close, body))
                    wrote_any = True
                    stats["sub_inserted"] += len(missing)

            if wrote_any:
                stats["blocks_written"] += 1

        if not insertions:
            continue

        new_lines = list(lines)
        # 同一插入点可能有多组（armor_prop + weapon_prop），合并后倒序插
        by_idx = {}
        for idx, body in insertions:
            by_idx.setdefault(idx, []).extend(body)
        for idx in sorted(by_idx, reverse=True):
            for line_text in reversed(by_idx[idx]):
                new_lines.insert(idx, line_text)
        new = "\n".join(new_lines)

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
        stats["zones"] += 1
        stats["inserted_lines"] += delta
        planned.append((path, new))
        print("  %-18s +%-4d lines" % (fn, delta))

    print(__import__("json").dumps(stats, ensure_ascii=False))

    if not args.apply:
        print("dry-run only; re-run with --apply to write")
        return 0
    if not planned:
        print("nothing to write")
        return 0

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
