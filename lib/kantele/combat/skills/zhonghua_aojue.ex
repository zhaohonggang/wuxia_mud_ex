defmodule Kantele.Combat.Skills.ZhonghuaAojue do
  @moduledoc """
  武学实装「zhonghua-aojue」（源 zhonghua-aojue.c）

  中华傲诀（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是
  `action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以
  生成时整表丢失 —— 本文件已按源补回：

  - `@actions`：`actionf`，空手时用（6 式）
  - `@actions_weapon`：`actionw`，持械时用（6 式）

  LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`
  —— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，
  这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。

  `valid_force` 恒 1（引擎默认即 true）；`valid_combo` / `double_attack` 引擎无对应回调，未迁移。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N跨出一步，一指缓缓戳向$n的$l，笼罩了方圆数寸的范围",
      "force" => 500,
      "attack" => 150,
      "parry" => 88,
      "dodge" => 90,
      "damage" => 170,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声震喝，随即一掌劈出，中途却忽然一指刺向$n的$l",
      "force" => 510,
      "attack" => 165,
      "parry" => 90,
      "dodge" => 110,
      "damage" => 160,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N疾走数步，左掌掌劈向$n的肩头，右手食却点向$n的$l，",
      "force" => 515,
      "attack" => 155,
      "parry" => 85,
      "dodge" => 85,
      "damage" => 175,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N深吸一口气，步步进逼，双掌连环劈向$n的$l",
      "force" => 520,
      "attack" => 140,
      "parry" => 90,
      "dodge" => 80,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身体原地不动，双掌平推，一股掌力凌空奔$n而去",
      "force" => 535,
      "attack" => 135,
      "parry" => 95,
      "dodge" => 80,
      "damage" => 170,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N足下暗和八卦，步法变幻莫测，左右掌连翻出击，攻向$n",
      "force" => 500,
      "attack" => 150,
      "parry" => 115,
      "dodge" => 85,
      "damage" => 165,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N跨出一步，手中$w缓缓刺向$n，笼罩了方圆数寸的范围",
      "force" => 450,
      "attack" => 170,
      "parry" => 110,
      "dodge" => 100,
      "damage" => 240,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声震喝，手中的$w随即横扫$n，中途却忽然刺向$n的$l",
      "force" => 460,
      "attack" => 165,
      "parry" => 110,
      "dodge" => 80,
      "damage" => 250,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N疾走数步，左掌掌劈向$n的肩头，右手的$w却点向$n的$l，",
      "force" => 480,
      "attack" => 175,
      "parry" => 100,
      "dodge" => 85,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N深吸一口气，步步进逼，手中的$w连环刺向$n的$l",
      "force" => 475,
      "attack" => 180,
      "parry" => 120,
      "dodge" => 75,
      "damage" => 275,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身体原地不动，手中的$w一划，一股内力凌空奔$n而去",
      "force" => 480,
      "attack" => 175,
      "parry" => 125,
      "dodge" => 80,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N足下暗合八卦，步法变幻莫测，手中的$w化作数道光芒，攻向$n",
      "force" => 490,
      "parry" => 110,
      "dodge" => 160,
      "damage" => 320,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @impl true
  def id(), do: "zhonghua-aojue"

  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "strike", "sword", "dodge", "parry", "force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, nil, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, attacker, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "持械招式表（LPC `actionw`）"
  def weapon_actions(), do: @actions_weapon

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.ZhonghuaAojue.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.ZhonghuaAojue.Shield
    }
  end
end
