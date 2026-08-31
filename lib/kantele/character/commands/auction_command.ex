defmodule Kantele.Character.AuctionCommand do
  @moduledoc """
  拍卖命令：`auction <物品> for <价格>` / `auction <价格> to <玩家>` / `auction check` / `auction cancel`

  对应 LPC cmds/usr/auction.c 的移植，使用 Kantele.Economy.Auction 全局 ETS 服务。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Economy.Auction
  alias Kantele.World.Items

  def run(conn, params) do
    rest = String.trim(params["rest"] || "")

    cond do
      rest == "check" -> check(conn)
      rest == "cancel" -> cancel(conn)
      String.starts_with?(rest, "cancel ") -> cancel(conn)
      String.contains?(rest, " for ") -> list_auction(conn, rest)
      String.contains?(rest, " to ") -> join_auction(conn, rest)
      true -> help(conn)
    end
  end

  # 挂出物品拍卖
  defp list_auction(conn, rest) do
    with [item_part, price_part] <- String.split(rest, " for ", parts: 2),
         {price, _} <- Integer.parse(price_part),
         price > 0 do
      item_name = String.trim(item_part)

      # 查找玩家背包中的物品
      item_instance =
        Enum.find(conn.character.inventory, fn inst ->
          instance_item_name(inst) =~ item_name
        end)

      if item_instance do
        case Auction.add_auction(conn.character, item_instance, price) do
          :ok ->
            conn
            |> render(CommandView, "text", %{
              text: "你将#{instance_item_name(item_instance)}送上拍卖台，底价#{price}文。\n"
            })
            |> prompt(CommandView, "prompt", %{})

          {:error, :already_auctioning} ->
            conn
            |> render(CommandView, "text", %{text: "你已经在拍卖别的东西了。\n"})
            |> prompt(CommandView, "prompt", %{})
        end
      else
        conn
        |> render(CommandView, "text", %{text: "你身上没有这个东西。\n"})
        |> prompt(CommandView, "prompt", %{})
      end
    else
      _ ->
        help(conn)
    end
  end

  # 参与竞价
  defp join_auction(conn, rest) do
    with [price_part, "to", player_part] <- String.split(rest, " to ", parts: 3),
         {price, _} <- Integer.parse(String.trim(price_part)),
         price > 0 do
      # 查找目标玩家的拍卖
      # auctioneer_id 需要从玩家名查找，这里简化：直接用玩家名
      bidder = conn.character

      case Auction.list_auctions()
           |> Enum.find(fn r -> r.character_name =~ String.trim(player_part) end) do
        nil ->
          conn
          |> render(CommandView, "text", %{text: "这个人没有在拍卖什么东西。\n"})
          |> prompt(CommandView, "prompt", %{})

        record when record.character_id == bidder.id ->
          conn
          |> render(CommandView, "text", %{text: "这是你自己的拍卖品。\n"})
          |> prompt(CommandView, "prompt", %{})

        record ->
          if price <= record.value do
            conn
            |> render(CommandView, "text", %{text: "这个价人家恐怕不会要。\n"})
            |> prompt(CommandView, "prompt", %{})
          else
            case Auction.bid(record.character_id, bidder, price) do
              :ok ->
                conn
                |> render(CommandView, "text", %{
                  text: "你向#{record.character_name}的#{record.goods_name}出价#{price}文。\n"
                })
                |> prompt(CommandView, "prompt", %{})

              {:error, :not_auctioning} ->
                conn
                |> render(CommandView, "text", %{text: "这个人已经不在拍卖了。\n"})
                |> prompt(CommandView, "prompt", %{})

              {:error, reason} ->
                conn
                |> render(CommandView, "text", %{text: "竞价失败：#{inspect(reason)}\n"})
                |> prompt(CommandView, "prompt", %{})
            end
          end
      end
    else
      _ ->
        help(conn)
    end
  end

  # 查看所有拍卖
  defp check(conn) do
    auctions = Auction.list_auctions()

    if auctions == [] do
      conn
      |> render(CommandView, "text", %{text: "目前没有任何正在拍卖的物品。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      sep = String.pad_trailing("≡", 59, "─") <> "≡"
      lines = ["目前正在拍卖的物品有以下这些：", sep]

      for record <- auctions do
        bidder_name = if record.now_bidder_name, do: record.now_bidder_name, else: "无"

        line =
          "  #{record.character_name}的#{record.goods_name}，#{money_str(record.value)}，竞价者：#{
            bidder_name
          }"

        lines = lines ++ [line]
      end

      lines = lines ++ [sep, "共有 #{length(auctions)} 件拍卖品。"]

      conn
      |> render(CommandView, "text", %{text: Enum.join(lines, "\n") <> "\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  # 取消拍卖
  defp cancel(conn) do
    case Auction.cancel_auction(conn.character.id) do
      :ok ->
        conn
        |> render(CommandView, "text", %{text: "你取消了拍卖。\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, :not_auctioning} ->
        conn
        |> render(CommandView, "text", %{text: "你没有在拍卖任何东西。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp help(conn) do
    conn
    |> render(CommandView, "text", %{
      text: """
      指令格式：
        auction <物品> for <价格>  —— 拍卖出一件物品
        auction <价格> to <玩家>    —— 参与叫价
        auction check              —— 察看目前所有正在拍卖的物品
        auction cancel             —— 取消自己物品的拍卖
      """
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp instance_item_name(inst) do
    case Items.get(inst.item_id) do
      {:ok, item} -> item.name
      _ -> inst.item_id || "物品"
    end
  end

  defp money_str(n) when is_integer(n) do
    Kantele.Economy.Money.money_str(Kantele.Economy.Money.split(n))
  end
end
