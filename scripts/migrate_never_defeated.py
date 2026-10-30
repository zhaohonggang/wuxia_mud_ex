#!/usr/bin/env python3
"""补 `never-defeated`（不败神功）的双招式表 + `valid_enable`。

## 背景

它是 C0 盘点里「5 个真缺口」中最后一个：`valid_enable` 是 `do: false` 空壳，
且**没进 `Kantele.Combat.Skills.@static` 注册表**（`enable` 直接报「没有这项武功」）。

它和 6 个「绝学内功」的差别在**分表维度**：

    LPC never-defeated.c
    mapping *action_default = ({ ... 11 式 ... });   // 空手 / 非鞭
    mapping *action_whip    = ({ ...  5 式 ... });   // 鞭类武器

    mapping query_action(object me, object weapon)
    {
            switch (weapon ? weapon->query("skill_type") : "default")
            {
            case "whip":
                    return action_whip[random(sizeof(action_whip))];
            default:
                    return action_default[random(sizeof(action_default))];
            }
    }

即按**武器的 skill_type** 分表，而不是「有没有武器」。为此
`Kantele.Combat.Fighter` 新增 `:weapon_skill_type`（存原始值，不套
`attack_skill` 的 `pin → sword` 归一），`Kantele.Combat.Skill.weapon_skill_type/1` 读取。

用法：

    python scripts/migrate_never_defeated.py --dry-run
    python scripts/migrate_never_defeated.py --apply
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from migrate_actionf_skills import (  # noqa: E402
    MUD,
    QUERY_TAIL_BY_WEAPON_TYPE,
    REPO,
    parse_table,
    render_table,
)

SKILL = "never-defeated"
MODULE = "never_defeated"
CN = "不败神功"

ENABLE = """  @impl true
  def valid_enable(usage) do
    usage in ["sword", "blade", "dagger", "staff", "hammer", "club", "whip", "dodge", "parry", "force", "throwing"]
  end"""

NOTES = [
    "`valid_force` 恒 1（引擎默认即 true）。",
    "`valid_combo(combo) == \"never-defeated\"` 引擎暂无 combo 回调，未迁移。",
]


def rewrite_moduledoc(src: str, counts: dict) -> str:
    lines = [
        f"武学实装「{SKILL}」（源 {SKILL}.c）",
        "",
        f"{CN}。LPC 的招式表变量名是 **`action_default`** / **`action_whip`**"
        "（既不叫 `action` 也不叫 `actionf`），",
        "`translate_skill.exs` 一个都不认，所以生成时两张表全丢 —— 本文件已按源补回：",
        "",
        f"- `@actions`：`action_default`，空手或非鞭类武器用（{counts['f']} 式）",
        f"- `@actions_weapon`：`action_whip`，鞭类武器用（{counts['w']} 式）",
        "",
        "分表维度是**武器的 `skill_type`** 而不是「有没有武器」：",
        "`switch (weapon ? weapon->query(\"skill_type\") : \"default\")` —— `whip` 走",
        "`action_whip`，其余（含空手）走 `action_default`。`Fighter.weapon_skill_type`",
        "存原始 skill_type 供此判定。",
        "",
    ]
    lines += NOTES
    lines += [
        "",
        "未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛",
        "（路由骨架已由 `perform_list`/`exert_list` 给出）。",
    ]
    doc = '  @moduledoc """\n' + "\n".join("  " + l if l else "" for l in lines) + "\n  \"\"\"\n"
    pattern = re.compile(r'  @moduledoc """.*?"""\n', re.S)
    new, n = pattern.subn(lambda _m: doc, src, count=1)
    if n == 0:
        raise RuntimeError("找不到 moduledoc")
    return new


def strip_attr(src: str, attr: str) -> str:
    """单行 `@attr []` 与多行 `@attr [ ... ]` 两种形式都删（单行分支须在前）。"""
    pattern = re.compile(
        rf"^  {re.escape(attr)} \[\]\n\n?|^  {re.escape(attr)} \[.*?^  \]\n\n?",
        re.M | re.S,
    )
    return pattern.sub("", src)


def replace_tables(src: str, f_table: list[dict], w_table: list[dict]) -> str:
    for attr in ("@actions", "@actions_weapon", "@actions_bad"):
        src = strip_attr(src, attr)

    combined = render_table(f_table, "@actions") + "\n\n" + render_table(w_table, "@actions_weapon") + "\n\n"

    anchor = re.search(r"^  use Kantele\.Combat\.Skill\n\n?", src, re.M)
    if not anchor:
        raise RuntimeError("找不到 `use Kantele.Combat.Skill`")
    return src[: anchor.end()] + combined + src[anchor.end() :]


def replace_behaviour(src: str) -> str:
    id_anchor = re.search(rf'^  def id\(\), do: "{re.escape(SKILL)}"\n', src, re.M)
    if not id_anchor:
        raise RuntimeError(f'找不到 `def id(), do: "{SKILL}"`')

    tail = re.search(r"^  @impl true\n  def (?:perform_list|exert_list)\(\)", src[id_anchor.end() :], re.M)
    if not tail:
        raise RuntimeError("找不到 perform_list / exert_list")

    start = id_anchor.end()
    end = start + tail.start()
    section = "\n" + ENABLE.strip("\n") + "\n\n" + QUERY_TAIL_BY_WEAPON_TYPE + "\n\n"
    return src[:start] + section + src[end:]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="真正写回文件（默认只干跑）")
    ap.add_argument("--dry-run", action="store_true", help="只打印统计（默认行为）")
    args = ap.parse_args()

    lpc = os.path.join(MUD, "kungfu", "skill", f"{SKILL}.c")
    ex = os.path.join(REPO, "lib", "kantele", "combat", "skills", MODULE + ".ex")
    if not (os.path.exists(lpc) and os.path.exists(ex)):
        print(f"[fail] 缺文件：{lpc} / {ex}")
        return 1

    lpc_src = open(lpc, encoding="utf-8", errors="ignore").read()
    f_table = parse_table(lpc_src, "action_default")
    w_table = parse_table(lpc_src, "action_whip")
    if not f_table or not w_table:
        print(f"[fail] 表解析失败：action_default={len(f_table)} action_whip={len(w_table)}")
        return 1

    src = open(ex, encoding="utf-8").read()
    src = rewrite_moduledoc(src, {"f": len(f_table), "w": len(w_table)})
    src = replace_tables(src, f_table, w_table)
    src = replace_behaviour(src)
    src = re.sub(r"\n{3,}", "\n\n", src)

    if args.apply:
        open(ex, "w", encoding="utf-8", newline="").write(src)

    print(
        ("[ok] " if args.apply else "[dry] ")
        + f"{SKILL}: action_default={len(f_table)} action_whip={len(w_table)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
