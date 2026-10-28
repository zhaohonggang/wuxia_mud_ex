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
  alias Kantele.Util.ChineseNumber
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

      Forging.qiankun_stone?(item) ->
        handle_qiankun(conn, npc, item_instance, item, data, from_id, reply_to)

      material?(item) ->
        handle_material(conn, npc, item_instance, item, data, from_id, reply_to)

      true ->
        reject(conn, npc, item_instance, reply_to, from_id, "你给我这些东西干什么？\n")
    end
  end

  # 乾坤石（LPC moye.c accept_object L328-366）：优先于通用材料判定。
  #
  # LPC 用 `me->query("storage_bag")` 判断玩家有没有背包：
  #   space == 0  → 报价（value/60 两黄金），进入 item_gived，给钱后给背包
  #   space < 100 → 免费强化 +5 格（不进入议价）
  #   space > 100 → 「已经强化到极限了」
  # 偏差：LPC 对 `space == 100` 没有分支（会掉到函数末尾返回 0），这里按「已到极限」处理。
  #
  # 本仓玩家侧没有 storage_bag 属性，扩展格在背包实例 meta 上，所以升级由玩家进程
  # 落地（回执里带 `upgrade_bag`），莫邪进程只负责收石头与发回执。
  defp handle_qiankun(conn, npc, item_instance, item, data, from_id, reply_to) do
    extra = Map.get(data, :bag_extra) || 0

    cond do
      extra >= 100 ->
        reject(conn, npc, item_instance, reply_to, from_id,
          "莫邪对你道：你的背包已经强化到极限了！\n")

      extra > 0 ->
        npc = %{npc | inventory: [item_instance | npc.inventory]}
        Records.save(npc)

        send_forge_accept(reply_to, %{
          ok: true,
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          message: "莫邪对你道：不错不错，我现在就帮你强化背包，请稍等片刻！\n",
          upgrade_bag: 5,
          from_id: from_id
        })

        Conn.put_character(conn, npc)

      true ->
        # 没有背包：报价。LPC 先 `val = value/60` 报「N 两黄金」，再 `val *= 10000` 作为内部币值
        price = div(item.meta.value || 0, 60)
        value = price * 10_000

        session = %{
          status: "item_gived",
          value: value,
          material_item_id: item.id,
          material_instance_id: item_instance.id,
          owner_id: from_id,
          owner_name: Map.get(data, :from_name),
          types: nil,
          qiankun: true
        }

        Forging.put(from_id, session)

        npc = %{npc | inventory: [item_instance | npc.inventory]}
        Records.save(npc)

        message = "莫邪对你说道：很好，炼制如意乾坤袋需要#{ChineseNumber.to_chinese(price)}两黄金。\n"

        send_forge_accept(reply_to, %{
          ok: true,
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          message: message,
          from_id: from_id
        })

        Conn.put_character(conn, npc)
    end
  end

  defp material?(item) do
    not is_nil(item.meta.material_attrib) and (item.meta.power_point || 0) > 0
  end

  # 给材料：估价 + 记 item_gived，材料收进莫邪背包
  #
  # 币值单位必须换算：报价对外是「两黄金」，内部记账（`session.value`，与
  # `KItem.currency_amount/1` 比较）是「文」，1 两 = 10000 文。
  # LPC moye.c L377-381：`val = power_point*2+20` → 报「N 两黄金」→ `val *= 10000`
  # → 写 `item/value`；随后 L423 `ob->value()`（= amount * base_value，base_value
  # 见 clone/money/gold.c 为 10000）与之比较。少了这步实际只收 N 文，等于白送。
  #
  # 巫师特权（LPC L382-388）：`wizardp(me)` 时额外一句提示，实收 1 文。
  defp handle_material(conn, npc, item_instance, item, data, from_id, reply_to) do
    price = (item.meta.power_point || 0) * 2 + 20
    value = price * 10_000
    wizard? = Map.get(data, :wizard) || false
    value = if wizard?, do: 1, else: value

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

    message =
      "莫邪对你说道：很好，用这块原料打造道具需要#{ChineseNumber.to_chinese(price)}两黄金。\n" <>
        if(wizard?,
          do: "莫邪仔细看了看你，笑着说道：原来是巫师啊，那么你随便给点好了。\n",
          else: ""
        )

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

  # 乾坤石付款：给如意乾坤袋（LPC L433），不走类型选择，石头销毁
  defp accept_money(conn, npc, item_instance, _item, _data, from_id, reply_to, %{qiankun: true} = session) do
    material = Items.get!(session.material_item_id)

    npc = drop_material(npc, session)
    Records.save(npc)
    Forging.delete(from_id)

    message =
      "莫邪随手把#{material.name}抛入炉内，霎时间已被火炉中的熊熊烈焰吞没。\n" <>
        "繁杂的炼制步骤看的你眼花缭乱，只能傻傻的等着。\n" <>
        "你获得了一个背包（如意乾坤袋），使用指令：\n" <>
        "\t查看背包   bag\n\t存放物品   store\n\t取出物品   take\n"

    send_forge_accept(reply_to, %{
      ok: true,
      item_id: item_instance.item_id,
      instance_id: item_instance.id,
      message: message,
      grant_item_id: Forging.qiankun_bag_id(),
      from_id: from_id
    })

    Conn.put_character(conn, npc)
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

  # 把材料实例从莫邪背包移除（乾坤袋炼成后石头销毁，LPC `destruct(origin)`）
  defp drop_material(npc, %{material_instance_id: instance_id}) do
    %{npc | inventory: Enum.reject(npc.inventory, &(&1.id == instance_id))}
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
