defmodule Kantele.Combat.Skills.JinsheJian do
  @moduledoc """
  金蛇剑法（对照 `kungfu/skill/jinshe-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinshe_jian/`。

  学习门槛 `valid_learn/2`（int>=33 / dex>=33 / max_neili>=4000 / force>=200 / dodge>=240 / sword>=220 / martial-cognize>=220 / sword>=jinshe-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 70 / neili 70，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关；LPC 原文 `character`（alignment）门控为注释态，本仓未建模。招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jinshe-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 int>=33 / dex>=33 / max_neili>=4000 / force>=200 / dodge>=240 / sword>=220 / martial-cognize>=220 / sword>=jinshe-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关；alignment 注释门控未建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.int(stats) < 33 ->
        {:error, "你先天悟性不足，无法领悟金蛇剑法。\n"}

      Stats.dex(stats) < 33 ->
        {:error, "你先天身法不足，无法修习金蛇剑法。\n"}

      not is_nil(max_neili) and max_neili < 4000 ->
        {:error, "你的内力修为不够，没有办法练金蛇剑法。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的基本内功火候不够，没有办法练金蛇剑法。\n"}

      Stats.skill(stats, "dodge") < 240 ->
        {:error, "你的基本轻功火候不够，没有办法练金蛇剑法。\n"}

      Stats.skill(stats, "sword") < 220 ->
        {:error, "你的基本剑法火候不够，没有办法练金蛇剑法。\n"}

      Stats.skill(stats, "martial-cognize") < 220 ->
        {:error, "你的武学修养不足，没有办法领悟金蛇剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的金蛇剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 70（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 70}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "kun" => Kantele.Combat.Skills.Performs.JinsheJian.Kun,
      "shi" => Kantele.Combat.Skills.Performs.JinsheJian.Shi,
      "wan" => Kantele.Combat.Skills.Performs.JinsheJian.Wan
    }
  end
end
