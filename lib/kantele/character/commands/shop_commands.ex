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
  购买物品：`buy <物品> [from 商人]` → v0 简化 `buy <物品>`

  商人报价由玩家侧校验铜钱后成交。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    conn
    |> event("shop/buy", %{item_name: params["item_name"], name: params["vendor"]})
    |> assign(:prompt, false)
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
