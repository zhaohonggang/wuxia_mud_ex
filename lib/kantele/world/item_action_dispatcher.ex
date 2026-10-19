defmodule Kantele.World.ItemActionDispatcher do
  @moduledoc """
  物品私有动词分发路由（第十二批，物品动作通道）。

  在 `Kantele.Character.CommandController.recv` 的 NPC 分发器**之后**、
  全局命令**之前**插入本分发器：
  提取玩家输入的动词 → 收集候选物品（**背包优先、房间地上次之**，对应 LPC
  `init()` 对 `all_inventory(me)` 与 `all_inventory(environment(me))` 的
  注册顺序）→ 只保留 `meta.actions` 含该 verb 的物品 → 经
  `ItemActionHandlers.lookup/1`（按 LPC handler 名）解析 handler
  `{module, function}` → 逐个执行。

  - 命中且已注册 → 执行 handler，拦截全局命令。
  - handler 返回 `:not_handled`（LPC `return 0`，例如 `play <song> with <id>`
    的 id 不是本对象）→ **继续尝试下一个候选物品**（LPC add_action 的逐个
    对象语义，与 NPC 通道的「第一个命中即止」不同）。
  - 未命中 / handler 未移植 → 返回 `:not_handled`，由调用方继续走
    `Kantele.Character.Commands.call`（全局命令）。

  ## 安全性(P7)

  当前 `ItemActionHandlers.@registry` 仅包含 `play_qin`/`play_xiao`/
  `play_zheng`/`do_read` 四个已移植 handler；物品侧其它动词（`move`/`du`/
  `xi`/`pretend` 等）未回填 actions，或未注册 handler，一律
  `:not_handled`，**对全局命令零行为影响**。

  ## 优先级

  LPC 语义中对象 `add_action` 动词优先于同名全局命令。本分发器插在
  `Commands.call` 之前，即实现该优先级；重名 verb 的激活须谨慎
  （`play`/`read` 均无全局命令，故无冲突）。

  ## 关注点：候选物品取数

  生产路径读房间进程 `state.private.item_instances`
  （`Room.item_instances_by_id/1`）与 `conn.character.inventory`。单测可经
  `items_fun` 注入候选列表，无需启动房间进程。定义缺失的物品
  （`Item.fetch/1` 占位）无 `meta.actions`，自然落空，不会崩。
  """
  alias Kantele.World.Item
  alias Kantele.World.ItemActionHandlers
  alias Kantele.World.Room

  @doc """
  分发玩家输入。返回 `{:handled, conn}` 或 `:not_handled`。

  `lookup_fun` 可注入（默认 `ItemActionHandlers.lookup/1`）；`items_fun`
  亦可注入（默认「背包 + 房间地上」），便于单测。
  """
  def dispatch(conn, text, lookup_fun \\ &ItemActionHandlers.lookup/1, items_fun \\ &candidate_items/1) do
    verb = extract_verb(text)

    Enum.reduce_while(action_candidates(conn, verb, items_fun), :not_handled, fn candidate, _acc ->
      case dispatch_candidate(conn, verb, text, candidate, lookup_fun) do
        {:handled, conn} -> {:halt, {:handled, conn}}
        :not_handled -> {:cont, :not_handled}
      end
    end)
  end

  @doc """
  纯决策：是否由物品私有动词拦截。返回 `{:handled, {mod, fun}, params}`
  或 `:not_handled`。取第一个**handler 已注册**的候选（handler 执行时仍
  可能因 LPC `return 0` 落到下一个候选，属 `dispatch/4` 的动态行为）。
  """
  def resolve(
        conn,
        text,
        lookup_fun \\ &ItemActionHandlers.lookup/1,
        items_fun \\ &candidate_items/1
      ) do
    verb = extract_verb(text)

    Enum.find_value(action_candidates(conn, verb, items_fun), :not_handled, fn candidate ->
      case resolve_target(candidate, lookup_fun) do
        {:ok, {module, function}} ->
          {:handled, {module, function}, build_params(verb, text, conn, candidate)}

        {:unimplemented, _} ->
          false
      end
    end)
  end

  defp dispatch_candidate(conn, verb, text, candidate, lookup_fun) do
    case resolve_target(candidate, lookup_fun) do
      {:ok, {module, function}} ->
        params = build_params(verb, text, conn, candidate)

        case apply(module, function, [conn, params]) do
          # LPC `return 0`：本对象不处理，交还分发器尝试下一个候选
          :not_handled -> :not_handled
          conn -> {:handled, conn}
        end

      {:unimplemented, _} ->
        :not_handled
    end
  end

  # 候选的 handler 名取自物品数据（`meta.actions` 里 verb 匹配的那条）。
  defp resolve_target({_item, _instance, handler}, lookup_fun), do: lookup_fun.(handler)

  defp extract_verb(text) when is_binary(text) do
    case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
      [verb | _] when verb != "" -> verb
      _ -> nil
    end
  end

  defp extract_verb(_), do: nil

  # 候选列表：`{item_definition, instance, handler_name}` 三元组，按
  # 背包优先、房间地上次之排序；已按 verb 过滤（`meta.actions` 含该 verb）。
  # `meta` 可能缺失（`Item.fetch/1` 占位物品是裸 `%{}`），故一律走 Map.get。
  defp action_candidates(_conn, nil, _items_fun), do: []

  defp action_candidates(conn, verb, items_fun) when is_binary(verb) do
    conn
    |> items_fun.()
    |> Enum.flat_map(fn instance ->
      item = Item.instance_item(instance)

      item.meta
      |> Map.get(:actions, [])
      |> Enum.filter(fn action -> is_map(action) and action[:verb] == verb end)
      |> Enum.map(fn action -> {item, instance, action[:handler]} end)
    end)
  end

  @doc false
  # 默认取数：背包 + 房间地上（LPC init() 的两个注册面）
  def candidate_items(conn) do
    inventory_items(conn) ++ room_items(conn)
  end

  defp inventory_items(conn) do
    case Map.get(conn, :character) do
      %{inventory: inventory} when is_list(inventory) -> inventory
      _ -> []
    end
  end

  defp room_items(conn) do
    # 测试快速路径：`conn.private.room` 直接注入了带 `item_instances` 的房间
    # 结构体（真实引擎不填该字段，走房间进程查询）。
    case Map.get(conn, :private) do
      %{room: room} when is_map(room) ->
        case Map.get(room, :item_instances) do
          list when is_list(list) -> list
          _ -> room_items_from_process(conn)
        end

      _ ->
        room_items_from_process(conn)
    end
  end

  defp room_items_from_process(conn) do
    case Map.get(conn, :character) do
      %{room_id: room_id} when is_binary(room_id) -> Room.item_instances_by_id(room_id)
      _ -> []
    end
  end

  defp room_id_of(conn) do
    case Map.get(conn, :character) do
      %{room_id: room_id} when is_binary(room_id) -> room_id
      _ -> nil
    end
  end

  defp build_params(verb, text, conn, {item, instance, handler}) do
    trailing =
      case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
        [_verb, rest] -> String.trim(rest)
        _ -> ""
      end

    %{
      verb: verb,
      trailing: trailing,
      room_id: room_id_of(conn),
      item: item,
      instance: instance,
      handler: handler
    }
  end
end
