defmodule Kantele.Combat.Skills.QiankunJian do
  @moduledoc """
  乾坤剑法（对照 `kungfu/skill/qiankun-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiankun_jian/`。

  学习门槛 `valid_learn/2`（force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 65 / neili 70，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "qiankun-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功火候不到，无法学习乾坤神剑。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力太差，无法学习乾坤神剑。\n"}

      Stats.skill(stats, "sword") < 150 ->
        {:error, "你的基本剑法火候太浅，无法学习乾坤神剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的乾坤神剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 70（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "ni" => Kantele.Combat.Skills.Performs.QiankunJian.Ni,
      "qian" => Kantele.Combat.Skills.Performs.QiankunJian.Qian,
      "riyue" => Kantele.Combat.Skills.Performs.QiankunJian.Riyue
    }
  end
end
