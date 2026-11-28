defmodule Kantele.Character.XingXiuAziEvent do
  @moduledoc """
  阿紫 `accept_kill` 给鼎分支的 NPC 侧回执（`azi.c:125-129`）。

  `Kantele.NPC.XingXiuAzi.engage_decide/3` 在房间进程里判定通过后，把
  `xingxiu_azi/revoke-swmuding` 投到阿紫自己的进程；本模块在这里完成两件
  LPC 里由 NPC 对象自己持有的状态变更：

  1. `set("swmuding", 0)` → `meta.env["swmuding"] = 0`；
  2. `ob->move(me); command("give <id> to <who id>")` → 经 `npc/give`
     把 `clone_lib:swmuding` 克隆实例交给攻击者，由
     `Kantele.Character.NpcScriptEvent.give_result/2` 落库。

  给鼎文案由 `engage_decide/3` 直接渲染给攻击者（`text: ""` 表示这里不要再
  发一遍），房间旁观者文案也在那里广播，避免异步到达造成重复。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.Event

  @doc "LPC `set(\"swmuding\", 0)` + `give`：只在 NPC 进程执行。"
  def revoke_swmuding(conn, %{data: %{asker: asker}} = event) do
    npc = conn.character
    env = Map.put(npc.meta.env || %{}, "swmuding", 0)
    conn = put_character(conn, %{npc | meta: %{npc.meta | env: env}})

    give_to(asker, %{
      npc_name: npc.name,
      item_id: Map.get(event.data, :item_id, "clone_lib:swmuding"),
      asker_id: asker.id,
      text: Map.get(event.data, :text, "")
    })

    conn
  end

  def revoke_swmuding(conn, _event), do: conn

  defp give_to(%{pid: pid}, data) when is_pid(pid) do
    send(pid, %Event{from_pid: self(), topic: "npc/give", data: data})
  end

  defp give_to(_asker, _data), do: :ok
end
