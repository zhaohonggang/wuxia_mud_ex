defmodule Kantele.Combat.Skills.PanlongSuo do
  @moduledoc """
  盘龙索法（对照 `kungfu/skill/panlong-suo.c`）

  鞭/索法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/panlong_suo/`。

  学习门槛 `valid_learn/2`（max_neili>=800 / force>=120 / whip>=80 / whip>=self）与练招消耗
  `practice_cost`（qi 75 / neili 85）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须持鞭」检查由 practice 流程把关；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "panlong-suo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 85}

  # LPC `valid_learn(object me)`（源 panlong-suo.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力修为不足，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "whip") < 80 ->
        {:error, "你的基本鞭法火候太浅，无法修炼霹雳盘龙索。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的霹雳盘龙索。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.PanlongSuo.Chan,
      "sha" => Kantele.Combat.Skills.Performs.PanlongSuo.Sha
    }
  end
end
