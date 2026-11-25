defmodule Kantele.World.ShaolinDuAccept do
  @moduledoc """
  少林三老（渡厄/渡劫/渡难）的 accept_object（对应 LPC `kungfu/class/shaolin/du-e.c` /
  `du-jie.c` / `du-nan.c` `accept_object`）。

  玩家把「黑索」(`heisuo1/2/3`) 或三老各自发放的物品（九环锡杖 `jiuhuan` /
  锦襕袈裟 `jinlan` / 神草结 `caojie`）交给三老时，三老点头说「甚好，甚好。」，
  并销毁该物品（LPC `destruct(ob)`，不进入 NPC 背包）。

  本模块在 NPC 进程内执行（give_event `handle_accept_give` 命中 `kind:"shaolin_du"`
  规则时调用）。玩家侧背包只能在玩家进程修改，故副作用在
  `shaolin_du/destruct-item` 玩家侧 handler 完成（从玩家背包移除实例）。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  def handle(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 向玩家发送 shaolin_du/destruct-item 事件，由玩家进程从背包移除该实例
    send(
      reply_to,
      %Event{
        from_pid: self(),
        topic: "shaolin_du/destruct-item",
        data: %{
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          from_id: from_id,
          to_id: npc.id,
          from_name: from_name
        }
      }
    )

    conn
    |> put_character(npc)
    |> render(CommandView, "text", %{text: "#{npc.name}点点头：「甚好，甚好。」\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
