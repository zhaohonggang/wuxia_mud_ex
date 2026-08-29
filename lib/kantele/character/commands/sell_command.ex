defmodule Kantele.Character.SellCommand do
  @moduledoc """
  变卖/估价：`sell|卖|变卖 <物品> [x数量]` 卖给商人收钱、
  `value|估价 <物品>` 只问收购价不成交

  用 `Kantele.Npc.Dealer`（feature/dealer.c 移植）做估价（do_value）与收购价
  （do_sell）的纯逻辑，宿主负责：从背包按名找物品、把物品实例翻译成
  item_map、成交时扣物 + 加铜钱 + 落盘。

  框架背包里的每件物品都是独立不可叠加实例（item_map 不带 :amount 栈计数字段，
  故 do_sell 用 :value 计价、max_count=1）；xN 卖出按单件收购价 × 数量累加。

  对照 LPC `feature/dealer.c` 的 do_value / do_sell 展示层。
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Economy.Money
  alias Kantele.Npc.Dealer
  alias Kantele.World.Item
  alias Kantele.World.Items

  @doc "估价（只问价不成交，对应 dealer.c do_value）"
  def value(conn, %{"item_name" => raw}) do
    case pick(conn.character, parse_name(raw)) do
      {:error, msg} ->
        reply(conn, "#{msg}\n")

      {:ok, _instance, definition, _quantity} ->
        case Dealer.do_value(item_map(definition)) do
          {:ok, val, _reason} ->
            reply(conn, "#{definition.name} 可以卖#{Money.money_str(val)}。\n")

          {:ok, val} ->
            reply(conn, "#{definition.name} 可以卖#{Money.money_str(val)}。\n")

          {:reject, msg} ->
            reply(conn, "#{msg}\n")
        end
    end
  end

  def value(conn, _params), do: usage(conn)

  @doc "变卖（成交收钱，对应 dealer.c do_sell）"
  def sell(conn, %{"item_name" => raw}) do
    {name, quantity} = parse_quantity(raw)

    case take(conn.character, name, quantity) do
      {:error, msg} ->
        reply(conn, "#{msg}\n")

      {:ok, instances, definition, quantity} ->
        single = item_map(definition)

        case Dealer.do_sell(single, 1) do
          {:ok, per} ->
            total = per * quantity
            sold_ids = Enum.map(instances, & &1.id)

            inventory =
              Enum.reject(conn.character.inventory, fn instance ->
                instance.id in sold_ids
              end)

            coins = (conn.character.meta.coins || 0) + total
            character = %{conn.character | inventory: inventory}
            character = Map.put(character, :meta, Map.put(character.meta, :coins, coins))
            Records.save(character)

            text =
              "你把#{definition.name}#{if quantity > 1, do: "（×#{quantity}）", else: ""}" <>
                "卖给了商人，得了#{Money.money_str(total)}。\n"

            conn
            |> put_character(character)
            |> reply(text)

          {:reject, msg} ->
            reply(conn, "#{msg}\n")
        end
    end
  end

  def sell(conn, _params), do: usage(conn)

  defp usage(conn) do
    reply(conn, "用法：sell|卖|变卖 <物品> [x数量]；value|估价 <物品> 只问价。\n")
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  # 名字 + 可选 xN 数量（与 BuyCommand 一致：`名字 xN`）
  defp parse_quantity(raw) do
    trimmed = String.trim(raw || "")

    case Regex.run(~r/^(.+?)\s*x(\d+)$/, trimmed) do
      [_, name, n] ->
        {String.trim(name), String.to_integer(n)}

      _ ->
        {trimmed, 1}
    end
  end

  defp parse_name(raw), do: elem(parse_quantity(raw), 0)

  # 估价：取第一件匹配物品（不指定数量，越出数量也无所谓）
  defp pick(character, name) do
    case matching(character, name) do
      [] ->
        {:error, "你身上没有这种东西。"}

      [instance | _] ->
        {:ok, instance, Items.get!(instance.item_id), 1}
    end
  end

  # 变卖：取最多 quantity 件，数量不够/为空则报错
  defp take(_character, name, _quantity) when name == "" do
    {:error, "你想卖什么？"}
  end

  defp take(character, name, quantity) do
    candidates = matching(character, name)

    cond do
      candidates == [] ->
        {:error, "你身上没有这种东西。"}

      Enum.count(candidates) < quantity ->
        {:error, "你身上没有这么多。"}

      true ->
        instances = Enum.take(candidates, quantity)
        {:ok, instances, Items.get!(hd(instances).item_id), quantity}
    end
  end

  defp matching(character, name) do
    Enum.filter(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      instance.id == name || Item.matches?(item, name)
    end)
  end

  # 物品实例 -> Dealer item_map。框架物为独立不可叠加实例：不带 :amount
  # （故 do_sell 用 :value 计价，max_count=1）；无 money_id/角色/装备等高级位，置缺省 falsy
  defp item_map(definition) do
    %{
      name: definition.name,
      id: definition.id,
      value: item_value(definition),
      money_id: nil,
      is_character?: false,
      no_sell?: false,
      equipped?: false
    }
  end

  defp item_value(definition) do
    case definition do
      %{meta: %{value: v}} when is_integer(v) and v > 0 -> v
      _ -> 0
    end
  end
end
