defmodule Kantele.Combat.Skills.SuxinJian do
  @moduledoc """
  素心剑法（对照 `kungfu/skill/suxin-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/suxin_jian/`。

  学习门槛 `valid_learn/2`（gender=="女性" / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 60，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「玉女素心剑只有女性能练」性别门走 `meta.env[:gender]`（缺省为"男性"）；
  须持剑（weapon skill_type=="sword"）检查由 practice 流程把关。招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "suxin-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 gender=="女性" / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      gender != "女性" ->
        {:error, "玉女素心剑只有女性能练。\n"}

      Stats.int(stats) < 28 ->
        {:error, "你的先天悟性不够，无法学习玉女素心剑。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不到，无法学习玉女素心剑。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法水平太低，无法学习玉女素心剑。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力修为不够，不能学习玉女素心剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的玉女素心剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 60（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "he" => Kantele.Combat.Skills.Performs.SuxinJian.He,
      "lian" => Kantele.Combat.Skills.Performs.SuxinJian.Lian
    }
  end
end
