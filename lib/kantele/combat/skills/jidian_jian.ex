defmodule Kantele.Combat.Skills.JidianJian do
  @moduledoc """
  疾电剑法（对照 `kungfu/skill/jidian-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jidian_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=200、dodge>=60、dex>=25、
    sword>=jidian-jian，本版以 force>=50 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N纵身跃起手中$w轻挥，一招「风平浪静」，斩向$n后颈",
      "force" => 80,
      "attack" => 35,
      "dodge" => 30,
      "parry" => 10,
      "damage" => 75,
      "lvl" => 0,
      "skill_name" => "风平浪静"
    },
    %{
      "action" => "$N手中$w连话三个弧形，一招「风起云涌」，向$n的右臂齐肩斩落",
      "force" => 100,
      "attack" => 45,
      "dodge" => 45,
      "parry" => 22,
      "damage" => 88,
      "lvl" => 30,
      "skill_name" => "风起云涌"
    },
    %{
      "action" => "$N轻吁一声，飞身一跃而起，一招「风卷残云」，连续向$n刺出数剑",
      "force" => 120,
      "attack" => 51,
      "dodge" => 53,
      "parry" => 18,
      "damage" => 95,
      "lvl" => 60,
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N仰天一声清啸，斜行向前，一招「风流云散」，$w横削直击，击向$n的$l",
      "force" => 150,
      "attack" => 58,
      "dodge" => 52,
      "parry" => 20,
      "damage" => 110,
      "lvl" => 90,
      "skill_name" => "风流云散"
    }
  ]

  @impl true
  def id(), do: "jidian-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jidian-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够，无法修习疾电剑法。\n"}

      Stats.skill(stats, "dodge") < 60 ->
        {:error, "你的轻功火候太浅，无法修习疾电剑法。\n"}

      Stats.query_dex(stats) < 25 ->
        {:error, "你的身法还不够灵活，无法修习疾电剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的疾电剑法。\n"}

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
    %{"dian" => Kantele.Combat.Skills.Performs.JidianJian.Dian}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end
