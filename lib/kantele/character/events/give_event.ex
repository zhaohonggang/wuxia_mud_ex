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
  alias Kantele.Item, as: KItem

  # ---- 收受端 ----

  def receive(conn, %{data: %{item_instance: item_instance, from_name: from_name} = data}) do
    character = conn.character

    cond do
      # 通用 accept_object 规则表优先生效（converter 从 accept_object() 抽取）
      generic_accept?(character) ->
        handle_accept_give(conn, character, item_instance, data, from_name)

      # 店小二 NPC 特殊处理：验证物品后，由给予者进程处理状态更新
      Xiaoer.is_xiaoer?(character) ->
        handle_xiaoer_give(conn, character, item_instance, data, from_name)

      true ->
        handle_normal_give(conn, character, item_instance, data, from_name)
    end
  end

  defp generic_accept?(%{meta: %{accept: rules}}) when is_list(rules) and rules != [], do: true
  defp generic_accept?(_), do: false

  # ---- 通用 accept_object 规则分发（对应 LPC accept_object/2） ----

  defp handle_accept_give(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)
    rules = npc.meta.accept

    case match_accept_rule(item_instance, rules) do
      {:ok, reply} ->
        npc = take_item(npc, item_instance)

        send(
          reply_to,
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: true,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: npc.id,
              from_id: from_id
            }
          }
        )

        if npc != conn.character, do: Records.save(npc)

        conn
        |> put_character(npc)
        |> render(CommandView, "text", %{text: reply <> "\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, reason} ->
        send(
          reply_to,
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: false,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: npc.id,
              from_id: from_id,
              reason: reason
            }
          }
        )

        conn
        |> put_character(npc)
        |> render(CommandView, "text", %{text: reason <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # 按收录顺序匹配规则；命中即返回代表文案。规则：
  #   { kind: "money" }        收钱币，可选 min 下限
  #   { kind: "item_id" }      收指定物品 id
  #   { kind: "item_name" }    收指定名字物品
  #   { kind: "any" }          兜底接受/拒绝（accept 布尔）
  defp match_accept_rule(item_instance, rules) do
    item =
      case Items.get(item_instance.item_id) do
        {:ok, item} -> item
        _ -> nil
      end

    if is_nil(item) do
      {:error, from_drop_message()}
    else
      Enum.reduce(rules, {:error, refuse_message(item)}, fn rule, acc ->
        case acc do
          {:ok, _} ->
            acc

          _ ->
            case rule_hit(rule, item) do
              :hit -> {:ok, take_message(rule, item)}
              :decline -> {:error, failure_message(rule, item)}
              :miss -> acc
            end
        end
      end)
    end
  end

  defp rule_hit(%{kind: "money"} = rule, item) do
    if KItem.is_currency?(item) do
      min = rule.min || 0

      if KItem.currency_amount(item) >= min,
        do: :hit,
        else: :miss
    else
      :miss
    end
  end

  defp rule_hit(%{kind: "item_id"} = rule, item) do
    if rule.id == item.id, do: :hit, else: :miss
  end

  defp rule_hit(%{kind: "item_name"} = rule, item) do
    if Kantele.World.Item.matches?(item, rule.name), do: :hit, else: :miss
  end

  defp rule_hit(%{kind: "any"} = rule, _item) do
    if rule.accept, do: :hit, else: :decline
  end

  defp rule_hit(_rule, _item), do: :miss

  # 收下的物品进入 NPC 背包（钱币不进背包，避免污染商店货架）
  defp take_item(npc, %{item_id: item_id} = item_instance) do
    case Items.get(item_id) do
      {:ok, item} ->
        if KItem.is_currency?(item) do
          npc
        else
          %{npc | inventory: [item_instance | npc.inventory]}
        end

      _ ->
        npc
    end
  end

defp take_message(%{msg: msg} = _rule, item) when is_list(msg) and msg != [],
  do: Enum.random(msg)

defp take_message(_rule, item), do: "你给了#{item.name}。"

# 拒绝文案：优先使用规则 fail_msg 台词池，缺省回退泛化拒绝语
defp failure_message(%{fail_msg: fail_msg} = rule, item) when is_list(fail_msg) and fail_msg != [],
  do: Enum.random(fail_msg)

defp failure_message(%{kind: "any"} = rule, _item), do: refuse_message(nil)
defp failure_message(_rule, item), do: refuse_message(item)

defp refuse_message(nil), do: "对方不肯收下。"
defp refuse_message(item), do: "对方不收#{item.name}。"
  defp from_drop_message(), do: "物品不在房间中。"

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