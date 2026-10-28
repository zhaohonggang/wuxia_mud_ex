defmodule Kantele.World.ForgingAccept do
  @moduledoc """
  forge accept 议价状态机（对应 LPC moye.c `accept_object`，L373–478）。

  在莫邪进程内执行（give_event receive 侧，命中 `kind:"forge"` 规则时调用）。
  负责：判定给来的是材料 / 钱币 / 其他；推进锻造会话；把莫邪的回复通过
  `forge/accept` 事件送达玩家（跨进程）。

  玩家侧物品实例从背包移除，由玩家进程收到 `forge/accept` 确认事件后完成
  （与通用 give 流程一致）；本模块只在莫邪侧记录会话、把关、把材料实例收进
  莫邪背包（钱币不入背包，仅记 money_instance_id）。
  """
  alias Kalevala.Event
  alias Kalevala.Character.Conn
  alias Kantele.Character.Records
  alias Kantele.World.Items
  alias Kantele.Item, as: KItem
  alias Kantele.World.Forging

  def handle(conn, npc, item_instance, data, from_name) do
    from_id = Map.get(data, :from_id)
    reply_to = Map.get(data, :reply_to)
    item = Items.get!(item_instance.item_id)

    cond do
      KItem.is_currency?(item) ->
        handle_money(conn, npc, item_instance, item, data, from_id, reply_to)

      material?(item) ->
        handle_material(conn, npc, item_instance, item, data, from_id, reply_to)

      true ->
        reject(conn, npc, item_instance, reply_to, from_id, "你给我这些东西干什么？\n")
    end
  end

  defp material?(item) do
    not is_nil(item.meta.material_attrib) and (item.meta.power_point || 0) > 0
  end

  # 给材料：估价 + 记 item_gived，材料收进莫邪背包
  defp handle_material(conn, npc, item_instance, item, data, from_id, reply_to) do
    value = (item.meta.power_point || 0) * 2 + 20

    session = %{
      status: "item_gived",
      value: value,
      material_item_id: item.id,
      material_instance_id: item_instance.id,
      owner_id: from_id,
      owner_name: Map.get(data, :from_name),
      types: nil
    }

    Forging.put(from_id, session)

    npc = %{npc | inventory: [item_instance | npc.inventory]}
    Records.save(npc)

    message = "莫邪对你说道：很好，用这块原料打造道具需要 #{value} 两黄金。\n"

    send_forge_accept(reply_to, %{
      ok: true,
      item_id: item_instance.item_id,
      instance_id: item_instance.id,
      message: message,
      from_id: from_id
    })

    Conn.put_character(conn, npc)
  end

  # 给钱币：须已交材料（item_gived）→ 校验金额 → 枚举类型 → answer_type
  defp handle_money(conn, npc, item_instance, item, data, from_id, reply_to) do
    case Forging.get(from_id) do
      nil ->
        reject(conn, npc, item_instance, reply_to, from_id,
          "莫邪把递过去的#{item.name}推了回来，摇头道：无功不受禄。\n")

      %{status: "answer_type"} ->
        reject(conn, npc, item_instance, reply_to, from_id,
          "莫邪摇摇头，对你说：快说你要做什么东西呀。\n")

      %{status: "item_gived"} = session ->
        if KItem.currency_amount(item) < session.value do
          reject(conn, npc, item_instance, reply_to, from_id,
            "莫邪冷笑一声，对你说：本店开张千多年来，还没有打过折扣。\n")
        else
          accept_money(conn, npc, item_instance, item, data, from_id, reply_to, session)
        end

      _ ->
        reject(conn, npc, item_instance, reply_to, from_id,
          "莫邪把递过去的#{item.name}推了回来，摇头道：无功不受禄。\n")
    end
  end

  defp accept_money(conn, _npc, item_instance, _item, _data, from_id, reply_to, session) do
    material = Items.get!(session.material_item_id)

    types = Forging.types_for(material.meta.can_make, material.meta.not_make)

    new_session =
      session
      |> Map.put(:money_instance_id, item_instance.id)
      |> Map.put(:money_instance, item_instance)
      |> Map.merge(%{status: "answer_type", types: types})

    Forging.put(from_id, new_session)

    # 钱币不入莫邪背包（避免污染货架），仅记实例 id，物理移除由玩家侧 forge/accept 完成
    message =
      "莫邪对你说道：好，这就给你炼。你打算锻造什么东西，请告诉(answer <类型>)我类型。\n「" <>
        Enum.join(types, "、") <> "」\n"

    send_forge_accept(reply_to, %{
      ok: true,
      item_id: item_instance.item_id,
      instance_id: item_instance.id,
      message: message,
      from_id: from_id
    })

    Conn.put_character(conn, conn.character)
  end

  defp reject(conn, _npc, item_instance, reply_to, from_id, message) do
    send_forge_accept(reply_to, %{
      ok: false,
      item_id: item_instance.item_id,
      instance_id: item_instance.id,
      message: message,
      from_id: from_id
    })

    Conn.put_character(conn, conn.character)
  end

  defp send_forge_accept(reply_to, data) do
    send(reply_to, %Event{
      from_pid: self(),
      topic: "forge/accept",
      data: data
    })
  end
end
