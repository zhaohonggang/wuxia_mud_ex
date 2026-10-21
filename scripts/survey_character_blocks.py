#!/usr/bin/env python
"""只读勘查：`characters` 块里哪些其实该是 `items`（R7 / D10）。

背景（2026-10-20）：
- `lpc_converter.ex` 的 `determine_object_type/1` 里 `npc_subdir?(path) -> :npc`
  排在 `is_item_inherit?/1` **之前**（L2282-2285）。任何位于 `npc/` 子目录下的
  源文件一律转成 `characters`，即使它 `inherit COMBINED_ITEM`。
- 典型：`d/beijing/npc/dan/danA_1.c`（`inherit COMBINED_ITEM`）→
  `characters "danA_1"`，而 B2 的 `item_meta_backfill.py` 只处理 `items` 块，
  所以这批物品的整个 `meta` 从未生成过。
- 已确认 83 个块 / 68% 的装备文案目标受影响。

本脚本按**源文件的继承链**而不是目录位置来判定真实类型，判据与转换器
`is_item_inherit?/1` 用的是同一张关键字表（保证口径一致）。只读，不改数据。

用法：
    python scripts/survey_character_blocks.py            # 打印报告
    python scripts/survey_character_blocks.py --json      # 同时写 tmp/survey_character_blocks.json

输出分类：
    item   —— 继承链上有物品标记，且没有 NPC/ROOM 标记 → 应改成 items 块
    npc    —— 有 NPC/KNOWER 标记（保持 characters 块）
    room   —— 有 ROOM/RIVER 标记
    skill  —— 有 SKILL/FORCE ? 标记
    unknown—— 没有 Generated-from 注释，或源不可读，或继承链解析不出标记
"""
import glob
import io
import json
import os
import re
import sys

# 与 lpc_converter.ex is_item_inherit?/1 同一张关键字表（顺序无关，只做 contains）
ITEM_KEYWORDS = [
    "WEAPON", "SWORD", "BLADE", "DAGGER", "STAFF", "CLUB", "HAMMER", "AXE",
    "THROWING", "WHIP", "FORCE ?", "ARMOR", "CLOTH", "BOOTS", "FINGER",
    "HANDS", "HEAD", "HELMET", "NECK", "RING", "SHIELD", "SURCOAT", "WAIST",
    "WRIST", "ARMOR ?", "ITEM", "MONEY", "CONTAINER", "FOOD", "MEDICINE",
    "BOOK", "GOLD", "SILVER",
]
# skill_inherit?/1 大写化后匹配 SKILL / FORCE ?（注意 "FORCE ?" 含空格而非 "FORCE"）
SKILL_KEYWORDS = ["SKILL", "FORCE ?"]

REPO_ROOT = "C:/files/git/mud"

RE_INHERIT = re.compile(r'''inherit\s+(["']?)([^;"']+)\1\s*;''')
RE_DEFINE = re.compile(r'#\s*define\s+([A-Za-z_]\w*)\s+([^\s;()]+)')
RE_DIR_QUOTED = re.compile(r'^\s*__DIR__\s*["\']([^"\']+)["\']\s*$')
RE_QUOTED = re.compile(r'^["\']([^"\']+)["\']\s*$')

RE_BLOCK_HEAD = re.compile(r'^(\s*)characters\s+"([^"]+)"\s*\{\s*$')
RE_GENERATED = re.compile(r'^# Generated from (\S+)')
# 块内注释才是权威归属：转换器为每个块写一行 `# LPC: <repo 相对路径>`，
# 而 `# Generated from` 头部只对**源文件**写一次，不逐块写。
# （2026-10-16 的对账教训：按「前最近的 # Generated from」归块会把
#  `mangshe` 等 12 条蛇算成 zhulou.c 被误写，虚高 item 数。）
RE_LPC_IN_BLOCK = re.compile(r'^\s*#\s*LPC:\s*(\S+)\s*$')


def read_text(path):
    try:
        with io.open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except (IOError, OSError):
        return None


def parse_inherits(content):
    return [m[1].strip() for m in RE_INHERIT.findall(content)]


def parse_defines(content):
    return {m[0]: m[1].strip() for m in RE_DEFINE.findall(content)}


def resolve_inherit_ref(token, defines):
    """复刻 lpc_converter.ex resolve_inherit_ref/2：返回相对仓库根的路径或 None。"""
    token = token.strip()

    if token.startswith("/"):
        path = token
    elif token in defines:
        value = defines[token]
        m = RE_DIR_QUOTED.match(value)
        if m:
            path = m.group(1)
        else:
            m = RE_QUOTED.match(value)
            if m:
                path = m.group(1)
            else:
                return None
    else:
        return None

    if not path:
        return None
    # 绝对路径（如 "/d/beijing/x"）剥前导 "/"，视为相对源码根
    return path.lstrip("/")


def inherit_tokens_chain(source_path, content, max_depth=12):
    """沿继承链收集所有 inherit token；去重、防环。"""
    seen_files = set()
    tokens = []
    queue = [(source_path, content, 0)]

    while queue:
        path, text, depth = queue.pop(0)
        if path in seen_files or depth > max_depth:
            continue
        seen_files.add(path)

        local = text or read_text(os.path.join(REPO_ROOT, path if path.endswith(".c") else path + ".c"))
        if local is None:
            continue
        tokens.extend(parse_inherits(local))
        if depth >= max_depth:
            continue

        defines = parse_defines(local)
        directory = os.path.dirname(path)
        for token in parse_inherits(local):
            rel = resolve_inherit_ref(token, defines)
            if rel is None:
                continue
            child = os.path.normpath(os.path.join(directory, rel)).replace("\\", "/")
            if child in seen_files:
                continue
            queue.append((child, None, depth + 1))

    return tokens, seen_files


def classify(tokens):
    """按转换器口径分类。任一 NPC/KNOWER/ROOM 标记优先于物品标记
    （对应 determine_object_type/1 的 cond 顺序）。"""
    upper = [t.upper() for t in tokens]

    if any("ROOM" in u or "RIVER" in u for u in upper):
        return "room"
    if any("NPC" in u or "KNOWER" in u for u in upper):
        return "npc"
    if any(kw in u for u in upper for kw in ITEM_KEYWORDS):
        return "item"
    if any(kw in u for u in upper for kw in SKILL_KEYWORDS):
        return "skill"
    return "unknown"


def scan_blocks():
    """扫 data/world/*.ucl，产出每个 characters 块的记录。"""
    records = []
    for path in sorted(glob.glob("data/world/*.ucl")):
        lines = read_text(path).split("\n")
        idx = 0
        while idx < len(lines):
            m = RE_BLOCK_HEAD.match(lines[idx])
            if not m:
                idx += 1
                continue

            block_id = m.group(2)
            head_line = idx

            # 收块体（到第一个单独的 "}"）
            end = idx + 1
            depth = 1
            while end < len(lines) and depth > 0:
                depth += lines[end].count("{") - lines[end].count("}")
                if depth == 0:
                    break
                end += 1

            body = lines[idx + 1:end]

            # 归属优先取块内 `# LPC:`（权威），退化为前最近的 `# Generated from`
            src = None
            src_kind = None
            for line in body:
                g = RE_LPC_IN_BLOCK.match(line)
                if g:
                    src = g.group(1)
                    src_kind = "lpc-in-block"
                    break

            if src is None:
                for j in range(head_line - 1, max(-1, head_line - 6), -1):
                    g = RE_GENERATED.match(lines[j])
                    if g:
                        src = g.group(1)
                        src_kind = "generated-from"
                        break
                    if lines[j].strip() == "" and j < head_line - 1:
                        break

            records.append({
                "file": path.replace("\\", "/"),
                "line": head_line + 1,
                "end_line": end + 1,
                "id": block_id,
                "source": src,
                "source_kind": src_kind,
            })
            idx = end + 1
    return records


def survey():
    records = scan_blocks()
    stats = {"item": 0, "npc": 0, "room": 0, "skill": 0, "unknown": 0}
    no_source = 0
    unreadable_source = 0
    details = []

    for rec in records:
        src = rec["source"]
        if src is None:
            cls = "unknown"
            no_source += 1
            rec["chain"] = []
            rec["chain_files"] = []
        else:
            # `# LPC:` 是仓库相对路径；`# Generated from` 是绝对 Windows 路径
            abs_src = src if os.path.isfile(src) else os.path.join(REPO_ROOT, src)
            content = read_text(abs_src)
            if content is None:
                cls = "unknown"
                unreadable_source += 1
                rec["chain"] = []
                rec["chain_files"] = []
            else:
                # 递归解析用仓库相对路径
                rel = src[len(REPO_ROOT) + 1:] if src.startswith(REPO_ROOT + "/") else src
                tokens, chain_files = inherit_tokens_chain(rel, content)
                cls = classify(tokens)
                rec["chain"] = sorted(set(tokens))
                rec["chain_files"] = sorted(chain_files)

        rec["classification"] = cls
        stats[cls] += 1
        details.append(rec)

    return {"total": len(records), "stats": stats,
            "no_source": no_source, "unreadable_source": unreadable_source,
            "records": details}


def main(argv):
    write_json = "--json" in argv
    result = survey()

    print("characters blocks scanned : %d" % result["total"])
    print("  without Generated-from  : %d" % result["no_source"])
    print("  with unreadable source  : %d" % result["unreadable_source"])
    print()
    print("classification by inherit chain:")
    for k in ("item", "npc", "room", "skill", "unknown"):
        print("  %-8s %5d" % (k, result["stats"][k]))
    print()
    print("=> should be `items` blocks: %d" % result["stats"]["item"])

    items = [r for r in result["records"] if r["classification"] == "item"]
    if items:
        by_file = {}
        for r in items:
            by_file.setdefault(r["file"], []).append(r)
        print()
        print("per-file breakdown:")
        for f in sorted(by_file):
            print("  %-26s %3d  (%s)" % (f, len(by_file[f]),
                                          ", ".join(r["id"] for r in by_file[f][:6]) +
                                          (" ..." if len(by_file[f]) > 6 else "")))

    if write_json:
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "tmp", "survey_character_blocks.json")
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(result, fh, ensure_ascii=False, indent=2)
        print()
        print("wrote tmp/survey_character_blocks.json")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
