defmodule Kantele.Condition.Attrition do
  @moduledoc """
  「损伤型」condition 共用的伤害公式（P5-1c，full `bi` 前置）。

  对应 LPC `kungfu/condition/nishui.c` 与 `kungfu/condition/duyan.c` 的
  `update_condition()` 伤害段——两者公式**完全相同**，只差消息与是否递减
  （`nishui` 不递减、`duyan` 每跳减一）。故抽出本模块避免复制。

  ## LPC 原始（逐字保留）

      int dam;
      if (me->query("neili") >= 4000)      dam = random(50);
      else if (me->query("neili") > 3000)  dam = random(500);
      else if (me->query("neili") > 2000)  dam = random(1000);
      else if (me->query("neili") > 1000)  dam = random(1500);
      else if (me->query("neili") > 500)   dam = random(2000);
      else                                 dam = random(3000);
      me->receive_wound("qi", dam);
      me->receive_wound("jing", dam);

  LPC `random(n)` = `0..n-1`，此处用 `:rand.uniform(n) - 1` 对齐。

  ## @todo（与 LPC 的差异，红区相关）

  - LPC 用 `receive_wound`（削减 **eff/max** qi/jing，当前值被夹逼），
    本引擎 `condition_event` 只回写**当前** qi/jing，故这里直接扣当前值
    ——效果等价于「持续掉血到 0」，与 `Kantele.Poison.do_effect` 同款约定。
    待 B1 `eff_*` 三层模型落地后再切回 wound 语义。
  - 每跳 `tell_object`（nishui「你感到一阵气闷！」/ duyan「你中的毒盐发作了！」）
    因 daemon 接口无 conn 渲染通道而暂缺，见各自模块 @todo。
  """

  @doc "按当前 neili 计算一跳伤害（LPC `random(...)` 区间）"
  def damage(neili) when is_integer(neili) do
    cond do
      neili >= 4000 -> roll(50)
      neili > 3000 -> roll(500)
      neili > 2000 -> roll(1000)
      neili > 1000 -> roll(1500)
      neili > 500 -> roll(2000)
      true -> roll(3000)
    end
  end

  def damage(_), do: 0

  @doc """
  对 state 造成 `dam` 点 qi/jing 损伤（对应当前值扣减，见 moduledoc @todo）。

  返回 `{:ok, state}`，与 `Kantele.Poison.do_effect/3` 的契约一致，
  供 `Kantele.Character.Conditions.affect_by/4` 包装。
  """
  def wound(state, dam) do
    attrs = state.attributes

    {:ok,
     state
     |> put_in([:attributes, :qi], max(Map.get(attrs, :qi, 0) - dam, 0))
     |> put_in([:attributes, :jing], max(Map.get(attrs, :jing, 0) - dam, 0))}
  end

  defp roll(n), do: :rand.uniform(n) - 1
end
