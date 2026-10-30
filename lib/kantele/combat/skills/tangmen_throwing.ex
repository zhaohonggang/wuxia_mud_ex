defmodule Kantele.Combat.Skills.TangmenThrowing do
  @moduledoc """
  唐门暗器（对照 `kungfu/skill/tangmen-throwing.c`）

  暗器载体：`valid_enable("throwing")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/tangmen_throwing/`。

  学习门槛 `valid_learn/2`（force>=60 / dodge>=60 / throwing>=50 / dex>=30 / str>=30 / int>=28 / throwing>=self）与
  练招消耗 `practice_cost`（qi 50 / neili 50）已按 LPC 迁移（2026-10-30）。招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "tangmen-throwing"

  @impl true
  def valid_enable(usage), do: usage in ["throwing", "parry"]

  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功心法火候不够，无法学唐门暗器。\n"}

      Stats.skill(stats, "dodge") < 60 ->
        {:error, "你的轻功火候不够，无法领悟唐门暗器。\n"}

      Stats.skill(stats, "throwing") < 50 ->
        {:error, "你的暗器技能不够娴熟，无法领悟唐门暗器。\n"}

      Stats.dex(stats) < 30 ->
        {:error, "你的身法不够灵巧，无法学习唐门暗器。\n"}

      Stats.str(stats) < 30 ->
        {:error, "你的臂力不够，多练练本门的基本手法吧。\n"}

      Stats.int(stats) < 28 ->
        {:error, "你的悟性不够，无法领悟唐门暗器秘诀。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，难以领会更高深的唐门暗器。\n"}

      true ->
        :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 50"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 50}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "biao" => Kantele.Combat.Skills.Performs.TangmenThrowing.Biao,
      "hua" => Kantele.Combat.Skills.Performs.TangmenThrowing.Hua,
      "qian" => Kantele.Combat.Skills.Performs.TangmenThrowing.Qian,
      "san" => Kantele.Combat.Skills.Performs.TangmenThrowing.San
    }
  end
end
