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

  alias Kantele.Character.Stats

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

  # LPC `valid_learn(object me)`（源 zhonghua-aojue.c）
  # 末段 `for (usage_skills)` 循环按数组顺序展开为 6 门。
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    personality = personality_of(character)
    gender = gender_of(character)
    cognize = Stats.skill(stats, "martial-cognize")

    cond do
      personality != "光明磊落" ->
        {:error, "中华傲决正大恢弘，气度俨然，你怎么也学不得神似。\n"}

      stats.combat_exp < 3_000_000 ->
        {:error, "你觉得中华傲决深奥之极，凭自己的战斗经验一时间难以领会。\n"}

      cognize < 300 ->
        {:error, "你觉得中华傲决过于深奥之极，以自己的武学修养全然无法明白。\n"}

      Stats.int(stats) < 35 ->
        {:error, "你觉得中华傲决过于艰深，难以理解。\n"}

      Stats.con(stats) < 31 ->
        {:error, "依照你的根骨无法修炼中华傲决。\n"}

      gender == "无性" and lvl > 219 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的中华傲决。\n"}

      cognize < lvl ->
        {:error, "你觉得自己的武学修养有限，难以领会更高深的中华傲决。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你对基本拳脚的理解还不够，无法继续领会更高深的中华傲决。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你对基本掌法的理解还不够，无法继续领会更高深的中华傲决。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你对基本剑法的理解还不够，无法继续领会更高深的中华傲决。\n"}

      Stats.skill(stats, "dodge") < lvl ->
        {:error, "你对基本轻功的理解还不够，无法继续领会更高深的中华傲决。\n"}

      Stats.skill(stats, "parry") < lvl ->
        {:error, "你对基本招架的理解还不够，无法继续领会更高深的中华傲决。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你对基本内功的理解还不够，无法继续领会更高深的中华傲决。\n"}

      true ->
        :ok
    end
  end

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

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"
end
