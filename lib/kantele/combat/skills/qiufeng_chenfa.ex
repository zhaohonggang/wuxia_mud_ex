defmodule Kantele.Combat.Skills.QiufengChenfa do
  @moduledoc """
  秋风尘法（对照 `kungfu/skill/qiufeng-chenfa.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiufeng_chenfa/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / force>=60 / whip>=self）与练招消耗
  `practice_cost`（qi 35 / neili 10）已按 LPC 迁移（2026-10-30）。须持拂尘检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N端坐不动，一招「秋风拂叶」，手中$w带着一股劲风，击向$n的脸颊",
      "force" => 40,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "skill_name" => "秋风拂叶"
    },
    %{
      "action" => "$N单臂一挥，一招「玉带围腰」，手中$w直绕向$n的身后",
      "force" => 70,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 20,
      "skill_name" => "玉带围腰"
    },
    %{
      "action" => "$N身形一转，一招「流云断川」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 80,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 40,
      "skill_name" => "流云断川"
    },
    %{
      "action" => "$N力贯尘梢，一招「春风化雨」，手中$w舞出满天幻影，排山倒海般扫向$n全身",
      "force" => 100,
      "dodge" => 15,
      "damage" => 50,
      "lvl" => 50,
      "skill_name" => "春风化雨"
    },
    %{
      "action" => "$N忽的向前一跃，一招「野马分鬃」，手中$w分击$n左右",
      "force" => 110,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 60,
      "skill_name" => "野马分鬃"
    },
    %{
      "action" => "$N慢步上前，一招「竹影扫阶」，手中$w缓缓罩向$n前胸",
      "force" => 130,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 70,
      "skill_name" => "竹影扫阶"
    }
  ]

  @impl true
  def id(), do: "qiufeng-chenfa"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 10（须持拂尘，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 10}

  # LPC `valid_learn(object me)`（源 qiufeng-chenfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条拂尘才能练尘法。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不足，没有办法练秋风尘法, 多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法火候不足，难以领会更高深的秋风尘法。\n"}

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
    %{"chan" => Kantele.Combat.Skills.Performs.QiufengChenfa.Chan}
  end
  def actions(), do: @actions

end
