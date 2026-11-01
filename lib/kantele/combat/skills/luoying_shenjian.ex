defmodule Kantele.Combat.Skills.LuoyingShenjian do
  @moduledoc """
  落英神剑（对照 `kungfu/skill/luoying-shenjian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luoying_shenjian/`。

  学习门槛 `valid_learn/2`（force>=30 / max_neili>=250 / sword>=luoying-shenjian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 41，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"，valid_learn 与 practice_skill 均检查）由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使一招「落英缤纷」，身形向上飘起，手中$w幻出万点剑花撒向$n",
      "force" => 100,
      "parry" => 15,
      "damage" => 40,
      "lvl" => 0,
      "skill_name" => "落英缤纷"
    },
    %{
      "action" => "$N一式「人面桃花」，左手向$n面门一晃，右手$w抖出几朵剑花刺向$n",
      "force" => 150,
      "parry" => 20,
      "damage" => 50,
      "lvl" => 20,
      "skill_name" => "人面桃花"
    },
    %{
      "action" => "$N身形一转，手中$w望空一指，一式「急风骤雨」幻出满天剑影刺向$n$l",
      "force" => 180,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 40,
      "skill_name" => "急风骤雨"
    },
    %{
      "action" => "$N身形飘然而起，悠然一式「江城飞花」，手中$w若有若无刺向$n的$l",
      "force" => 210,
      "dodge" => 30,
      "damage" => 70,
      "lvl" => 60,
      "skill_name" => "江城飞花"
    },
    %{
      "action" => "$N纵起丈余，一招「万花齐落」手中$w舞成一个光球罩向$n的$l",
      "force" => 250,
      "dodge" => 35,
      "damage" => 80,
      "lvl" => 80,
      "skill_name" => "万花齐落"
    },
    %{
      "action" => "$N一声大喝使出「漫天花雨」，手中$w幻出漫天花瓣，迅若奔雷射向$n的$l",
      "force" => 280,
      "dodge" => 35,
      "damage" => 90,
      "lvl" => 100,
      "skill_name" => "漫天花雨"
    },
    %{
      "action" => "$N轻叹一声，手中$w怀中一抱，一式「落花无意」，$w顿时飘然飞向$n的$l",
      "force" => 300,
      "dodge" => 30,
      "damage" => 110,
      "lvl" => 120,
      "skill_name" => "落花无意"
    }
  ]

  @impl true
  def id(), do: "luoying-shenjian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=30 / max_neili>=250 / sword>=luoying-shenjian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 41（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 41}

  # LPC `valid_learn(object me)`（源 luoying-shenjian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能学习剑法。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，不能练落英神剑。\n"}

      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力修为不够，不能练落英神剑。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的落英神剑。\n"}

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
    %{"sui" => Kantele.Combat.Skills.Performs.LuoyingShenjian.Sui}
  end
  def actions(), do: @actions

end
