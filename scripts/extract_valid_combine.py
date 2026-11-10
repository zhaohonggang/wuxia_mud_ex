#!/usr/bin/env python3
"""Extract LPC `valid_combine` pairs into an Elixir data module.

Source: /c/files/git/mud/kungfu/skill/*.c
Output: lib/kantele/combat/skill_combos.ex (generated; do not hand-edit the map)

Each LPC skill file defines:

    int valid_combine(string combo) { return combo == "x" || combo == "y"; }

possibly across several lines. Commented-out definitions (`//int valid_combine`)
are ignored, as are files without an active definition. The LPC skill id is the
filename without `.c` (hyphenated), matching `Kantele.Combat.Skills.@static` keys.
"""
import re
import sys
from pathlib import Path

LPC_DIR = Path("/c/files/git/mud/kungfu/skill")
OUT = Path("/c/files/git/wuxia_mud_ex/lib/kantele/combat/skill_combos.ex")

# Matches an active (non-commented) valid_combine definition and its body up to
# the closing brace of the return statement.
DEF_RE = re.compile(
    r"^[ \t]*int\s+valid_combine\s*\([^)]*\)\s*\{(?P<body>.*?)\}",
    re.MULTILINE | re.DOTALL,
)
STR_RE = re.compile(r'combo\s*==\s*"([a-z0-9_-]+)"')


def extract(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    # Strip line comments so commented-out definitions don't count.
    lines = []
    for line in text.splitlines():
        # Only strip full-line comments; inline `//` after code is rare here.
        stripped = line.lstrip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue
        lines.append(line)
    cleaned = "\n".join(lines)

    match = DEF_RE.search(cleaned)
    if not match:
        return None
    return sorted(set(STR_RE.findall(match.group("body"))))


def main():
    pairs = {}
    for path in sorted(LPC_DIR.glob("*.c")):
        combos = extract(path)
        if combos:
            pairs[path.stem] = combos

    # NOTE: 全量扫描 LPC 源未发现任何 valid_combine 定义（0 文件）。
    # 现有组合数据来自已落地的 Elixir 技能模块（taiji-quan 等），
    # 手工维护于 lib/kantele/combat/skill_combos.ex。
    if not pairs:
        print("INFO: no valid_combine definitions found in LPC sources (expected - none exist)")
        print("      existing combos come from Elixir skill modules (see skill_combos.ex)")
        return 0

    # Sanity: report asymmetric declarations (informational, not an error — LPC
    # sources are not perfectly symmetric).
    asym = []
    for skill, combos in pairs.items():
        for other in combos:
            if other not in pairs or skill not in pairs[other]:
                asym.append((skill, other))

    lines = [
        "defmodule Kantele.Combat.SkillCombos do",
        '  @moduledoc """',
        "  拳术组合白名单（LPC `valid_combine` 的移植）。",
        "",
        "  数据源：`/c/files/git/mud/kungfu/skill/*.c` 中每个技能文件的",
        "  `int valid_combine(string combo)` 返回值。由",
        "  `scripts/extract_valid_combine.py` 生成，**勿手工编辑 `@combos`**。",
        "",
        "  LPC 语义：`SKILL_D(arg1)->valid_combine(arg2)` 判定两种特殊拳术能否",
        "  组合预备（`cmds/skill/prepare.c`）。键为技能 id（连字符，与",
        "  `Kantele.Combat.Skills.@static` 一致），值为允许与之组合的技能 id 列表。",
        "",
        "  注：LPC 源本身并非完全对称，故 `valid_combine?/2` 按方向查询，",
        "  与 LPC 保持一致（不自动补全反向关系）。",
        '  """',
        "",
        "  @combos %{",
    ]
    for skill in sorted(pairs):
        combos = ", ".join(f'"{c}"' for c in pairs[skill])
        lines.append(f'    "{skill}" => [{combos}],')
    lines += [
        "  }",
        "",
        "  @doc \"返回全部组合表（skill_id -> [允许组合的 skill_id]）。\"",
        "  def all, do: @combos",
        "",
        "  @doc \"某技能声明的可组合技能列表；未定义 valid_combine 的技能返回 `[]`。\"",
        "  def for(skill_id) when is_binary(skill_id), do: Map.get(@combos, skill_id, [])",
        "",
        "  @doc \"LPC `SKILL_D(skill)->valid_combine(other)` 等价判定（有方向）。\"",
        "  def valid_combine?(skill, other) when is_binary(skill) and is_binary(other),",
        "    do: other in Map.get(@combos, skill, [])",
        "",
        "  @doc \"技能数 / 组合关系数（供测试与统计）。\"",
        "  def size, do: map_size(@combos)",
        "",
        "  def pair_count, do: Enum.reduce(@combos, 0, fn {_k, v}, acc -> acc + length(v) end)",
        "end",
        "",
    ]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")

    print(f"skills with valid_combine: {len(pairs)}")
    print(f"total pairs: {sum(len(v) for v in pairs.values())}")
    print(f"asymmetric pairs (informational): {len(asym)}")
    for a, b in asym[:20]:
        print(f"  {a} -> {b} (no reverse)")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
