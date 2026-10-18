defmodule Kantele.Duyan do
  @moduledoc """
  毒盐 condition：`apply_condition("duyan", N)`（P5-1c，full `bi` 前置）。

  对应 LPC `kungfu/condition/duyan.c`，用于海沙派元广波（`d/tulong/tulong/npc/yuan.c`）
  的比试：双方各吃一碗毒盐，每跳按 neili 掉 qi/jing，直到一方倒下。

  ## LPC 原始 `update_condition(me, duration)`

      ... 按 neili 计算 dam，receive_wound qi/jing ...
      me->apply_condition("duyan", duration - 1);   // ← 每跳减一
      if (duration < 1) tell_object(me, "你中的毒盐终于发作光了。");
      else              tell_object(me, "你中的毒盐发作了！");
      if (duration < 1) return 0;
      return 1;

  与 `Kantele.Nishui` 相反：`duyan` **每跳递减**，`duration < 1` 到期。
  （LPC 用传入的 `duration` 判定、却写回 `duration - 1`；此处按「递减后在
  `< 1` 时到期」实现，避免 LPC 的 off-by-one 多打一跳。）

  ## @todo

  每跳消息「你中的毒盐发作了！」/ 到期「你中的毒盐终于发作光了。」暂缺
  （daemon 接口无渲染通道，见 `Kantele.Condition.Attrition` @todo）。
  """

  alias Kantele.Condition.Attrition

  @doc "给 'duyan' 返回 {:ok, Duyan}"
  def daemon("duyan"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc "每 tick：按 neili 掉 qi/jing（对应对端 LPC `receive_wound`）"
  def do_effect(state, _cnd, _para) do
    neili = Map.get(state.attributes, :neili, 0)
    Attrition.wound(state, Attrition.damage(neili))
  end

  @doc "生命周期：每跳 duration 减一，< 1 到期"
  def update_condition(info) do
    d = Map.get(info, "duration", 0) - 1
    if d < 1, do: {:expire}, else: {:continue, Map.put(info, "duration", d)}
  end
end
