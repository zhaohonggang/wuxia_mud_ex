defmodule Kantele.Combat.Skills.FumoJian do
  @moduledoc """
  伏魔剑（对照 `kungfu/skill/fumo-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fumo_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=250，本版以 force>=50 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一式「穿云势」，剑锋平指，剑势如风，一气呵成横扫$n的腰间",
      "force" => 90,
      "attack" => 15,
      "dodge" => -10,
      "parry" => 20,
      "damage" => 25,
      "lvl" => 0,
      "skill_name" => "穿云势"
    },
    %{
      "action" => "$N向前跃上一步，左手剑诀，右手$w使出一式「破雾势」直刺$n的$l",
      "force" => 130,
      "attack" => 30,
      "dodge" => -10,
      "parry" => 30,
      "damage" => 30,
      "lvl" => 40,
      "skill_name" => "破雾势"
    },
    %{
      "action" => "$N拔步挺腰，一式「推山势」，手中$w沉滞无比，缓缓挥剑撞向$n的$l",
      "force" => 170,
      "attack" => 40,
      "dodge" => 5,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 60,
      "skill_name" => "推山势"
    },
    %{
      "action" => "$N一式「搅海势」，$w自左而右划出一个大弧，平平地向$n的$l挥去",
      "force" => 190,
      "attack" => 50,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 40,
      "lvl" => 80,
      "skill_name" => "搅海势"
    },
    %{
      "action" => "$N回身拧腰，右手虚抱成圆，一式「开天势」，$w中宫直进，刺向$n的胸口",
      "force" => 240,
      "attack" => 60,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 50,
      "lvl" => 100,
      "skill_name" => "开天势"
    },
    %{
      "action" => "$N一式「劈地势」，$w从上至下猛劈，剑锋直出，挟爆裂之声骤然斩向$n的$l",
      "force" => 260,
      "attack" => 65,
      "dodge" => 5,
      "parry" => 50,
      "damage" => 60,
      "lvl" => 120,
      "skill_name" => "劈地势"
    },
    %{
      "action" => "$N运气施出「雷针势」，$w剑尖逼出一道青芒，闪电般破空射向$n的$l",
      "force" => 280,
      "attack" => 70,
      "dodge" => 5,
      "parry" => 52,
      "damage" => 75,
      "lvl" => 140,
      "skill_name" => "雷针势"
    },
    %{
      "action" => "$N双腿半屈半蹲，一式「龙吞势」，剑尖划出无数圆圈，狂风骤起，笼罩天地",
      "force" => 310,
      "attack" => 75,
      "dodge" => 5,
      "parry" => 64,
      "damage" => 90,
      "lvl" => 150,
      "skill_name" => "龙吞势"
    }
  ]

  @impl true
  def id(), do: "fumo-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fumo-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的伏摩剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"foxin" => Kantele.Combat.Skills.Performs.FumoJian.Foxin}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end
