defmodule Kantele.Combat.Skills.LongxingJian do
  @moduledoc """
  龙形剑法（对照 `kungfu/skill/longxing-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/longxing_jian/`。

  学习门槛 `valid_learn/2`（str>=24 / int>=30 / max_neili>=2000 / hunyuan-yiqi>=200 / sword>=200 / sword>=longxing-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 30 / neili 40）已按 LPC 迁移（2026-10-30）。
  LPC `practice_skill` 不检查武器（无持械门控）；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "longxing-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff", "parry"]

  # LPC valid_learn 要求 str>=24 / int>=30 / max_neili>=2000 / hunyuan-yiqi>=200 / sword>=200 / sword>=longxing-jian
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.str(stats) < 24 ->
        {:error, "你先天臂力不足。\n"}

      Stats.int(stats) < 30 ->
        {:error, "你先天悟性不足。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力修为不够，难以修炼龙形剑法。\n"}

      Stats.skill(stats, "hunyuan-yiqi") < 200 ->
        {:error, "你的内功火候太浅，难以修炼龙形剑法。\n"}

      Stats.skill(stats, "sword") < 200 ->
        {:error, "你的剑法根基不足，难以修炼龙形剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的龙形剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 30 / neili 40（LPC 原文不查武器）"
  @impl true
  def practice_cost(), do: %{qi: 30, neili: 40}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "xian" => Kantele.Combat.Skills.Performs.LongxingJian.Xian,
      "kong" => Kantele.Combat.Skills.Performs.LongxingJian.Kong
    }
  end
end
