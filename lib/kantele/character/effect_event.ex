defmodule Kantele.Character.EffectEvent do
  @moduledoc """
  通用角色副作用执行器（P5-4e）。

  房间进程只做判定，把 `{:set_temp, key, value}` 等效果交回角色进程执行
  （meta 只有角色进程能安全修改并落盘）。效果列表复用
  `Kantele.Character.TrapEvent` 的实现；与 `trap/effect` 的区别只是语义：
  `character/effects` 供非陷阱场景（如动态 `item_desc` 的只读副作用）使用。
  """

  defdelegate run(conn, event), to: Kantele.Character.TrapEvent
end
