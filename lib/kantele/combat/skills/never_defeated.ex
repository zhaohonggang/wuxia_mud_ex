defmodule Kantele.Combat.Skills.NeverDefeated do
  @moduledoc """
  武学实装「never-defeated」（源 never-defeated.c）

  不败神功。LPC 的招式表变量名是 **`action_default`** / **`action_whip`**（既不叫 `action` 也不叫 `actionf`），
  `translate_skill.exs` 一个都不认，所以生成时两张表全丢 —— 本文件已按源补回：

  - `@actions`：`action_default`，空手或非鞭类武器用（11 式）
  - `@actions_weapon`：`action_whip`，鞭类武器用（5 式）

  分表维度是**武器的 `skill_type`** 而不是「有没有武器」：
  `switch (weapon ? weapon->query("skill_type") : "default")` —— `whip` 走
  `action_whip`，其余（含空手）走 `action_default`。`Fighter.weapon_skill_type`
  存原始 skill_type 供此判定。

  `valid_force` 恒 1（引擎默认即 true）。
  `valid_combo(combo) == "never-defeated"` 引擎暂无 combo 回调，未迁移。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N攻势忽缓而不疏，似剑法又似刀法，捉摸不定向$n慢慢推去",
      "force" => 410,
      "attack" => 150,
      "parry" => 120,
      "dodge" => 70,
      "damage" => 225,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N手中的$w突焕气象森严，便似千军万马奔驰而来，横扫$n",
      "force" => 410,
      "attack" => 160,
      "parry" => 110,
      "dodge" => 85,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "擦伤"
    },
    %{
      "action" => "$N举起手中的$w，对着$n乱砍乱砸，没有半点章法",
      "force" => 430,
      "attack" => 170,
      "parry" => 130,
      "dodge" => 70,
      "damage" => 205,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N运用$w幻化做一个一个圆圈，似乎要将$n包围",
      "force" => 425,
      "attack" => 160,
      "parry" => 125,
      "dodge" => 65,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N含笑回转$w，伸手一指，颇得拈花指之意，点向$n的$l",
      "force" => 530,
      "attack" => 176,
      "parry" => 115,
      "dodge" => 75,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N长叹一声，将$w随手递出，连自己也不知道也攻向哪里",
      "force" => 440,
      "attack" => 170,
      "parry" => 125,
      "dodge" => 80,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N神色凝重，$w上劈下切左右横扫，挟雷霆万钧之势逼往$n",
      "force" => 410,
      "attack" => 160,
      "parry" => 120,
      "dodge" => 95,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N运起$w，就如狂风暴雨，霍霍亮光中反攻$n的$l，尝试逼$n自守",
      "force" => 420,
      "attack" => 150,
      "parry" => 135,
      "dodge" => 95,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N突然如痴如狂，手中的$w猛然向$n周身乱刺乱削",
      "force" => 410,
      "attack" => 165,
      "parry" => 125,
      "dodge" => 85,
      "damage" => 235,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N将$w随手一摆，$n反而自己向$w撞将上来，神兵之威，实人所难测",
      "force" => 430,
      "attack" => 180,
      "parry" => 110,
      "dodge" => 75,
      "damage" => 225,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N手中的$w忽起剑势，却似或刀法，又夹杂棍杖之意，令$n眩目",
      "force" => 420,
      "attack" => 175,
      "parry" => 130,
      "dodge" => 85,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N攻势忽缓而不疏，$w变化无常，捉摸不定向$n慢慢卷去",
      "force" => 430,
      "attack" => 180,
      "parry" => 115,
      "dodge" => 75,
      "damage" => 225,
      "lvl" => 0,
      "damage_type" => "擦伤"
    },
    %{
      "action" => "$N手中的$w突焕气象森严，便似千军万马奔驰而来，$w就如棍棒一般横扫$n",
      "force" => 410,
      "attack" => 160,
      "parry" => 125,
      "dodge" => 85,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "擦伤"
    },
    %{
      "action" => "$N卷起手中的$w，就如铁锤一般对着$n乱砍乱砸，没有半点章法",
      "force" => 440,
      "attack" => 175,
      "parry" => 125,
      "dodge" => 80,
      "damage" => 205,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N运用$w幻化做一个一个圆圈，似乎要将$n团团包围",
      "force" => 425,
      "attack" => 160,
      "parry" => 125,
      "dodge" => 65,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N含笑回转$w，伸手一指，颇得拈花指之意，点向$n的$l",
      "force" => 510,
      "attack" => 180,
      "parry" => 120,
      "dodge" => 70,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @impl true
  def id(), do: "never-defeated"

  @impl true
  def valid_enable(usage) do
    usage in ["sword", "blade", "dagger", "staff", "hammer", "club", "whip", "dodge", "parry", "force", "throwing"]
  end

  # LPC `valid_learn(object me)`（源 never-defeated.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      stats.combat_exp < 3000000 ->
        {:error, "你觉得不败神功深奥之极，凭自己的战斗经验一时间难以领会。\n"}

      Stats.skill(stats, "martial-cognize") < 50 ->
        {:error, "你觉得不败神功过于深奥，以自己的武学修养全然无法明白。\n"}

      personality != "狡黠多变" ->
        {:error, "你学了半天，发现不败神功古怪的紧，不合常理，根本无法领会。"}

      Stats.int(stats) < 22 ->
        {:error, "你觉得不败神功过于深奥，绝非自己的智力所能理解。\n"}

      (gender == "无性") and (lvl > 239) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的不败神功。\n"}

      Stats.skill(stats, "martial-cognize") < lvl ->
        {:error, "你觉得自己的武学修养有限，难以领会更高深的不败神功。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你对基本内功的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "parry") < lvl ->
        {:error, "你对基本招架的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "dodge") < lvl ->
        {:error, "你对基本轻功的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你对基本剑法的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你对基本刀法的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你对基本鞭法的理解还不够，无法继续领会更高深的不败神功。\n"}

      Stats.skill(stats, "throwing") < lvl ->
        {:error, "你对基本暗器的理解还不够，无法继续领会更高深的不败神功。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
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
  def weapon_actions(), do: @actions_weapon

  @impl true
  def perform_list() do
    %{
      "juemie" => Kantele.Combat.Skills.Performs.NeverDefeated.Juemie,
      "lei" => Kantele.Combat.Skills.Performs.NeverDefeated.Lei,
      "po" => Kantele.Combat.Skills.Performs.NeverDefeated.Po,
      "tianhua" => Kantele.Combat.Skills.Performs.NeverDefeated.Tianhua,
      "wanli" => Kantele.Combat.Skills.Performs.NeverDefeated.Wanli,
      "yuce" => Kantele.Combat.Skills.Performs.NeverDefeated.Yuce
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.NeverDefeated.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.NeverDefeated.Shield
    }
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil
end
