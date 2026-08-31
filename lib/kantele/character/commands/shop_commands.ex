defmodule Kantele.Character.ListCommand do
  @moduledoc """
  列出商人货物：`list [商人]`

  房间转发给指名（或全场）NPC，由带 goods 的商人应答货单。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    require Logger

    Logger.debug("[SHOPDIAG-CMD] list name=#{inspect(params["name"])}")

    conn
    |> event("shop/list", %{name: params["name"]})
    |> assign(:prompt, false)
  end

  # 裸 `list`（无参数）走这里
  def bare(conn, _params), do: run(conn, %{})
end

defmodule Kantele.Character.BuyCommand do
  @moduledoc """
  购买物品：`buy <物品> [x数量]`

  支持 xN 后缀一次购买多件（v0 库存无限）。数量随事件数据传递，
  不放 conn.assigns（assigns 不跨 foreman 消息存活）。
  """

  use Kalevala.Character.Command

  @max_quantity 100

  def run(conn, params) do
    raw = params["item_name"] || ""
    {item_name, quantity} = parse_quantity(raw)

    conn
    |> event("shop/buy", %{item_name: item_name, quantity: min(quantity, @max_quantity)})
    |> assign(:prompt, false)
  end

  defp parse_quantity(raw) do
    case Regex.run(~r/^(.+?)\s*x(\d+)$/, String.trim(raw)) do
      [_, name, n] -> {String.trim(name), String.to_integer(n)}
      _ -> {raw, 1}
    end
  end
end

defmodule Kantele.Character.AskCommand do
  @moduledoc """
  问询：`ask <人> about <关键词>` / 中文 `问 <人> <关键词>`

  关键词包含匹配 NPC 的 inquiries 表，命中即回话。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    keyword =
      params["keyword"]
      |> to_string()
      |> strip_about()

    conn
    |> event("characters/ask", %{name: params["name"], keyword: keyword})
    |> assign(:prompt, false)
  end

  defp strip_about("about " <> rest), do: String.trim(rest)

  defp strip_about("关于" <> rest), do: String.trim(rest)

  defp strip_about(keyword), do: String.trim(keyword)
end

defmodule Kantele.Character.ShopCommand do
  @moduledoc """
  商店/摊位状态：`shop`

  展示玩家当前摊位状态与货品（需先摆摊 baitan）。
  对应 LPC cmds/usr/shop.c 的玩家视角简化版（巫师 shop 管理不在 M1 范围）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    meta = character.meta

    text =
      if meta.stall do
        items = meta.shop_stock || []

        if items == [] do
          "你的摊位「#{meta.stall}」目前没有摆上货物。\n"
        else
          lines = ["你的摊位「#{meta.stall}」当前货品："]

          items
          |> Enum.with_index(1)
          |> Enum.each(fn {item, idx} ->
            lines = lines ++ ["  #{idx}. #{item["name"]} #{item["price"]}文"]
          end)

          lines |> Enum.join("\n")
        end
      else
        "你还没有摆摊。使用 baitan 命令开始摆摊。\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
