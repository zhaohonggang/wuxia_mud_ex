defmodule Kantele.Combat.Skills.FengleiPanfa do
  @moduledoc """
  风雷盘法（对照 `kungfu/skill/fenglei-panfa.c`）

  锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fenglei_panfa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=800，本版以 force>=120 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「秋风起夕」，右手立掌而出，左手单臂抡起$w，夹杂着阵阵风声向$n$l砸去",
      "force" => 320,
      "attack" => 27,
      "dodge" => -10,
      "parry" => 40,
      "damage" => 62,
      "lvl" => 0,
      "skill_name" => "秋风起夕"
    },
    %{
      "action" => "$N将手中$w抛上半空，跃起一掌砸在$w上，这式「风吹云散」有如流星坠地，直轰$n",
      "force" => 260,
      "attack" => 38,
      "dodge" => -20,
      "parry" => 45,
      "damage" => 66,
      "lvl" => 40,
      "skill_name" => "风吹云散"
    },
    %{
      "action" => "凭空闪出一道雪白的光幕，光电闪烁中$w挟「雷雨交加」的无上劲力，从$N手中飞出砍向$n的$l",
      "force" => 300,
      "attack" => 43,
      "dodge" => -20,
      "parry" => 47,
      "damage" => 70,
      "lvl" => 80,
      "skill_name" => "雷雨交加"
    },
    %{
      "action" => "$N双眼磕闭，全身衣物却在内劲冲击下涨如气球，那$w在这「八方云涌」的推动下，向$n缓缓压来",
      "force" => 340,
      "attack" => 51,
      "dodge" => 5,
      "parry" => 50,
      "damage" => 75,
      "lvl" => 120,
      "skill_name" => "八方云涌"
    },
    %{
      "action" => "$N双手画圈，光幕宛如一轮明月，将$P笼罩，这「九天雷动」的劲力带着$w以排山倒海之势飞旋而出",
      "force" => 380,
      "attack" => 55,
      "dodge" => -10,
      "parry" => 55,
      "damage" => 80,
      "lvl" => 160,
      "skill_name" => "九天雷动"
    }
  ]

  @impl true
  def id(), do: "fenglei-panfa"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fenglei-panfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "hammer") < lvl ->
        {:error, "你的基本锤法水平有限，无法领会更高深的风雷盘法。\n"}

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
    %{"fenglei" => Kantele.Combat.Skills.Performs.FengleiPanfa.Fenglei}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end
