defmodule Kantele.World.SuoyangdanAccept do
  @moduledoc """
  锁阳丹药引 accept_object（对应 LPC `d/death/npc/yanluo.c` `accept_object`）。

  玩家将四味药引（龙胆、虎骨、朱羽、玄武甲壳）交给阎罗时，
  SuoyangdanAccept 向玩家发 `suoyangdan/give-ingredient` 事件，
  由玩家进程通过 Quest.add_item/4 追踪收集进度；
  四味齐备时置位 Quest.set_solved/2，发放奖励（exp/potential/寰宇天晶）。

  本模块在 NPC 进程内执行（give_event `handle_accept_give` 命中 `kind:"suoyangdan"` 规则时调用）。
  玩家侧状态（背包/任务进度）仅在玩家进程可安全修改，故校验与消费均在
  `suoyangdan/give-ingredient` 玩家侧 handler 完成。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  @ingredient_ids ~w(longdan hugu yumao jiake)a

  def handle(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 向玩家发送 suoyangdan/give-ingredient 事件，由玩家进程校验并追踪进度
    send(reply_to, %Event{
      from_pid: self(),
      topic: "suoyangdan/give-ingredient",
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
    |> render(CommandView, "text", %{text: "十殿阎罗接过药引，点点头道：这味可用。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
