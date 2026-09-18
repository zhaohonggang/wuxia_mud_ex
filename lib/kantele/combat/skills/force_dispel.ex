defmodule Kantele.Combat.Skills.Force.Dispel do
  @moduledoc """
  排除异常（对照 `kungfu/skill/force/dispel.c`）

  清除自身或目标的异常状态：neili>=300（自身）/neili>=250（他人）；
  自身扣 100，他人扣 250；清除 target.query_condition() 所有条件。
  简化版：直接清除 target.meta.conditions map。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"dispel" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/dispel",
      kind: :exert,
      gates: [
        {:custom, &gate_self_or_target/1, ""},
        {:custom, &gate_neili/1, "你的内力不足，无法运满一个周天。\n"},
        {:custom, &gate_not_fighting_target/1, "对方正在打架，还是等他打完了再说吧。\n"},
        {:custom, &gate_not_busy_target/1, "对方现在正忙着呢，等他空了些再说吧。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_dispel/1}
      ],
      busy: 0,
      message: fn ctx ->
        if ctx.target == ctx.character do
          "$N深吸一口气，又缓缓的吐了出来。\n你默运#{to_chinese(ctx.stats.mapped.force)}，开始排除身体中的异常症状。\n"
        else
          "$N深吸一口气，将手掌粘到#{ctx.target.name}的背后。\n你默运#{to_chinese(ctx.stats.mapped.force)}，开始帮助#{
            ctx.target.name
          }排除身体中的异常症状。\n#{ctx.target.name}正在运功将你身体中的异常症状尽数排除。\n"
        end
      end
    }
  end

  defp gate_self_or_target(_ctx), do: :ok

  defp gate_neili(ctx) do
    cost = if ctx.target == ctx.character, do: 100, else: 250
    if ctx.character.meta.vitals.neili >= cost, do: :ok, else: {:error, "你的内力不足，无法运满一个周天。\n"}
  end

  defp gate_not_fighting_target(ctx) do
    if ctx.target == ctx.character || not ctx.target.meta.combat.busy > 0 ||
         Enum.empty?(ctx.target.meta.combat.enemies),
       do: :ok,
       else: {:error, "对方正在打架，还是等他打完了再说吧。\n"}
  end

  defp gate_not_busy_target(ctx) do
    if ctx.target == ctx.character || not ctx.target.meta.combat.busy > 0,
      do: :ok,
      else: {:error, "对方现在正忙着呢，等他空了些再说吧。\n"}
  end

  defp effect_dispel(state) do
    char = state.character
    target = state.target

    cost = if target == char, do: 100, else: 250
    new_vitals = %{char.meta.vitals | neili: char.meta.vitals.neili - cost}

    new_target =
      if target.meta.conditions && map_size(target.meta.conditions) > 0 do
        %{target | meta: %{target.meta | conditions: %{}}}
      else
        target
      end

    new_char = %{char | meta: %{char.meta | vitals: new_vitals}}

    %{state | character: new_char, target: new_target}
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      _ -> name
    end
  end
end
