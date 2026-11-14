defmodule Kantele.World.HunterAccept do
  @moduledoc """
  猎人收捕兽夹 accept_object（对应 LPC `d/hengyang/npc/hunter.c` `accept_object`）。

  玩家把「捕兽夹」(`bushou jia`) 交给猎人时，猎人点头收下，并发出
  `hunter/give-trap` 事件给玩家进程；由玩家侧 handler 置位 `marks/hunter`
  （LPC 的 `set_temp("marks/hunter", 1)`），使 `ask hunter about hunting` /
  `learn hunting 猎人` 的门控放行。

  本模块在 NPC 进程内执行（give_event `handle_accept_give` 命中 `kind:"hunter"` 规则时调用）。
  玩家侧状态（marks/hunter）仅在玩家进程可安全修改，故副作用在
  `hunter/give-trap` 玩家侧 handler 完成。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  def handle(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 向玩家发送 hunter/give-trap 事件，由玩家进程置位 marks/hunter
    send(reply_to, %Event{
      from_pid: self(),
      topic: "hunter/give-trap",
      data: %{
        item_id: item_instance.item_id,
        instance_id: item_instance.id,
        from_id: from_id,
        to_id: npc.id,
        from_name: from_name
      }
    })

    conn
    |> put_character(npc)
    |> render(CommandView, "text", %{
      text: "猎人点点头收下了捕兽夹：这个我正用得着，我教你捕猎技巧和驭兽之术。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end
end
