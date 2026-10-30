defmodule Kantele.Combat.Skills.MantianhuayuZhen do
  @moduledoc """
  满天花雨阵（对照 `kungfu/skill/mantianhuayu-zhen.c`）

  阵法/内功载体：`valid_enable("force")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/mantianhuayu_zhen/`。

  学习门槛 `valid_learn/2` 与练招消耗 `practice_cost` 已按 LPC 迁移（2026-10-30）。
  招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "mantianhuayu-zhen"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry"]

  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功心法火候不够，无法学满天花雨掷金针。\n"}

      Stats.skill(stats, "dodge") < 60 ->
        {:error, "你的轻功火候不够，无法领悟满天花雨掷金针。\n"}

      Stats.dex(stats) < 25 ->
        {:error, "你的身法不够灵巧，无法领悟满天花雨掷金针。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，难以领会更高深的满天花雨掷金针。\n"}

      true ->
        :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 45"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 45}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zheng" => Kantele.Combat.Skills.Performs.MantianhuayuZhen.Zheng}
  end
end
