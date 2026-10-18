defmodule Kantele.Character.CallOutEvent do
  @moduledoc """
  NPC `call_out` 回调宿主（P5-1c，full `bi` 前置）。

  对应 LPC `call_out()` 到期后在 NPC 进程上执行目标函数（见
  `Kantele.World.NpcActions.CallOut`）。收到 `"npc/call-out"` 主题的
  `%Kalevala.Event{}` 后，把 `event.data` 里的 `{module, function, args}`
  解析为一次 `apply(module, function, [conn | args])` 调用。

  目标函数签名约定：`fun(conn, ...args)` → `conn`，与本引擎其它事件一致。
  """

  use Kalevala.Character.Event

  def run(conn, event) do
    data = event.data
    module = Map.get(data, :module)
    function = Map.get(data, :function)
    args = Map.get(data, :args, []) || []

    if is_atom(module) and is_atom(function) and
         function_exported?(module, function, length(args) + 1) do
      apply(module, function, [conn | args])
    else
      conn
    end
  end
end
