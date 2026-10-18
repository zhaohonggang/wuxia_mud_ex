defmodule Kantele.Nishui do
  @moduledoc """
  泥水（憋气）condition：`apply_condition("nishui", N)`（P5-1c，full `bi` 前置）。

  对应 LPC `kungfu/condition/nishui.c`，用于巨鲸帮麦鲸（`d/tulong/tulong/npc/mai.c`）
  的水上比试：双方各用湿泥糊嘴，每跳按 neili 掉 qi/jing，直到一方倒下。

  ## LPC 原始 `update_condition(me, duration)`

      ... 按 neili 计算 dam，receive_wound qi/jing ...
      me->apply_condition("nishui", duration);   // ← 以**原 duration** 重挂！
      if (duration < 1) tell_object(me, "你抹去糊在嘴上的泥巴…");
      else              tell_object(me, "你感到一阵气闷！");
      if (duration < 1) return 0;
      return 1;

  要点：`nishui` **不自行递减**，只由对端 `apply_condition("nishui", 0)` 清除
  （见 mai.c `die()`/`unconcious()`）。故 `update_condition/1` 仅在
  `duration < 1` 时到期。

  ## @todo

  - 每跳消息「你感到一阵气闷！」/ 到期「你抹去糊在嘴上的泥巴，只感到空气
    是多么的清新。」：daemon 接口无渲染通道，暂缺（见 `Kantele.Condition.Attrition` @todo）。
  """

  alias Kantele.Condition.Attrition

  @doc "给 'nishui' 返回 {:ok, Nishui}"
  def daemon("nishui"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc "每 tick：按 neili 掉 qi/jing（对应对端 LPC `receive_wound`）"
  def do_effect(state, _cnd, _para) do
    neili = Map.get(state.attributes, :neili, 0)
    Attrition.wound(state, Attrition.damage(neili))
  end

  @doc "生命周期：nishui 不递减，duration < 1 才到期"
  def update_condition(info) do
    case Map.get(info, "duration", 0) do
      d when is_integer(d) and d >= 1 -> {:continue, info}
      _ -> {:expire}
    end
  end
end
