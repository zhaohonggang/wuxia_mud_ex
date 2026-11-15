defmodule Kantele.Character.HintsCommand do
  @moduledoc """
  `hints` / `交互` / `提示`：列出当前房间里所有可执行的交互命令。

  进入房间时 `look` 已自动带出精简版提示；本命令给完整版（不截断行数），
  且不受 `option hints_hidden` 影响 —— 与 `map` / `map_hidden` 的关系一致。

  真正的汇总在房间进程侧的 `Kantele.World.Room.HintsEvent`，因为房间数据、
  NPC 快照和地上物品实例都在那里。
  """
  use Kalevala.Character.Command

  def run(conn, _params) do
    conn
    |> event("room/hints")
    |> assign(:prompt, false)
  end
end
