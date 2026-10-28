defmodule Kantele.World.WuxiuwenAccept do
  @moduledoc """
  武修文收还工具（对应 LPC wuxiuwen.c `accept_object`，还工具分支）。

  在武修文进程内执行（give_event receive 侧，命中 `kind:"wuxiuwen"` 规则时调用）。
  负责：判定给来的是不是五种打工工具之一；是则收下、把工具实例进武修文背包、
  向给予者（玩家）进程发 `give/result` 确认（玩家侧物理移除），并再发
  `wuxiuwen/returned` 事件让玩家进程落 `mark/还了`（LPC `set_temp("mark/还了", 1)`）。

  ## 与 LPC 的差异

  - LPC `accept_object` 在**同一进程**内读完玩家 `mark/劈完了` 等完成标记、工具 id、
    `job_name` 后决定收/拒。本端口跨进程：武修文进程只持工具实例，**看不见玩家
    meta**，故「完成标记 / job_name」校验改在玩家进程的 `GiveEvent.wuxiuwen_returned`
    里做；正常流程（先干完活、再还工具）下校验通过、`mark/还了` 落定，闭环可通。
  - 极端情形（玩家未完工就还工具）：工具已被武修文收下、但玩家侧校验不通过，
    `mark/还了` 不置（LPC 同样不置，且 `destruct` 了工具，本端口仅收下不销毁，
    行为更接近「暂存」，属可接受的边角差异）。
  - `command("nod")` / `command("say ...")` 的房间可见反馈，由武修文进程广播一条
    vision（"$N点头道：干得不错，你现在去耶律师兄那儿领取酬劳吧。"）承载。
  """
  alias Kalevala.Event
  alias Kalevala.Character.Conn
  alias Kantele.Character.Records
  alias Kantele.World.Items
  alias Kantele.World.RoomActions.Helpers

  # 五种打工工具（Kantele 全 id；定义落在 wuguan.ucl 的 items 命名空间，
  # LPCConverter 从 /d/wuguan/obj/{chutou,piao,juzi,chaidao,saozhou}.c 抽出）。
  # 与 LPC accept_object 的 id 表（"chu tou"/"shui piao"/"ju zi"/"chai dao"/"sao zhou"）
  # 一一对应，这里直接用实例的 item_id 全 id 比对，避免 KItem.matches? 只认
  # name/aliases 而漏配。
  @valid_tools ~w(wuguan:items.chutou wuguan:items.piao wuguan:items.juzi wuguan:items.chaidao wuguan:items.saozhou)

  def handle(conn, npc, item_instance, data, _from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)
    item = Items.get!(item_instance.item_id)

    if not valid_tool?(item) do
      reject(conn, item_instance, reply_to, from_id,
        "你还错东西了吧，我从没有发过这样工具。\n")
    else
      accept(conn, npc, item_instance, item, data, reply_to, from_id)
    end
  end

  defp valid_tool?(item), do: Enum.member?(@valid_tools, item.id)

  defp accept(conn, npc, item_instance, _item, data, reply_to, from_id) do
    npc = %{npc | inventory: [item_instance | npc.inventory]}
    Records.save(npc)

    # 玩家侧物理移除（与通用 give 流程一致）
    send_give_result(reply_to, item_instance, from_id, true)

    # 交由玩家进程落 mark/还了 + 回话（跨进程）
    send_returned(reply_to, %{
      ok: true,
      item_id: item_instance.item_id,
      instance_id: item_instance.id,
      from_id: from_id,
      message: "干得不错，你现在去耶律师兄那儿领取酬劳吧。\n"
    })

    # 房间可见反馈（LPC command("nod") + command("say ...")）
    conn
    |> Helpers.broadcast_vision(npc.room_id,
      "$N点头道：干得不错，你现在去耶律师兄那儿领取酬劳吧。\n")
    |> Conn.put_character(npc)
  end

  defp reject(conn, _item_instance, reply_to, from_id, message) do
    # 不退工具给玩家（LPC accept_object 返回 0 即原样留在玩家背包），仅把拒绝文案
    # 经玩家进程回执出来（give/result 走通用流程会显示泛化「对方不肯收下」，故单独发）。
    send_returned(reply_to, %{ok: false, from_id: from_id, message: message})
    Conn.put_character(conn, conn.character)
  end

  defp send_give_result(reply_to, item_instance, from_id, ok) do
    send(reply_to, %Event{
      from_pid: self(),
      topic: "give/result",
      data: %{
        ok: ok,
        item_id: item_instance.item_id,
        instance_id: item_instance.id,
        to_id: nil,
        from_id: from_id
      }
    })
  end

  defp send_returned(reply_to, data) do
    send(reply_to, %Event{
      from_pid: self(),
      topic: "wuxiuwen/returned",
      data: data
    })
  end
end
