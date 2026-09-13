defmodule Kantele.Character.GiveEvent do
  @moduledoc """
  give 的两端处理（Batch 5）

  - 收受端 `characters/give`：把对方赠予的物品实例加入自己背包并落盘，回执赠与人
  - 店小二等特殊 NPC：委托给 Kantele.NPC.Xiaoer 处理钱币/尸体/兑换（跨进程由给予者更新状态）
  - 赠与端 `give/result`：确认后从自己背包移除该物品并落盘，提示成功
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.PlayerMeta
  alias Kantele.NPC.Xiaoer
  alias Kantele.World.Items
  alias Kalevala.World.Item

  # ---- 收受端 ----

  def receive(conn, %{data: %{item_instance: item_instance, from_name: from_name} = data}) do
    character = conn.character

    # 店小二 NPC 特殊处理：验证物品后，由给予者进程处理状态更新
    if Xiaoer.is_xiaoer?(character) do
      handle_xiaoer_give(conn, character, item_instance, data, from_name)
    else
      handle_normal_give(conn, character, item_instance, data, from_name)
    end
  end

  defp handle_normal_give(conn, character, item_instance, data, from_name) do
    item = Items.get!(item_instance.item_id)
    item_name = item.name

    case item_instance do
      nil ->
        deny(conn, from_name)

      _ ->
        inventory = [item_instance | character.inventory]
        character = %{character | inventory: inventory}

        send(
          Map.get(data, :reply_to),
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: true,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: character.id,
              from_id: Map.get(data, :from_id)
            }
          }
        )

        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: "#{from_name}给你#{item_name}。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp handle_xiaoer_give(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 在 NPC 进程验证物品，通过则让给予者进程处理状态更新
    case Xiaoer.validate_give(npc, item_instance) do
      {:ok, action} ->
        # 发送给给予者进程处理
        send(reply_to, %Event{
          from_pid: self(),
          topic: "xiaoer/process_give",
          data: %{
            action: action,
            item_id: item_instance.item_id,
            instance_id: item_instance.id,
            npc_id: npc.id,
            npc_pid: self(),
            from_id: from_id
          }
        })

        # NPC 即时回应
        conn
        |> put_character(conn.character)
        |> render(CommandView, "text", %{text: "店小二接过#{Xiaoer.item_name(item_instance)}，正在为您办理...\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, msg} ->
        send(reply_to, %Event{
          from_pid: self(),
          topic: "give/result",
          data: %{
            ok: false,
            item_id: item_instance.item_id,
            instance_id: item_instance.id,
            to_id: npc.id,
            from_id: Map.get(data, :from_id),
            reason: msg
          }
        })

        conn
        |> put_character(conn.character)
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp deny(conn, from_name) do
    conn
    |> render(CommandView, "text", %{text: "#{from_name}递来东西，但你无法接受。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 给予者端：处理店小二业务（更新自身 meta）----

  def xiaoer_process_give(conn, %{data: %{action: action}} = event) do
    character = conn.character

    case do_xiaoer_action(character, action, event.data) do
      {:ok, new_character, msg} ->
        send(
          Map.get(event.data, :npc_pid) || :ignore,
          %Event{
            from_pid: self(),
            topic: "xiaoer/give_result",
            data: %{ok: true, msg: msg, from_id: character.id}
          }
        )

        conn
        |> put_character(new_character)
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp do_xiaoer_action(character, :pay_rent, data) do
    amount = data.amount
    rent_paid = PlayerMeta.get_temp(character.meta, "rent_paid") || 0
    new_rent = rent_paid + amount

    new_meta = PlayerMeta.put_temp(character.meta, "rent_paid", new_rent)
    new_character = %{character | meta: new_meta}
    Records.save(new_character)

    change = amount - Xiaoer.rent_per_night()

    msg =
      if change > 0 do
        "多谢客官，找您 #{change} 文钱。您已预付 #{new_rent} 文房钱。"
      else
        "多谢客官，您已预付 #{new_rent} 文房钱。"
      end

    {:ok, %{character | meta: new_meta}, msg}
  end

  defp do_xiaoer_action(character, :exchange_item, data) do
    item_key = data.item_key
    exchange = Map.get(Xiaoer.exchange_items(), item_key)

    if exchange == nil do
      {:error, "没有这个兑换项目。"}
    else
      points = Kantele.Character.PlayerMeta.jifen(character.meta)

      if points >= exchange.cost do
        new_points = points - exchange.cost
        new_meta = Kantele.Character.PlayerMeta.put_jifen(character.meta, new_points)
        new_character = %{character | meta: new_meta}

        # 创建物品实例给玩家
        case Kantele.World.Items.get(exchange.item) do
          {:ok, item_template} ->
            item_instance = %Kalevala.World.Item.Instance{
              id: Kalevala.World.Item.Instance.generate_id(),
              item_id: exchange.item,
              created_at: DateTime.utc_now()
            }

            new_character = %{new_character | inventory: [item_instance | new_character.inventory]}
            Kantele.Character.Records.save(new_character)

            {:ok, new_character, "兑换成功！您获得了 #{exchange.name}。"}

          _ ->
            {:error, "兑换物品不存在，请联系巫师。"}
        end
      else
        {:error, "您的积分不足，需要 #{exchange.cost} 点。"}
      end
    end
  end

  defp do_xiaoer_action(character, :dispose_corpse, _data) do
    # 尸体处理：直接丢弃（已从给予者背包移除）
    {:ok, character, "店小二拖着尸体拖到了后院。"}
  end

  # ---- 赠与端 ----

  def result(conn, %{data: %{ok: true, from_id: from_id, instance_id: instance_id}} = _event) do
    character = conn.character

    if from_id == character.id do
      inventory =
        Enum.reject(character.inventory, fn item_instance ->
          item_instance.id == instance_id
        end)

      character = %{character | inventory: inventory}
      Records.save(character)

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你把东西交给了对方。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
    end
  end

  def result(conn, %{data: %{ok: false}}) do
    conn
    |> render(CommandView, "text", %{text: "对方不肯收下。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn
end