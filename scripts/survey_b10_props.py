#!/usr/bin/env python
"""B10 勘查（只读）：统计 LPC `set("armor_prop/<sub>"/"weapon_prop/<sub>")` 斜杠键
在 data/world items 块上的可回填分布。

背景（2026-10-16 实测）：
- 转换器只认整体式 `set("armor_prop", ([...]))` 映射，全库 0 处；
  LPC 实际用斜杠路径式 `set("armor_prop/armor", 1)`，全库 646 处 → **从未被转换**。
- 全库 .ucl 只有 liuxi.ucl 3 个手写 armor_prop 块（b6/D3 测试件）。
- `Item.Meta.sanitize_prop/1` 只放行 Combat.applies_keys() =
  [:attack :defense :damage :unarmed_damage :dodge :parry :armor]，其余子键被丢弃。

本脚本把 646 处按「白名单内 / 白名单外（待决策） / 技能键（manual）」三类清点，
并清点各子键能落到哪些 .ucl items 块（按块归因取源），output tmp/b10_survey.json。
"""
import json
import os
import re
import sys

CORPUS = r"C:\files\git\mud"
WORLD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "data", "world")

# ---- 键分类 ----
# 白名单内（sanitize_prop 放行 → 数据一写即通过既有链路生效）
WHITELISTED = {"armor", "dodge", "defense", "attack", "unarmed_damage"}
# 白名单外、引擎有语义落点或计划点名的（personality/per/armor_vs_force/warm）
NON_WL = {"personality", "per", "armor_vs_force", "warm"}
# 技能类加成（finger/hand/strike/cuff/claw/unarmed）→ Fighter.skills 通道，v0 不支持

SET_RE = re.compile(
    r'set\(\s*"(armor_prop|weapon_prop)/([a-z_0-9]+)"\s*,\s*(-?\d+)\s*\)')

# ---- UCL 块遍历（同 B8/B9 口径：块内首条 `# LPC:` > 最近的 `# Generated from` 头）----
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^(\s*)(items|characters)\s+"([^"]+)"\s*\{\s*$')


def norm(path):
    return path.replace("\\", "/").lower()


def skeleton_delta(line):
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
    """Yield (kind, key, source, indent, open_idx, close_idx)."""
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
                pending = (om.group(2), om.group(3), header, om.group(1), i)
        nxt = depth + skeleton_delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            kind, key, src, _indent, start = pending
            resolved = src
            for j in range(start + 1, i):
                lm = LPC.match(lines[j].strip())
                if lm and resolved in (None, header):
                    resolved = norm(lm.group(1))
            yield kind, key, resolved, start, i
            pending = None
        depth = nxt


def collect_sources():
    """source file -> {subkey: value}（同时索引绝对路径与语料相对路径两种归一化键）。"""
    found = {}
    rels = {}
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
            for m in SET_RE.finditer(src):
                base, sub, v = m.group(1), m.group(2), int(m.group(3))
                vals.setdefault((base, sub), v)  # 同键多处取首个（样本同值）
            if vals:
                found[norm(path)] = vals
                rels.setdefault(norm(rel), vals)
    return found, rels


def main():
    abs_src, rel_src = collect_sources()
    # 一个源可能两种键都出现（abs 优先）；合并成一张查找表。
    # 注意：统计**只基于 abs_src**（每个物理文件一次）；rel_src 仅用于匹配
    # 块内 `# LPC: <corpus-relative>` 注释的查找，**不可计入统计**——
    # 同一文件的 abs/rel 两个键会指向同一份 vals，重复计入会翻倍。
    sources = dict(abs_src)
    for k, v in rel_src.items():
        sources.setdefault(k, v)

    # 源文件按子键统计（同一块同键取首值，样本已验证同值）
    sub_stat = {}  # (base, sub) -> {"files": n}
    for vals in abs_src.values():
        for (base, sub) in vals:
            st = sub_stat.setdefault((base, sub), {"files": 0})
            st["files"] += 1

    def classify(sub):
        if sub in WHITELISTED:
            return "whitelisted"
        if sub in NON_WL:
            return "non_whitelisted"
        return "skill_manual"

    for (base, sub), st in sub_stat.items():
        st["classification"] = classify(sub)

    # 块级清点
    block_stat = {}  # (base, sub) -> {"items_blocks": n, "characters_blocks": n, "no_meta": n}
    blocks_detail = []
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        path = os.path.join(WORLD, fn)
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        for kind, key, src, start, close in iter_blocks(lines):
            if src not in sources:
                continue
            vals = sources[src]
            # 该块含哪些 prop 键
            for (base, sub), v in vals.items():
                bs = block_stat.setdefault((base, sub),
                                           {"items_blocks": 0, "characters_blocks": 0})
                if kind == "items":
                    bs["items_blocks"] += 1
                    blocks_detail.append({"zone": fn, "block": key, "base": base,
                                          "sub": sub, "value": v})
                else:
                    bs["characters_blocks"] += 1

    # 汇总打印
    total_entries = sum(s["files"] for s in sub_stat.values())
    print("corpus sources with prop keys: %d" % len(sources))
    print("total set() prop entries (source files per key): %d" % total_entries)
    print()
    print("%-22s %6s %6s %6s  %s" % ("key", "files", "items", "chars", "class"))
    for (base, sub) in sorted(sub_stat):
        st = sub_stat[(base, sub)]
        bs = block_stat.get((base, sub), {"items_blocks": 0, "characters_blocks": 0})
        print("%-22s %6d %6d %6d  %s" % (
            "%s/%s" % (base, sub), st["files"],
            bs["items_blocks"], bs["characters_blocks"], st["classification"]))

    # 分类汇总
    by_class = {}
    for (base, sub), st in sub_stat.items():
        c = st["classification"]
        agg = by_class.setdefault(c, {"files": 0, "items_blocks": 0, "characters_blocks": 0})
        bs = block_stat.get((base, sub), {"items_blocks": 0, "characters_blocks": 0})
        agg["files"] += st["files"]
        agg["items_blocks"] += bs["items_blocks"]
        agg["characters_blocks"] += bs["characters_blocks"]
    print()
    print("by classification:", json.dumps(by_class, indent=2, ensure_ascii=False))
    print("items blocks total (any prop key):", len(blocks_detail))

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "tmp", "b10_survey.json"), "w",
              encoding="utf-8") as fh:
        json.dump({"sub_stat": {"%s/%s" % k: v for k, v in sub_stat.items()},
                   "block_stat": {"%s/%s" % k: v for k, v in block_stat.items()},
                   "by_class": by_class,
                   "blocks": blocks_detail}, fh, ensure_ascii=False, indent=2)
    print("wrote tmp/b10_survey.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
