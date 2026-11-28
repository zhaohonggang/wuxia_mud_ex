#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UG-06 carry 裸引用回填器。

按每个 NPC 块头 `# Generated from <lpc_path> by LPCConverter` 读 LPC 源文件的
carry_object(...) 路径，把 carry 列表里不带 zone 前缀的 `items.<key>.id` 改写为
LPC 路径对应的 `<zone>.items.<key>.id` 限定引用。

只改 carry 段内、key 命中歧义清单的引用；LPC 源里找不到对应 carry_object
路径的键保持原样并打印 WARN（人工核查）。
"""
import re
import sys
from pathlib import Path

WORLD = Path("data/world")

# 仍处于歧义/损坏状态的 carry 键（引擎唯一键回退已修掉其余）
TARGET_KEYS = {
    "armor1", "beixin", "bi", "blade1", "bluecloth", "cheng_cloth", "cloth1",
    "cloth2", "cloth4", "fuchen", "greenrobe", "greyrobe", "hat", "necklace",
    "pink_cloth", "shoes", "staff", "stick", "tiejiang", "xuan_cloth",
    "yayifu", "ycloth", "",
}

BLOCK_RE = re.compile(
    r'(# Generated from \S*mud[/\\](\S+)\.c by LPCConverter\n# Zone: (\w+)\n\n\s*characters "(\w+)" \{)',
    re.M,
)
CARRY_RE = re.compile(r'(carry = \[\n)((?:.*?\n)*?)(  \])')
REF_RE = re.compile(r'\{ id = items\.(\w*)\.id \}')
CARRY_OBJ_RE = re.compile(r'carry_object\(\s*(?:__DIR__|"/d/|")([^"]*?)(?:")?([^"]*)"?')
CARRY_OBJ_FULL = re.compile(r'carry_object\(([^)]*)\)')

def lpc_carry_paths(lpc_file: Path):
    """返回 LPC 文件里 carry_object(...) 的原始参数串列表。"""
    try:
        text = lpc_file.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    return [m.group(1).strip() for m in CARRY_OBJ_FULL.finditer(text)]

def resolve_arg(arg: str, lpc_dir: Path):
    """把 carry_object 参数串解析成 (zone_id, key) 或 None。

    形态：__DIR__"obj/xxx" 、 "/d/zone/.../xxx" 、 __DIR__"xxx" 等。
    """
    m = re.match(r'__DIR__\s*"([^"]+)"', arg)
    if m:
        rel = m.group(1)
        base = (lpc_dir / rel).resolve()
    else:
        m = re.match(r'"([^"]+)"', arg)
        if not m:
            return None
        p = m.group(1)
        if p.startswith("/d/"):
            base = Path(r"C:/files/git/mud") / p.lstrip("/")
        else:
            base = (lpc_dir / p).resolve()
    if base.suffix != ".c":
        base = base.with_suffix(".c")
    if not base.exists():
        return None
    # /d/<dir>/... -> zone 即目录名第一段
    parts = base.parts
    try:
        d_idx = parts.index("d")
    except ValueError:
        return None
    zone = parts[d_idx + 1]
    # sky 在 ex 侧是 death zone 的子目录（d/death/sky），LPC dir=sky 时归 death/sky 区
    if zone == "death" and len(parts) > d_idx + 2 and parts[d_idx + 2] == "sky":
        zone = "sky"  # ex 侧独立 zone id（物品 id 形如 sky:xxx）
    return zone, base.stem.replace('-', '_')

def process_ucl(ucl: Path, report, apply=False):
    text = ucl.read_text(encoding="utf-8")
    changed = 0
    out = []
    last_end = 0
    for m in BLOCK_RE.finditer(text):
        lpc_rel = m.group(2)
        lpc_file = Path(r"C:/files/git/mud") / (lpc_rel.replace("\\", "/") + ".c")
        block_start = m.end()
        # 块结束：下一个 "# Generated from" 或文件尾
        nxt = text.find("# Generated from", block_start)
        block = text[block_start:nxt if nxt != -1 else len(text)]
        cm = CARRY_RE.search(block)
        if not cm:
            continue
        carry_body = cm.group(2)
        if not REF_RE.search(carry_body):
            continue
        args = lpc_carry_paths(lpc_file)
        resolved = []
        lpc_dir = lpc_file.parent
        for a in args:
            r = resolve_arg(a, lpc_dir)
            if r:
                resolved.append(r)

        def repl(rm):
            nonlocal changed
            key = rm.group(1)
            if key not in TARGET_KEYS:
                return rm.group(0)
            # 在 LPC resolved 里找 basename == key 的条目
            hits = [z for (z, k) in resolved if k == key]
            if key == "":
                # items..id：LPC fujiang.c 随机武器，回填 changjian 并注释
                if any(k == "changjian" for (_z, k) in resolved) or "weapon_file" in (
                    lpc_file.read_text(encoding="utf-8", errors="replace") if lpc_file.exists() else ""
                ):
                    changed += 1
                    return "{ id = changan.items.changjian.id }  # LPC fujiang.c weapon_file=random(5)，随机武器未建模，取 changjian"
                report.append(("EMPTY_KEY", str(ucl), lpc_rel))
                return rm.group(0)
            if not hits:
                report.append(("NO_LPC_MATCH", str(ucl), lpc_rel, key))
                return rm.group(0)
            if len(set(hits)) > 1:
                report.append(("AMBIG_LPC", str(ucl), lpc_rel, key, str(hits)))
                return rm.group(0)
            changed += 1
            return "{ id = %s.items.%s.id }" % (hits[0], key)

        new_body = REF_RE.sub(repl, carry_body)
        if changed:
            pass
        new_block = block[:cm.start(2)] + new_body + block[cm.end(2):]
        out.append(text[last_end:block_start])
        out.append(new_block)
        last_end = (nxt if nxt != -1 else len(text))
    out.append(text[last_end:])
    if changed and apply:
        ucl.write_text("".join(out), encoding="utf-8", newline="\n")
    return changed

def main():
    apply = "--apply" in sys.argv
    report = []
    total = 0
    for ucl in sorted(WORLD.glob("*.ucl")):
        n = process_ucl(ucl, report, apply)
        total += n
        if n:
            print(f"{ucl}: rewrote {n}")
    print(f"\nTOTAL rewrote: {total}" + ("" if apply else "  (DRY RUN, 未写盘)"))
    if report:
        print("\n-- WARN report --")
        for row in report:
            print(" | ".join(str(x) for x in row))

if __name__ == "__main__":
    sys.exit(main())
