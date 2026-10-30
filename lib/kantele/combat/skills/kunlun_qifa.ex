defmodule Kantele.Combat.Skills.KunlunQifa do
  @moduledoc """
  昆仑气法（对照 `kungfu/skill/kunlun-qifa.c`）

  内功载体：`valid_enable("force")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/kunlun_qifa/`。

  学习门槛 `valid_learn/2`（throwing>=50 / throwing>=kunlun-qifa）与
  练招消耗 `practice_cost`（LPC 扣 qi 70 / neili 50，须持暗器）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持暗器（weapon skill_type=="throwing"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "kunlun-qifa"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry"]

  # LPC valid_learn 要求 throwing>=50 / throwing>=kunlun-qifa（须持暗器检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "throwing") < 50 ->
        {:error, "你的暗器技能不够娴熟。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，难以领会更精妙的昆仑器法。\n"}

      true ->
        :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 50（须持暗器，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"liu" => Kantele.Combat.Skills.Performs.KunlunQifa.Liu}
  end
end
