defmodule Kantele.Character.ItemUse do
  @moduledoc """
  `stab` / `touch` 的共享取物与物品方法分发（LPC `cmds/std/{stab,touch}.c`）。

  LPC 两个命令都是薄壳：校验参数 → `present(arg, me)` / `present(arg, environment(me))`
  → 给一句 `notify_fail` 兜底 → `obj->do_stab(me)` / `obj->do_touch(me)`。
  Ex 没有「对象自带方法」这一层，物品自定义能力统一走
  `Kantele.World.ItemActionHandlers` 的 handler 名注册表（与第十二批
  `ItemActionDispatcher` 同一套）。

  ## 命中规则

  物品的 `meta.actions` 里若有 `%{verb: "stab", handler: "do_stab"}`（或
  handler 直接叫 `do_stab` / `do_touch`），就通过 `ItemActionHandlers.lookup/1`
  找到 `{module, function}` 并 `apply(module, function, [conn, params])`。
  handler 返回 `:not_handled`（LPC `return 0`）或未注册时，回落到调用方给的
  `notify_fail` 文案 —— 这正是 LPC 里「物品没有 do_stab / do_touch」的分支。

  > **建模缺口**：LPC 大部分可插/可摸物品的能力来自 `feature/itemmake.c`
  > 转调 `ITEM_D->do_stab/do_touch`（把武器插到地上、认主电击、消耗 jingli
  > 触发随机特效等）。Ex 目前既没有 UCL 侧的 `do_stab`/`do_touch` 回填，
  > 也没有「把物品实例放进房间地上」的公开通道，故这些物品今天走 LPC 的
  > `notify_fail` 兜底路径。命令壳、门控与兜底文案均已按 LPC 落地，后续
  > 只要回填物品 `meta.actions` 并注册 handler 即可激活，无需改命令。

  ## 测试注入

  - `conn.private[:item_use_room]`：房间快照（读 `private.characters` /
    `private.item_instances` 或顶层 `items`），避免启动房间进程。
  - `conn.private[:item_use_items]`：`item_id => item 定义` 的 map，
    避免依赖 `Kantele.World.Items` 缓存。
  - `conn.private[:item_use_handlers]`：`handler 名 => {module, function}`，
    覆盖 `ItemActionHandlers.lookup/1`。
  """

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.World.Item
  alias Kantele.World.ItemActionHandlers
  alias Kantele.World.Items
  alias Kantele.World.Room

  @doc """
  在背包里按 LPC `present(arg, me)` 找物品。

  返回 `{item, instance}` 或 `nil`。匹配顺序：实例 id → `Item.matches?/2`
  （全名 / 首词 / `meta.aliases` 拼音 id）。
  """
  def find_in_inventory(conn, arg) do
    inventory = inventory_of(conn)

    Enum.find_value(inventory, fn instance ->
      with {:ok, item} <- definition(conn, instance) do
        if matches?(item, instance, arg), do: {item, instance}, else: nil
      else
        _ -> nil
      end
    end)
  end

  @doc """
  LPC `touch.c` 的双面查找：`present(arg, me)` → `present(arg, environment(me))`。

  房间那一面同时含 NPC 与地上物品；命中 NPC 时返回 `{:character, npc}`
  （调用方据此回「你别乱动X了。」），命中物品返回 `{:item, item, instance}`。
  """
  def find_present(conn, arg) do
    case find_in_inventory(conn, arg) do
      {item, instance} ->
        {:item, item, instance}

      nil ->
        room = room_snapshot(conn)

        case find_character(room, arg) do
          npc when is_map(npc) ->
            {:character, npc}

          nil ->
            case find_room_item(conn, room, arg) do
              {item, instance} -> {:item, item, instance}
              nil -> nil
            end
        end
    end
  end

  @doc """
  `obj->do_xxx(me)` 分发。无注册 handler 或 handler 返回 `:not_handled`
  时渲染 LPC `notify_fail` 兜底文案。
  """
  def dispatch(conn, item, instance, method, verb, arg, fallback) do
    handler = handler_for(item, method, verb)

    case resolve_handler(conn, handler) do
      {:ok, {module, function}} ->
        params = %{
          verb: verb,
          trailing: arg,
          method: method,
          item: item,
          instance: instance,
          handler: handler,
          room_id: room_id(conn)
        }

        case safe_apply(module, function, conn, params) do
          :not_handled -> fallback(conn, fallback)
          %{} = updated -> updated
          _ -> fallback(conn, fallback)
        end

      _ ->
        fallback(conn, fallback)
    end
  end

  @doc "渲染兜底文案（LPC `notify_fail`）；本模块不是 Command，走 Conn 原语"
  def fallback(conn, text) do
    conn
    |> Conn.render(CommandView, "text", %{text: text})
    |> Conn.prompt(CommandView, "prompt", %{})
  end

  # ---- 取数 ----

  defp inventory_of(conn) do
    case Map.get(conn, :character) do
      %{inventory: inventory} when is_list(inventory) -> inventory
      _ -> []
    end
  end

  defp definition(_conn, %{item: %Kalevala.World.Item{} = item}), do: {:ok, item}

  defp definition(conn, %{item_id: item_id}) do
    case Map.get(conn.private || %{}, :item_use_items) do
      %{^item_id => item} -> {:ok, item}
      _ -> fetch_item(item_id)
    end
  end

  defp definition(_conn, _instance), do: :error

  defp fetch_item(item_id) do
    {:ok, Items.get!(item_id)}
  rescue
    _ -> :error
  end

  defp matches?(item, instance, arg) do
    key = arg |> to_string() |> String.trim() |> String.downcase()
    instance_id = instance |> Map.get(:id) |> to_string() |> String.downcase()

    instance_id == key or safe_item_match?(item, key)
  end

  defp safe_item_match?(item, key) do
    Item.matches?(item, key)
  rescue
    _ -> false
  end

  defp room_snapshot(conn) do
    private = conn.private || %{}

    case Map.get(private, :item_use_room) do
      room when is_map(room) ->
        room

      _ ->
        case Map.get(private, :room) do
          room when is_map(room) ->
            room

          _ ->
            room_id = room_id(conn)
            if is_binary(room_id), do: safe_snapshot(room_id), else: %{}
        end
    end
  end

  defp safe_snapshot(room_id) do
    Room.snapshot(room_id)
  rescue
    _ -> %{}
  end

  defp find_character(room, arg) do
    room
    |> characters_of()
    |> Enum.find(&character_matches?(&1, arg))
  end

  defp characters_of(room) do
    from_private = get_in(room, [Access.key(:private), Access.key(:characters)])
    from_top = Map.get(room, :characters)

    cond do
      is_list(from_private) -> from_private
      is_list(from_top) -> from_top
      true -> []
    end
  end

  defp character_matches?(npc, arg) do
    key = arg |> to_string() |> String.trim() |> String.downcase()
    id = npc |> Map.get(:id) |> to_string() |> String.downcase()
    name = npc |> Map.get(:name) |> to_string() |> String.downcase()

    id == key or name == key or String.starts_with?(name, "#{key} ")
  end

  defp find_room_item(conn, room, arg) do
    room
    |> item_instances_of()
    |> Enum.find_value(fn instance ->
      with {:ok, item} <- definition(conn, instance) do
        if matches?(item, instance, arg), do: {item, instance}, else: nil
      else
        _ -> nil
      end
    end)
  end

  defp item_instances_of(room) do
    list = get_in(room, [Access.key(:private), Access.key(:item_instances)])
    if is_list(list), do: list, else: if(is_list(Map.get(room, :items)), do: Map.get(room, :items), else: [])
  end

  # ---- handler 解析 ----

  defp handler_for(item, method, verb) do
    meta = Map.get(item, :meta) || %{}
    actions = Map.get(meta, :actions) || []

    found =
      Enum.find_value(actions, fn
        %{handler: handler, verb: ^verb} when is_binary(handler) -> handler
        %{handler: ^method} -> method
        _ -> nil
      end)

    found || method
  end

  defp resolve_handler(conn, handler) do
    case Map.get(conn.private || %{}, :item_use_handlers) do
      %{^handler => target} -> {:ok, target}
      _ -> ItemActionHandlers.lookup(handler)
    end
  end

  defp safe_apply(module, function, conn, params) do
    apply(module, function, [conn, params])
  rescue
    _ -> :not_handled
  end

  defp room_id(conn) do
    case Map.get(conn, :character) do
      %{room_id: room_id} when is_binary(room_id) -> room_id
      _ -> nil
    end
  end
end
