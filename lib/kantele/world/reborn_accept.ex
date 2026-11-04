defmodule Kantele.World.RebornAccept do
  @moduledoc """
  转世献丹 accept_object（对应 LPC `d/death/npc/dizangwang.c` `accept_object`）。

  玩家将精元丹交给地藏王时，地藏王校验 SkyPass + DiZangPass：
  - 不足 → 「无功不受禄」，物品不收（玩家侧拒绝）
  - 齐备 → 收下精元丹，向玩家发 `reborn/give-jingyuandan` 事件，
    由玩家进程销毁药丹并触发六道轮回遍历（传送至无间道）

  本模块在 NPC 进程内执行（give_event `handle_accept_give` 命中 `kind:"reborn"` 规则时调用）。
  玩家侧状态（SkyPass/DiZangPass/背包）仅在玩家进程可安全修改，故校验与消费均在
  `reborn/give-jingyuandan` 玩家侧 handler 完成。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  def handle(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 向玩家发送 reborn/give-jingyuandan 事件，由玩家进程校验 SkyPass+DiZangPass
    # 并执行精元丹销毁 + 六道轮回遍历（传送至无间道）
    send(reply_to, %Event{
      from_pid: self(),
      topic: "reborn/give-jingyuandan",
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
    |> render(CommandView, "text", %{text: "地藏王接过精元丹，随手一招，突然刮起一阵阴风……\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
