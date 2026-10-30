defmodule Kantele.Combat.Skills.PidiShenzhen do
  @moduledoc """
  辟地神针（对照 `kungfu/skill/pidi-shenzhen.c`）

  暗器/针法载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/pidi_shenzhen/`。

  学习门槛 `valid_learn/2` 与练招消耗 `practice_cost` 已按 LPC 迁移（2026-10-30）。
  招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "pidi-shenzhen"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "throwing") < 40 ->
        {:error, "你的暗器技能不够娴熟。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，难以领会更精妙的辟地神针。\n"}

      true ->
        :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 70 / neili 50"
  @impl true
  def practice_cost(), do: %{qi: 70, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"huan" => Kantele.Combat.Skills.Performs.PidiShenzhen.Huan}
  end
end
