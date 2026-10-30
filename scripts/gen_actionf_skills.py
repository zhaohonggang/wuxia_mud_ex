#!/usr/bin/env python3
"""把 LPC `mapping *actionf = ({ ... });` 的招式表转成 Elixir `@actions` 并写回。

## 为什么需要这个脚本

`translate_skill.exs` 只认变量名 `action`（447 个技能如此），而 **6 个「绝学内功」**
用的是 `actionf`（`inherit FORCE` 家族）：bluesea-force / jiuyang-shengong /
jiuyin-shengong / kuihua-mogong / taixuan-gong / zhonghua-aojue。
于是这 6 个技能在 Elixir 侧全是 `@actions []` —— 能学、能练，但**出招无描述、无伤害**。

这 6 个文件的 `actionf` 全部是**静态字面量**（无 `query_skill` / `this_player` /
`random()`），所以可以机械转换，无需人工复现公式。

## 输出格式

与 `translate_skill.exs` 生成的既有技能（如 `huashan_jian.ex`）逐字一致：

    @actions [
      %{
        "action" => "...",
        "force" => 70,
        "attack" => 10,
        "parry" => 5,
        "dodge" => 10,
        "damage" => 30,
        "lvl" => 0,
        "damage_type" => "刺伤",
        "skill_name" => "有凤来仪"
      },
      ...
    ]

`skill_name` 取 `action` 文案里第一个「…」的内容；LPC 没有 `lvl` 字段，统一写 0。

用法：

    python scripts/gen_actionf_skills.py --dry-run   # 只打印
    python scripts/gen_actionf_skills.py --apply     # 写回 .ex
"""

from __future__ import annotations

import argparse
import os
import re
import sys

MUD = os.environ.get("MUD_SRC", "C:/files/git/mud")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# LPC 技能名 -> Elixir 模块文件（下划线化）
SKILLS = [
    "bluesea-force",
    "jiuyang-shengong",
    "jiuyin-shengong",
    "kuihua-mogong",
    "taixuan-gong",
    "zhonghua-aojue",
]

FIELD_ORDER = ["action", "force", "attack", "parry", "dodge", "damage", "lvl", "damage_type"]

ENTRY_RE = re.compile(r"\(\[(.*?)\]\)", re.S)
KV_RE = re.compile(r'"(\w+)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+)')


def elixir_string(literal: str) -> str:
    """LPC 双引号字面量 -> Elixir 双引号字面量（转义已兼容，保留原样）。"""
    return literal


def parse_actions(src: str, var: str = "actionf") -> list[dict]:
    m = re.search(rf"mapping\s*\*\s*{var}\s*=\s*\(\{{(.*?)\n\}}\);", src, re.S)
    if not m:
        return []

    actions = []
    for block in ENTRY_RE.findall(m.group(1)):
        entry: dict[str, str] = {}
        for key, value in KV_RE.findall(block):
            entry[key] = value
        if "action" not in entry:
            continue
        actions.append(entry)
    return actions


def skill_name_of(action_literal: str) -> str | None:
    body = action_literal.strip('"')
    m = re.search(r"「([^」]+)」", body)
    return m.group(1) if m else None


def render_actions(actions: list[dict], attr: str = "@actions") -> str:
    lines = [f"  {attr} ["]
    for entry in actions:
        lines.append("    %{")
        fields = []
        for key in FIELD_ORDER:
            if key == "lvl":
                fields.append(('"lvl"', "0"))
                continue
            if key in entry:
                fields.append((f'"{key}"', entry[key]))
        name = skill_name_of(entry.get("action", ""))
        if name:
            fields.append(('"skill_name"', f'"{name}"'))
        for i, (k, v) in enumerate(fields):
            comma = "," if i < len(fields) - 1 else ""
            lines.append(f"      {k} => {v}{comma}")
        lines.append("    },")
    lines.append("  ]")
    return "\n".join(lines)


def patch_file(path: str, replacements: list[tuple[str, str]]) -> list[str]:
    """按序把 `@actions []` 之类占位替换成真实表。返回实际替换掉的占位符。"""
    src = open(path, encoding="utf-8").read()
    done = []
    for placeholder, block in replacements:
        pattern = re.compile(r"^  " + re.escape(placeholder) + r"$", re.M)
        src, n = pattern.subn(lambda _m, b=block: b, src, count=1)
        if n:
            done.append(placeholder)
    if done:
        open(path, "w", encoding="utf-8", newline="").write(src)
    return done


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    apply = args.apply
    rc = 0

    for skill in SKILLS:
        lpc = os.path.join(MUD, "kungfu", "skill", f"{skill}.c")
        ex = os.path.join(REPO, "lib", "kantele", "combat", "skills", skill.replace("-", "_") + ".ex")

        if not os.path.exists(lpc):
            print(f"[skip] 缺 LPC 源 {lpc}")
            rc = 1
            continue
        if not os.path.exists(ex):
            print(f"[skip] 缺 Elixir {ex}")
            rc = 1
            continue

        actions = parse_actions(open(lpc, encoding="utf-8", errors="ignore").read(), "actionf")
        if not actions:
            print(f"[skip] {skill}: 未解析到 actionf")
            rc = 1
            continue

        src = open(lpc, encoding="utf-8", errors="ignore").read()
        weapon_actions = parse_actions(src, "actionw")
        bad_actions = parse_actions(src, "actionbad")

        replacements = [("@actions []", render_actions(actions, "@actions"))]
        if weapon_actions:
            replacements.append(
                ("@actions_weapon []", render_actions(weapon_actions, "@actions_weapon"))
            )
        if bad_actions:
            replacements.append(
                ("@actions_bad []", render_actions(bad_actions, "@actions_bad"))
            )

        if apply:
            done = patch_file(ex, replacements)
            print(
                f"[{'+'.join(done) if done else 'noop'}] {skill}: "
                f"actionf={len(actions)} actionw={len(weapon_actions)} actionbad={len(bad_actions)}"
            )
        else:
            print(f"=== {skill} (actionf={len(actions)} actionw={len(weapon_actions)} actionbad={len(bad_actions)}) ===")
            print(render_actions(actions, "@actions"))
            print()
            if weapon_actions:
                print(render_actions(weapon_actions, "@actions_weapon"))
                print()
            if bad_actions:
                print(render_actions(bad_actions, "@actions_bad"))
                print()

    return rc


if __name__ == "__main__":
    sys.exit(main())
