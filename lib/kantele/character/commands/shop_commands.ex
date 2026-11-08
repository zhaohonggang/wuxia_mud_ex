defmodule Kantele.Character.ListCommand do
  @moduledoc """
  列出商人货物：`list [商人]`

  房间转发给指名（或全场）NPC，由带 goods 的商人应答货单。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
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

  若目标 NPC 配置了 `meta.ask_handler`（如地藏王的转世），优先分发到
  `Kantele.NPC.AskHandler` 模块执行 `check`/`execute`（对应 LPC `ask/1` 四前置链等
  复杂交互）；否则落回 `characters/ask` 事件流（NpcAskEvent 的 inquiries/quest/turn_in 表）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Items
  alias Kantele.World.Room

  def run(conn, %{"name" => name, "keyword" => keyword_raw}) do
    keyword = keyword_raw |> to_string() |> strip_about()

    case find_ask_npc(conn, name) do
      {:ok, npc} ->
        case npc.meta.ask_handler do
          nil ->
            # 无 AskHandler：先检查是否有 quest_gift 物品提供（answer Y|N 流），
            # 否则落回事件流（inquiries/quest/turn_in 等）
            case handle_quest_gift_offer(conn, npc, keyword) do
              {:ok, conn} -> conn
              :passthrough ->
                conn
                |> event("characters/ask", %{name: name, keyword: keyword})
                |> assign(:prompt, false)
            end

          handler when is_binary(handler) ->
            dispatch_ask_handler(conn, npc, handler, keyword)
        end

      :error ->
        conn
        |> render(CommandView, "text", %{text: "这里没有这样的人。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params), do: usage(conn)

  # ---- quest_gift：ask <npc> quest 设置 temp[:quest_gift] ----

  defp handle_quest_gift_offer(conn, npc, keyword) do
    cond do
      keyword != "quest" ->
        :passthrough

      is_nil(Map.get(npc.meta, :quest_gift)) ->
        :passthrough

      true ->
        %{"obj" => obj, "gongxian" => gongxian} = Map.get(npc.meta, :quest_gift)
        item = Items.get!(obj)
        character = conn.character

        meta =
          character.meta
          |> PlayerMeta.put_temp(:quest_gift, %{npc: npc.name, obj: obj, gongxian: gongxian})

        {:ok,
         conn
         |> put_character(%{character | meta: meta})
         |> render(
           CommandView,
           "text",
           %{text: "#{npc.name} 摇了摇头，说：我这里有一件#{item.name}，需要#{gongxian}门贡才能换。你愿意接受吗？（answer Y/N）\n"}
         )
         |> prompt(CommandView, "prompt", %{})}
    end
  end

  defp find_ask_npc(conn, name) do
    room =
      Map.get(conn, :room) ||
        conn.private.room ||
        Room.snapshot(conn.character.room_id)

    characters = Map.get(room.private || %{}, :characters, [])

    Enum.find_value(characters, fn char ->
      if char.name == name or name in (char.meta.aliases || []) do
        {:ok, char}
      else
        :error
      end
    end) || :error
  end

  defp dispatch_ask_handler(conn, npc, handler_module_str, keyword) do
    # 配置中的 ask_handler 形如 "Kantele.NPC.Dizangwang"（不含 Elixir. 前缀），
    # 而 Elixir 模块原子的标准形式带 "Elixir." 前缀，故补齐后再转 atom，
    # 否则 String.to_atom 生成的是不带 Elixir. 前缀的「另一个」原子，lookup 必失败。
    module =
      if String.starts_with?(handler_module_str, "Elixir.") do
        String.to_atom(handler_module_str)
      else
        String.to_atom("Elixir." <> handler_module_str)
      end

    # 变量模块名调用不会触发自动加载（仅字面模块名会），故显式 ensure_loaded；
    # 模块不可用时兜底，避免命令崩溃。
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        dispatch_ask_specs(conn, npc, module, keyword)

      {:error, _} ->
        conn
        |> render(CommandView, "text", %{text: "这个人暂时无法回答你的问题。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp dispatch_ask_specs(conn, npc, module, keyword) do
    case module.check(conn.character, npc, keyword) do
      :ok ->
        case module.execute(conn.character, npc, keyword) do
          {:ok, new_character} ->
            conn
            |> put_character(new_character)
            |> render(
              CommandView,
              "text",
              %{text: "你向#{npc.name}请教#{keyword}。\n"}
            )
            |> prompt(CommandView, "prompt", %{})

          {:error, msg, new_character} ->
            # ask_handler 拒绝的同时改了角色（如高处不胜寒 accept_kill 把
            # 玩家击晕）；先落地角色状态再显示拒绝语。
            conn
            |> put_character(new_character)
            |> render(CommandView, "text", %{text: msg})
            |> prompt(CommandView, "prompt", %{})

          {:error, msg} ->
            conn
            |> render(CommandView, "text", %{text: msg})
            |> prompt(CommandView, "prompt", %{})

          :ok ->
            # 兼容旧式返回 :ok 的 AskHandler（不更新角色）
            conn
            |> render(
              CommandView,
              "text",
              %{text: "你向#{npc.name}请教#{keyword}。\n"}
            )
            |> prompt(CommandView, "prompt", %{})
        end

      {:error, msg, new_character} ->
        conn
        |> put_character(new_character)
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})

      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})
    end
  rescue
    e in [ArgumentError, UndefinedFunctionError] ->
      # ask_handler 回调内部异常（如参数不匹配）时的兜底，避免命令崩溃
      conn
      |> render(CommandView, "text", %{text: "这个人暂时无法回答你的问题。\n"})
      |> prompt(CommandView, "prompt", %{})
  end

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：ask <人> about <关键词>\n"})
    |> prompt(CommandView, "prompt", %{})
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
          # `Enum.each` 里 `lines = lines ++ [...]` 只会重绑被丢弃的局部变量，
          # 摊位货品一行都列不出来（R20）。用 `Enum.map` 收结果。
          item_lines =
            items
            |> Enum.with_index(1)
            |> Enum.map(fn {item, idx} -> "  #{idx}. #{item["name"]} #{item["price"]}文" end)

          (["你的摊位「#{meta.stall}」当前货品："] ++ item_lines) |> Enum.join("\n")
        end
      else
        "你还没有摆摊。使用 baitan 命令开始摆摊。\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
