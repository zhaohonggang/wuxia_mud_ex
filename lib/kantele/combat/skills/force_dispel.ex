defmodule Kantele.Combat.Skills.Force.Dispel do
  @moduledoc """
  排除异常（对照 `kungfu/skill/force/dispel.c`）

  自我版：清除自身全部异常状态；需 neili>=300，扣 neili 100，busy 1+random(2)。

  LPC 原可对他人运功（neili>=250、扣 250、校验目标战斗/忙碌/条件）；
  本引擎 exert 无目标侧 -> TODO(migrate): 他人路径待目标侧结算接入后再补。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/dispel",
      kind: :exert,
      gates: [
        {:neili_min, 300, "你的内力不足，无法运满一个周天。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_dispel/1}
      ],
      busy: {:random, 1, 3},
      message: fn ctx ->
        force = to_chinese(Map.get(ctx.stats.mapped, "force") || "force")
        "$N深吸一口气，又缓缓的吐了出来。\n你默运#{force}，开始排除身体中的异常症状。\n"
      end
    }
  end

  defp effect_dispel(state) do
    char = state.character
    conditions = Map.get(char.meta, :conditions) || %{}

    if map_size(conditions) == 0 do
      state
    else
      %{state | character: %{char | meta: Map.put(char.meta, :conditions, %{})}}
    end
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