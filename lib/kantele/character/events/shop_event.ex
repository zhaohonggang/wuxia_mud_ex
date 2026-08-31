defmodule Kantele.Character.ShopEvent do
  @moduledoc """
  商店结果处理（A10/N2，玩家侧）

  - `shop/list-result`：渲染商人货单
  - `shop/buy-result`：报价可信即成交（v0 简化：玩家侧扣钱+入包，
    不做二次确认；库存视为无限）
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.ShopView
  alias Kantele.World.Items

  def list_result(conn, %{data: %{vendor: vendor, items: items}}) do
    require Logger

    Logger.debug("[SHOPDIAG-PLAYER] list_result vendor=#{vendor} items=#{length(items)}")

    conn
    |> render(ShopView, "list", %{vendor: vendor, items: items})
    |> prompt(CommandView, "prompt", %{})
  end

  def list_result(conn, _event), do: conn

  def buy_result(conn, %{data: %{unavailable: true, item_name: item_name}}) do
    conn
    |> render(CommandView, "text", %{text: "这里不卖#{item_name}。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def buy_result(
        conn,
        %{
          data:
            %{
              unavailable: false,
              vendor: vendor,
              item_id: item_id,
              item_name: item_name,
              price: price,
              buyer_id: buyer_id
            } = data
        }
      ) do
    character = conn.character
    quantity = Map.get(data, :quantity, 1) || 1

    cond do
      buyer_id != character.id ->
        conn

      (character.meta.coins || 0) < price * quantity ->
        conn
        |> render(CommandView, "text", %{
          text: "你身上的钱不够，#{item_name}要 #{price} 文×#{quantity}＝#{price * quantity} 文。\n"
        })
        |> prompt(CommandView, "prompt", %{})

      true ->
        case Items.get(item_id) do
          {:ok, _item} ->
            instances =
              for _ <- 1..quantity do
                %Item.Instance{
                  id: Item.Instance.generate_id(),
                  item_id: item_id,
                  created_at: DateTime.utc_now()
                }
              end

            coins = character.meta.coins - price * quantity
            character = %{character | inventory: instances ++ character.inventory}
            character = Map.put(character, :meta, Map.put(character.meta, :coins, coins))

            Records.save(character)

            qty_text = if quantity > 1, do: "（×#{quantity}）", else: ""

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{
              text: "你从#{vendor}手里买下#{item_name}#{qty_text}，花了 #{price * quantity} 文铜钱。\n"
            })
            |> prompt(CommandView, "prompt", %{})
            |> render(Kantele.Character.CharacterView, "vitals")

          _ ->
            conn
        end
    end
  end

  def buy_result(conn, _event), do: conn
end
