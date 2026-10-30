defmodule Kantele.Combat.Skills.ShunvJian do
  @moduledoc """
  淑女剑法（对照 `kungfu/skill/shunv-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/shunv_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / dodge>=40 / dex>=24 / sword>=shunv-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 40 / neili 34，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "shunv-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / dodge>=40 / dex>=24 / sword>=shunv-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模；dex 走 query_dex 基础属性）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力修为不够，无法修习淑女剑法。\n"}

      Stats.skill(stats, "dodge") < 40 ->
        {:error, "你的基本轻功火候太浅，无法修习淑女剑法。\n"}

      Stats.dex(stats) < 24 ->
        {:error, "你的身法还不够灵活，无法修习淑女剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的淑女剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 40 / neili 34（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 34}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ning" => Kantele.Combat.Skills.Performs.ShunvJian.Ning}
  end
end
