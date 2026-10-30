#!/usr/bin/env python3
"""把 6 个「绝学内功」的 LPC 双招式表（`actionf` / `actionw`）迁到 Elixir。

## 背景

`translate_skill.exs` 只认招式表变量名 `action`；全库恰好有 6 个 `inherit FORCE`
的绝学内功用的是 `actionf` + `actionw`（按是否持械分两张表），生成时整表丢失：

    bluesea-force / jiuyang-shengong / jiuyin-shengong /
    kuihua-mogong / taixuan-gong / zhonghua-aojue

于是这 6 个技能在 Elixir 侧是 `@actions []`：能学能练，但出招无描述、无伤害。

## 本脚本做什么（幂等）

1. 从 LPC 源解析 `actionf` / `actionw` / `actionbad` 三张表，写成
   `@actions` / `@actions_weapon` / `@actions_bad`（与既有技能同样的 map 结构）；
2. 重写 `def id()` 与 `def perform_list()`（或 `exert_list`）之间的「行为段」——
   即 `valid_enable` / `query_action` / `actions` / `weapon_actions` 一整块，
   每技能按 LPC 原文定制（见 `BEHAVIOUR`）；
3. 重写 moduledoc 的 `TODO(migrate)` 段（说明真实缺口）。

用法：

    python scripts/migrate_actionf_skills.py --dry-run
    python scripts/migrate_actionf_skills.py --apply
"""

from __future__ import annotations

import argparse
import os
import re
import sys

MUD = os.environ.get("MUD_SRC", "C:/files/git/mud")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FIELD_ORDER = ["action", "force", "attack", "parry", "dodge", "damage", "lvl", "damage_type"]
ENTRY_RE = re.compile(r"\(\[(.*?)\]\)", re.S)
KV_RE = re.compile(r'"(\w+)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+)')


# ---- 每技能的「行为段」（valid_enable / query_action / actions / weapon_actions）----

# 通用尾部：两张表按是否持械分流
QUERY_TAIL = """  @impl true
  def query_action(level, rng \\\\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, nil, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, attacker, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "持械招式表（LPC `actionw`）"
  def weapon_actions(), do: @actions_weapon"""

# never-defeated：按**武器类型**分表，不是「有无武器」
QUERY_TAIL_BY_WEAPON_TYPE = """  @impl true
  def query_action(level, rng \\\\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    # LPC: switch (weapon ? weapon->query("skill_type") : "default")
    #       { case "whip": return action_whip[random(sizeof(action_whip))];
    #         default:    return action_default[random(sizeof(action_default))]; }
    if Kantele.Combat.Skill.weapon_skill_type(attacker) == "whip" do
      Kantele.Combat.Skill.pick_action(@actions_weapon, level, rng)
    else
      Kantele.Combat.Skill.pick_action(@actions, level, rng)
    end
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "鞭法招式表（LPC `action_whip`）"
  def weapon_actions(), do: @actions_weapon"""

# 太玄专用尾部：识字的直接走 `actionbad[0]`
QUERY_TAIL_LITERATE = """  @impl true
  def query_action(level, rng \\\\ &:rand.uniform/1), do: query_action(level, rng, nil)

  @impl true
  def query_action(level, rng, attacker) do
    if literate?(attacker) do
      # LPC: if (me->query_skill("literate", 1) || me->query("learned_literate"))
      #          return actionbad[0];
      List.first(@actions_bad) || %{}
    else
      Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, attacker, rng)
    end
  end

  # 识字的人参不透太玄经的蝌蚪文（LPC `query_skill("literate", 1) || query("learned_literate")`；
  # 本引擎 `learned_literate` 未独立建模，识字技能 > 0 即视为识字，与
  # `ItemDescHandlers.PlayerSkill` 的判定一致）。
  # 两种形状都要认：`valid_enable/2` 收角色（`meta.stats`），`query_action/3` 收 Fighter 快照（`skills`）。
  defp literate?(%{meta: %{stats: stats}}),
    do: Kantele.Character.Stats.skill(stats, "literate") > 0

  defp literate?(%{skills: skills}) when is_map(skills), do: Map.get(skills, "literate", 0) > 0
  defp literate?(_), do: false

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "持械招式表（LPC `actionw`）"
  def weapon_actions(), do: @actions_weapon"""

BEHAVIOUR = {
    # ---- 1. 南海玄功：usage_skills 直接列 ----
    "bluesea-force": {
        "module": "bluesea_force",
        "cn": "南海玄功",
        "literate_bad": False,
        "enable": """  @impl true
  def valid_enable(usage), do: usage in ["finger", "strike", "staff", "dodge", "parry", "force"]""",
        "notes": [
            "`valid_force` 恒 1（引擎默认即 true）。",
            "`valid_combo`（bluesea-force / tanzhi-shentong）引擎暂无 combo 回调，未迁移。",
        ],
    },
    # ---- 2. 九阳神功：reborn 门控 + can_learn/enable_weapon ----
    "jiuyang-shengong": {
        "module": "jiuyang_shengong",
        "cn": "九阳神功",
        "literate_bad": False,
        "enable": '''  @impl true
  def valid_enable(usage), do: usage == "force"

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`，有 reborn 门控）：

      if (me->query("reborn")) {
          if (!me->query("can_learn/jiuyang-shengong/enable_weapon"))
              return usage == "force" || usage == "unarmed" || usage == "parry";
          else
              return usage == "force" || usage == "unarmed" || usage == "parry"
                     || usage == "sword" || usage == "blade";
      } else
          return usage == "force";

  `reborn` 以 `stats.reborn` 有非零加成为准（见 `Kantele.Combat.Skill.reborn?/1`）；
  `can_learn/...` 落在 `meta.marks`（见 `Kantele.Combat.Skill.mark?/2`）。
  """
  @impl true
  def valid_enable(usage, character) do
    cond do
      not Kantele.Combat.Skill.reborn?(character) -> usage == "force"
      weapon_enabled?(character) -> usage in ["force", "unarmed", "parry", "sword", "blade"]
      true -> usage in ["force", "unarmed", "parry"]
    end
  end

  defp weapon_enabled?(character),
    do: Kantele.Combat.Skill.mark?(character, "can_learn/jiuyang-shengong/enable_weapon")''',
        "notes": [
            "**reborn 门控**：未转世只能 enable `force`；转世后放开拳脚/招架，",
            "拿到 `can_learn/jiuyang-shengong/enable_weapon` 才加剑/刀 ——",
            "`valid_enable/1` 走未转世分支（保守），`valid_enable/2` 读角色走完整分支。",
            "`valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。",
        ],
    },
    # ---- 3. 九阴神功：reborn 门控（usage_skills3 / usage_skills）----
    "jiuyin-shengong": {
        "module": "jiuyin_shengong",
        "cn": "九阴神功",
        "literate_bad": False,
        "enable": '''  @impl true
  def valid_enable(usage), do: usage == "force"

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`）：

      if (!me->query("reborn"))
          return (member_array(usage, usage_skills3) != -1);   // {"force"}
      else
          return (member_array(usage, usage_skills) != -1);    // 9 项

  未转世只能 `force`；转世后放开拳脚/爪/手法/鞭/轻功/招架等 9 项。
  """
  @impl true
  def valid_enable(usage, character) do
    if Kantele.Combat.Skill.reborn?(character) do
      usage in ["unarmed", "strike", "claw", "hand", "cuff", "dodge", "whip", "parry", "force"]
    else
      usage == "force"
    end
  end''',
        "notes": [
            "**reborn 门控**：`usage_skills3` 只有 `force`，转世后才放开 `usage_skills` 的 9 项；",
            "`valid_enable/1` 走未转世分支（保守），`valid_enable/2` 读角色走完整分支。",
            "`valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。",
        ],
    },
    # ---- 4. 葵花魔功：usage_skills 直接列 ----
    "kuihua-mogong": {
        "module": "kuihua_mogong",
        "cn": "葵花魔功",
        "literate_bad": False,
        "enable": """  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "sword", "dodge", "parry", "force"]""",
        "notes": [
            "`valid_combo(combo) == \"kuihua-mogong\"` 引擎暂无 combo 回调，未迁移。",
            "`valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。",
        ],
    },
    # ---- 5. 太玄功：literate 全拒 + enable_weapon 后按剑/刀等级放开 ----
    "taixuan-gong": {
        "module": "taixuan_gong",
        "cn": "太玄功",
        "literate_bad": True,
        "enable": '''  @base_usages ["force", "unarmed", "dodge", "parry"]

  @impl true
  def valid_enable(usage), do: usage in @base_usages

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`）：

      if (me->query_skill("literate", 1) || me->query("learned_literate"))
          return usage == 0;
      if (!me->query("can_learned/taixuan-gong/enable_weapon"))
          return usage == "force" || usage == "unarmed" || usage == "dodge" || usage == "parry";
      // 之后按 sword / blade 与 taixuan-gong 的等级关系逐级放开剑或刀

  注意 `usage == 0` 是 LPC 里 string 与 int 的比较，**恒为假** —— 即识字的人
  一项都不能 enable（参不透蝌蚪文，连内功都不行）。
  """
  @impl true
  def valid_enable(usage, character) do
    cond do
      literate?(character) -> false
      not weapon_enabled?(character) -> usage in @base_usages
      true -> usage in (@base_usages ++ extra_usages(character))
    end
  end

  defp weapon_enabled?(character),
    do: Kantele.Combat.Skill.mark?(character, "can_learned/taixuan-gong/enable_weapon")

  # LPC 四个分支：谁的等级低于太玄就不放开谁；相等走 else（剑刀都放开）
  defp extra_usages(character) do
    tx = skill_level(character, "taixuan-gong")
    sword = skill_level(character, "sword")
    blade = skill_level(character, "blade")

    cond do
      sword < tx and blade < tx -> []
      sword < tx and blade > tx -> ["blade"]
      sword > tx and blade < tx -> ["sword"]
      true -> ["blade", "sword"]
    end
  end

  defp skill_level(%{meta: %{stats: stats}}, name), do: Kantele.Character.Stats.skill(stats, name)
  defp skill_level(_, _name), do: 0''',
        "notes": [
            "**literate 分支**：LPC `query_action` 里识字就 `return actionbad[0]`（只会「胡乱使出」，",
            "`@actions_bad` 10/10/10/10/10）；`valid_enable` 里识字则 `usage == 0` 恒假 → **全拒**。",
            "**enable_weapon 分支**：`can_learned/taixuan-gong/enable_weapon` 之后按",
            "`sword` / `blade` 与 `taixuan-gong` 的等级关系放开剑或刀。",
        ],
    },
    # ---- 6. 中华傲诀：usage_skills 直接列 ----
    "zhonghua-aojue": {
        "module": "zhonghua_aojue",
        "cn": "中华傲诀",
        "literate_bad": False,
        "enable": """  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "strike", "sword", "dodge", "parry", "force"]""",
        "notes": [
            "`valid_force` 恒 1（引擎默认即 true）；`valid_combo` / `double_attack` 引擎无对应回调，未迁移。",
        ],
    },
}


# ---- LPC 解析 ----


def parse_table(src: str, var: str) -> list[dict]:
    m = re.search(rf"mapping\s*\*\s*{var}\s*=\s*\(\{{(.*?)\n\}}\);", src, re.S)
    if not m:
        return []
    out = []
    for block in ENTRY_RE.findall(m.group(1)):
        entry = dict(KV_RE.findall(block))
        if "action" in entry:
            out.append(entry)
    return out


def skill_name_of(action_literal: str) -> str | None:
    m = re.search(r"「([^」]+)」", action_literal.strip('"'))
    return m.group(1) if m else None


def render_table(actions: list[dict], attr: str) -> str:
    lines = [f"  {attr} ["]
    for entry in actions:
        lines.append("    %{")
        fields = []
        for key in FIELD_ORDER:
            if key == "lvl":
                fields.append(('"lvl"', "0"))
            elif key in entry:
                fields.append((f'"{key}"', entry[key]))
        name = skill_name_of(entry.get("action", ""))
        if name:
            fields.append(('"skill_name"', f'"{name}"'))
        for i, (k, v) in enumerate(fields):
            lines.append(f"      {k} => {v}{',' if i < len(fields) - 1 else ''}")
        lines.append("    },")
    lines.append("  ]")
    return "\n".join(lines)


# ---- Elixir 改写 ----


def strip_attr(src: str, attr: str) -> str:
    """删掉 `  @attr []` 单行形式或 `  @attr [` ... `  ]` 多行块（连同其后一个空行）。

    两种形式都要认：生成器最初产出的是 `@actions []`（单行），迁移后才是多行块。
    单行分支必须排在前面，否则多行正则的 `.*?` 会跨块吞掉后面的内容。
    """
    pattern = re.compile(
        rf"^  {re.escape(attr)} \[\]\n\n?|^  {re.escape(attr)} \[.*?^  \]\n\n?",
        re.M | re.S,
    )
    return pattern.sub("", src)


def replace_tables(src: str, f_table: list[dict], w_table: list[dict], b_table: list[dict]) -> str:
    """把三张表整体重写在 `use Kantele.Combat.Skill` 之后（幂等：先删后插）。"""
    for attr in ("@actions", "@actions_weapon", "@actions_bad"):
        src = strip_attr(src, attr)

    blocks = [render_table(f_table, "@actions")]
    if w_table:
        blocks.append(render_table(w_table, "@actions_weapon"))
    if b_table:
        blocks.append(render_table(b_table, "@actions_bad"))
    combined = "\n\n".join(blocks) + "\n\n"

    anchor = re.search(r"^  use Kantele\.Combat\.Skill\n\n?", src, re.M)
    if not anchor:
        raise RuntimeError("找不到 `use Kantele.Combat.Skill`")
    return src[: anchor.end()] + combined + src[anchor.end() :]


def replace_behaviour(src: str, skill: str, cfg: dict) -> str:
    """重写 `def id()` 与 `def perform_list()` / `def exert_list()` 之间的整段。"""
    id_anchor = re.search(rf'^  def id\(\), do: "{re.escape(skill)}"\n', src, re.M)
    if not id_anchor:
        raise RuntimeError(f'找不到 `def id(), do: "{skill}"`')

    tail = re.search(r"^  @impl true\n  def (?:perform_list|exert_list)\(\)", src[id_anchor.end() :], re.M)
    if not tail:
        raise RuntimeError("找不到 perform_list / exert_list")

    start = id_anchor.end()
    end = start + tail.start()

    body = [cfg["enable"].strip("\n"), QUERY_TAIL_LITERATE if cfg["literate_bad"] else QUERY_TAIL]
    section = "\n" + "\n\n".join(body) + "\n\n"
    return src[:start] + section + src[end:]


def rewrite_moduledoc(src: str, skill: str, cfg: dict, counts: dict) -> str:
    lines = [
        f"武学实装「{skill}」（源 {skill}.c）",
        "",
        f"{cfg['cn']}（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是",
        "`action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以",
        "生成时整表丢失 —— 本文件已按源补回：",
        "",
        f"- `@actions`：`actionf`，空手时用（{counts['f']} 式）",
        f"- `@actions_weapon`：`actionw`，持械时用（{counts['w']} 式）",
    ]
    if counts["bad"]:
        lines.append(f"- `@actions_bad`：`actionbad`，识字的「胡乱使出」兜底（{counts['bad']} 式）")
    lines += [
        "",
        "LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`",
        "—— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，",
        "这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。",
        "",
    ]
    lines += cfg["notes"]
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


def migrate(skill: str, cfg: dict, apply: bool) -> str:
    lpc = os.path.join(MUD, "kungfu", "skill", f"{skill}.c")
    ex = os.path.join(REPO, "lib", "kantele", "combat", "skills", cfg["module"] + ".ex")
    if not (os.path.exists(lpc) and os.path.exists(ex)):
        raise RuntimeError(f"缺文件：{lpc} / {ex}")

    lpc_src = open(lpc, encoding="utf-8", errors="ignore").read()
    f_table = parse_table(lpc_src, "actionf")
    w_table = parse_table(lpc_src, "actionw")
    b_table = parse_table(lpc_src, "actionbad")
    if not f_table:
        raise RuntimeError(f"{skill}: 未解析到 actionf")

    src = open(ex, encoding="utf-8").read()

    src = rewrite_moduledoc(src, skill, cfg, {"f": len(f_table), "w": len(w_table), "bad": len(b_table)})
    src = replace_tables(src, f_table, w_table, b_table)
    src = replace_behaviour(src, skill, cfg)

    # 空行归一：拼接处偶尔会留下 2 个以上连续空行
    src = re.sub(r"\n{3,}", "\n\n", src)

    if apply:
        open(ex, "w", encoding="utf-8", newline="").write(src)
    return f"{skill}: actionf={len(f_table)} actionw={len(w_table)} actionbad={len(b_table)}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="真正写回文件（默认只干跑）")
    ap.add_argument("--dry-run", action="store_true", help="只打印统计，不写文件（默认行为）")
    args = ap.parse_args()

    rc = 0
    for skill, cfg in BEHAVIOUR.items():
        try:
            print(("[ok] " if args.apply else "[dry] ") + migrate(skill, cfg, args.apply))
        except Exception as exc:  # noqa: BLE001
            print(f"[fail] {skill}: {exc}")
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
